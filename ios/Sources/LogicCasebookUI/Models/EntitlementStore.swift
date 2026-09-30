import Combine
import Foundation
import StoreKit

/// A verified transaction reduced to what the entitlement logic needs.
/// `Transaction` cannot be constructed outside StoreKit, so this seam lets
/// the unlock/restore/revocation rules be tested without StoreKit's daemon.
struct EntitlementRecord: Sendable {
    let productID: String
    let isRevoked: Bool
    let finish: @Sendable () async -> Void
}

/// Where entitlement records come from. `LiveEntitlementBackend` is real
/// StoreKit 2; tests inject a fake.
protocol EntitlementBackend: Sendable {
    /// Verified records for everything currently owned.
    func currentEntitlements() -> AsyncStream<EntitlementRecord>
    /// Verified records as they arrive (purchase, Ask-to-Buy, other device).
    func updates() -> AsyncStream<EntitlementRecord>
    /// Restore Purchases: ask the App Store to re-sync.
    func sync() async throws
}

struct LiveEntitlementBackend: EntitlementBackend {
    func currentEntitlements() -> AsyncStream<EntitlementRecord> {
        Self.records(from: Transaction.currentEntitlements)
    }

    func updates() -> AsyncStream<EntitlementRecord> {
        Self.records(from: Transaction.updates)
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    /// Unverified transactions are dropped here, so they never grant anything.
    private static func records<S: AsyncSequence>(
        from source: S
    ) -> AsyncStream<EntitlementRecord> where S.Element == VerificationResult<Transaction> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    for try await result in source {
                        if case let .verified(transaction) = result {
                            continuation.yield(record(for: transaction))
                        }
                    }
                } catch {}
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func record(for transaction: Transaction) -> EntitlementRecord {
        EntitlementRecord(
            productID: transaction.productID,
            isRevoked: transaction.revocationDate != nil,
            finish: { await transaction.finish() }
        )
    }
}

/// StoreKit 2 wrapper for the single non-consumable "unlock everything"
/// entitlement (docs/logic-casebook-locked-process-flow.md, sections 2 and
/// 4.8). There is no subscription and nothing else to purchase at launch.
@MainActor
public final class EntitlementStore: ObservableObject {
    public static let fullUnlockProductID = "jp.logic.casebook.fullunlock"

    @Published public private(set) var isFullUnlockPurchased = false
    @Published public private(set) var fullUnlockProduct: Product?
    @Published public private(set) var isLoading = false
    @Published public var lastError: String?

    private let backend: EntitlementBackend
    private var updateListenerTask: Task<Void, Never>?

    public convenience init() {
        self.init(backend: LiveEntitlementBackend())
    }

    init(backend: EntitlementBackend) {
        self.backend = backend
        let updates = backend.updates()
        updateListenerTask = Task { [weak self] in
            for await record in updates {
                await self?.handle(record)
            }
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    /// Loads the storefront product and any existing entitlement. Call once
    /// at app start; per the locked spec, an unreachable storefront must
    /// never block the free cases from being playable.
    public func start() async {
        await refreshProducts()
        await refreshEntitlements()
    }

    public func refreshProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            fullUnlockProduct = try await Product.products(for: [Self.fullUnlockProductID]).first
        } catch {
            fullUnlockProduct = nil
        }
    }

    public func refreshEntitlements() async {
        for await record in backend.currentEntitlements() {
            await handle(record)
        }
    }

    public func purchaseFullUnlock() async {
        guard let product = fullUnlockProduct else {
            lastError = "商品情報を取得できませんでした"
            return
        }
        do {
            switch try await product.purchase() {
            case let .success(.verified(transaction)):
                await handle(LiveEntitlementBackend.record(for: transaction))
            case .success(.unverified):
                lastError = "購入を確認できませんでした"
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func restorePurchases() async {
        do {
            try await backend.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func handle(_ record: EntitlementRecord) async {
        if record.productID == Self.fullUnlockProductID, !record.isRevoked {
            isFullUnlockPurchased = true
        }
        await record.finish()
    }
}
