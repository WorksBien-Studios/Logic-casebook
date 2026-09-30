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
    private var nextSnapshotStarted: (@Sendable () -> Void)?
    private var pausedSnapshot: (AsyncStream<EntitlementRecord>.Continuation, [EntitlementRecord])?

    /// `owned` is visible immediately; `restorable` appears only after `sync()`.
    init(owned: [EntitlementRecord] = [], restorable: [EntitlementRecord] = []) {
        self.owned = owned
        self.restorable = restorable
    }

    func currentEntitlements() -> AsyncStream<EntitlementRecord> {
        lock.lock()
        let snapshot = owned
        let onStarted = nextSnapshotStarted
        nextSnapshotStarted = nil
        lock.unlock()
        return AsyncStream { continuation in
            if let onStarted {
                self.lock.lock()
                self.pausedSnapshot = (continuation, snapshot)
                self.lock.unlock()
                onStarted()
            } else {
                snapshot.forEach { continuation.yield($0) }
                continuation.finish()
            }
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

    func setOwned(_ records: [EntitlementRecord]) {
        lock.lock(); owned = records; lock.unlock()
    }

    /// Hold a captured snapshot until the test has delivered newer information.
    func pauseNextSnapshot(onStarted: @escaping @Sendable () -> Void) {
        lock.lock(); nextSnapshotStarted = onStarted; lock.unlock()
    }

    func resumeSnapshot() {
        lock.lock(); let paused = pausedSnapshot; pausedSnapshot = nil; lock.unlock()
        guard let (continuation, snapshot) = paused else { return }
        snapshot.forEach { continuation.yield($0) }
        continuation.finish()
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
    @MainActor
    func testRevocationUpdateRemovesExistingUnlockAndIsFinished() async {
        let backend = FakeBackend(owned: [makeRecord()])
        let store = EntitlementStore(backend: backend)
        await store.refreshEntitlements()
        XCTAssertTrue(store.isFullUnlockPurchased)

        let finished = expectation(description: "revocation processed")
        backend.deliver(makeRecord(revoked: true, onFinish: { finished.fulfill() }))
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertFalse(store.isFullUnlockPurchased)
    }

    @MainActor
    func testEmptySnapshotRemovesExistingUnlock() async {
        let backend = FakeBackend(owned: [makeRecord()])
        let store = EntitlementStore(backend: backend)
        await store.refreshEntitlements()
        XCTAssertTrue(store.isFullUnlockPurchased)

        // Apple omits refunded transactions from currentEntitlements.
        backend.setOwned([])
        await store.refreshEntitlements()
        XCTAssertFalse(store.isFullUnlockPurchased)
    }

    @MainActor
    func testSnapshotWithOnlyOtherProductsRemovesExistingUnlock() async {
        let backend = FakeBackend(owned: [makeRecord()])
        let store = EntitlementStore(backend: backend)
        await store.refreshEntitlements()
        XCTAssertTrue(store.isFullUnlockPurchased)

        backend.setOwned([makeRecord("jp.logic.casebook.other")])
        await store.refreshEntitlements()
        XCTAssertFalse(store.isFullUnlockPurchased)
    }

    @MainActor
    func testOtherProductRevocationDoesNotRemoveExistingUnlock() async {
        let backend = FakeBackend(owned: [makeRecord()])
        let store = EntitlementStore(backend: backend)
        await store.refreshEntitlements()
        let finished = expectation(description: "other product processed")
        backend.deliver(makeRecord("jp.logic.casebook.other", revoked: true,
                                  onFinish: { finished.fulfill() }))
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertTrue(store.isFullUnlockPurchased)
    }

    @MainActor
    func testRepurchaseAfterRevocationUnlocksAgain() async {
        let backend = FakeBackend(owned: [makeRecord()])
        let store = EntitlementStore(backend: backend)
        await store.refreshEntitlements()
        let revoked = expectation(description: "revocation processed")
        backend.deliver(makeRecord(revoked: true, onFinish: { revoked.fulfill() }))
        await fulfillment(of: [revoked], timeout: 2)
        XCTAssertFalse(store.isFullUnlockPurchased)

        let purchased = expectation(description: "repurchase processed")
        backend.deliver(makeRecord(onFinish: { purchased.fulfill() }))
        await fulfillment(of: [purchased], timeout: 2)
        XCTAssertTrue(store.isFullUnlockPurchased)
    }

    @MainActor
    func testSuccessfulRestoreReconcilesEmptySnapshotAndClearsOldError() async {
        let backend = FakeBackend(owned: [makeRecord()])
        let store = EntitlementStore(backend: backend)
        await store.refreshEntitlements()
        XCTAssertTrue(store.isFullUnlockPurchased)
        store.lastError = "Previous failure"

        backend.setOwned([])
        await store.restorePurchases()
        XCTAssertFalse(store.isFullUnlockPurchased)
        XCTAssertNil(store.lastError)
    }

    @MainActor
    func testFailedRestorePreservesExistingUnlock() async {
        let backend = FakeBackend(owned: [makeRecord()])
        let store = EntitlementStore(backend: backend)
        await store.refreshEntitlements()
        backend.syncError = URLError(.notConnectedToInternet)
        await store.restorePurchases()
        XCTAssertTrue(store.isFullUnlockPurchased)
        XCTAssertNotNil(store.lastError)
    }

    @MainActor
    func testStaleOwnedSnapshotCannotUndoNewerRevocation() async {
        let backend = FakeBackend(owned: [makeRecord()])
        let store = EntitlementStore(backend: backend)
        await store.refreshEntitlements()
        let started = expectation(description: "snapshot captured")
        backend.pauseNextSnapshot(onStarted: { started.fulfill() })
        let refresh = Task { await store.refreshEntitlements() }
        await fulfillment(of: [started], timeout: 2)
        // Holding a snapshot must not temporarily lock a valid owner.
        XCTAssertTrue(store.isFullUnlockPurchased)

        let revoked = expectation(description: "newer revocation processed")
        backend.deliver(makeRecord(revoked: true, onFinish: { revoked.fulfill() }))
        await fulfillment(of: [revoked], timeout: 2)
        XCTAssertFalse(store.isFullUnlockPurchased)
        backend.resumeSnapshot()
        await refresh.value
        XCTAssertFalse(store.isFullUnlockPurchased)
    }

    @MainActor
    func testStaleEmptySnapshotCannotUndoNewerPurchase() async {
        let backend = FakeBackend()
        let store = EntitlementStore(backend: backend)
        let started = expectation(description: "empty snapshot captured")
        backend.pauseNextSnapshot(onStarted: { started.fulfill() })
        let refresh = Task { await store.refreshEntitlements() }
        await fulfillment(of: [started], timeout: 2)

        let purchased = expectation(description: "newer purchase processed")
        backend.deliver(makeRecord(onFinish: { purchased.fulfill() }))
        await fulfillment(of: [purchased], timeout: 2)
        XCTAssertTrue(store.isFullUnlockPurchased)
        backend.resumeSnapshot()
        await refresh.value
        XCTAssertTrue(store.isFullUnlockPurchased)
    }

    @MainActor
    func testOlderRefreshCannotOverwriteNewerSnapshot() async {
        let backend = FakeBackend(owned: [makeRecord()])
        let store = EntitlementStore(backend: backend)
        let started = expectation(description: "old snapshot captured")
        backend.pauseNextSnapshot(onStarted: { started.fulfill() })
        let older = Task { await store.refreshEntitlements() }
        await fulfillment(of: [started], timeout: 2)

        backend.setOwned([])
        await store.refreshEntitlements()
        XCTAssertFalse(store.isFullUnlockPurchased)
        backend.resumeSnapshot()
        await older.value
        XCTAssertFalse(store.isFullUnlockPurchased)
    }

}
