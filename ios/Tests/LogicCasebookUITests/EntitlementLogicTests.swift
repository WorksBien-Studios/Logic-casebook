import XCTest

@testable import LogicCasebookUI

/// EntitlementStore's own rules -- a purchase unlocks, Restore Purchases
/// recovers, a revoked or unrelated transaction does not -- run against a
/// fake `EntitlementBackend`, so they need no StoreKit daemon and run
/// identically on any CI runner.
private final class FakeBackend: EntitlementBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var owned: [EntitlementRecord]
    private var restorable: [EntitlementRecord]
    private var updateContinuation: AsyncStream<EntitlementRecord>.Continuation?
    private(set) var syncCount = 0
    var syncError: Error?

    /// `owned` is visible immediately; `restorable` appears only after `sync()`.
    init(owned: [EntitlementRecord] = [], restorable: [EntitlementRecord] = []) {
        self.owned = owned
        self.restorable = restorable
    }

    func currentEntitlements() -> AsyncStream<EntitlementRecord> {
        lock.lock(); defer { lock.unlock() }
        let snapshot = owned
        return AsyncStream { continuation in
            snapshot.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    func updates() -> AsyncStream<EntitlementRecord> {
        AsyncStream { continuation in
            self.lock.lock(); self.updateContinuation = continuation; self.lock.unlock()
        }
    }

    func sync() async throws {
        lock.lock(); defer { lock.unlock() }
        syncCount += 1
        if let syncError { throw syncError }
        owned += restorable
        restorable = []
    }

    func deliver(_ record: EntitlementRecord) {
        lock.lock(); let c = updateContinuation; lock.unlock()
        c?.yield(record)
    }
}

private func makeRecord(
    _ id: String = EntitlementStore.fullUnlockProductID,
    revoked: Bool = false,
    onFinish: @escaping @Sendable () -> Void = {}
) -> EntitlementRecord {
    EntitlementRecord(productID: id, isRevoked: revoked, finish: onFinish)
}

final class EntitlementLogicTests: XCTestCase {
    @MainActor
    func testStartsLocked() async {
        let store = EntitlementStore(backend: FakeBackend())
        await store.refreshEntitlements()
        XCTAssertFalse(store.isFullUnlockPurchased)
    }

    @MainActor
    func testOwnedEntitlementUnlocksAndIsFinished() async {
        let finished = expectation(description: "transaction finished")
        let store = EntitlementStore(backend: FakeBackend(owned: [makeRecord(onFinish: { finished.fulfill() })]))
        await store.start()
        XCTAssertTrue(store.isFullUnlockPurchased)
        await fulfillment(of: [finished], timeout: 2)
    }

    @MainActor
    func testPurchaseArrivingViaUpdatesUnlocks() async throws {
        let backend = FakeBackend()
        let store = EntitlementStore(backend: backend)
        await store.start()
        XCTAssertFalse(store.isFullUnlockPurchased)

        // Same path an Ask-to-Buy approval or another-device purchase takes.
        backend.deliver(makeRecord())
        for _ in 0..<50 where !store.isFullUnlockPurchased {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(store.isFullUnlockPurchased)
    }

    @MainActor
    func testRestorePurchasesRecoversEntitlementOnAFreshStore() async {
        let backend = FakeBackend(restorable: [makeRecord()])
        let store = EntitlementStore(backend: backend)
        await store.start()
        XCTAssertFalse(store.isFullUnlockPurchased)

        await store.restorePurchases()
        XCTAssertEqual(backend.syncCount, 1)
        XCTAssertTrue(store.isFullUnlockPurchased)
        XCTAssertNil(store.lastError)
    }

    @MainActor
    func testRestoreFailureSurfacesErrorAndStaysLocked() async {
        let backend = FakeBackend(restorable: [makeRecord()])
        backend.syncError = URLError(.notConnectedToInternet)
        let store = EntitlementStore(backend: backend)
        await store.restorePurchases()
        XCTAssertFalse(store.isFullUnlockPurchased)
        XCTAssertNotNil(store.lastError)
    }

    @MainActor
    func testRevokedEntitlementDoesNotUnlock() async {
        let store = EntitlementStore(backend: FakeBackend(owned: [makeRecord(revoked: true)]))
        await store.start()
        XCTAssertFalse(store.isFullUnlockPurchased)
    }

    @MainActor
    func testOtherProductDoesNotUnlock() async {
        let store = EntitlementStore(backend: FakeBackend(owned: [makeRecord("jp.logic.casebook.other")]))
        await store.start()
        XCTAssertFalse(store.isFullUnlockPurchased)
    }
}
