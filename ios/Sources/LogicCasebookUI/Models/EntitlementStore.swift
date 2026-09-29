import Combine
import Foundation
import StoreKit

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

    private var updateListenerTask: Task<Void, Never>?

    public init() {
        updateListenerTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
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
        for await result in Transaction.currentEntitlements {
            await handle(result)
        }
    }

    public func purchaseFullUnlock() async {
        guard let product = fullUnlockProduct else {
            lastError = "商品情報を取得できませんでした"
            return
        }
        do {
            switch try await product.purchase() {
            case let .success(verification):
                await handle(verification)
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
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = result else { return }
        if transaction.productID == Self.fullUnlockProductID, transaction.revocationDate == nil {
            isFullUnlockPurchased = true
        }
        await transaction.finish()
    }
}
