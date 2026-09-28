import Foundation
import StoreKit
import Observation

/// The full-library unlock: a single StoreKit 2 non-consumable, per spec §5
/// ("Purchase | StoreKit 2 non-consumable entitlement") and §4.8's purchase
/// flow. `@Observable` (not `ObservableObject`) is Apple's current
/// lightweight observation macro — the "most appropriate native tool" for a
/// view-model with no Combine publishers to expose.
public enum CasebookProduct {
    public static let fullUnlockID = "jp.logic.casebook.fullunlock"
}

@Observable
@MainActor
public final class PurchaseStore {
    public private(set) var product: Product?
    public private(set) var isUnlocked = false
    public private(set) var isLoading = false
    public private(set) var lastError: String?

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

    public func start() async {
        await refreshEntitlement()
        await loadProduct()
    }

    public func loadProduct() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [CasebookProduct.fullUnlockID])
            product = products.first
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Spec §4.8: purchase, cancellation and failure all return safely to
    /// the library; free-case progress is untouched regardless of outcome.
    public func purchase() async {
        guard let product else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
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

    public func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshEntitlement() async {
        for await entitlement in Transaction.currentEntitlements {
            await handle(entitlement)
        }
    }

    private func handle(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else { return }
        if transaction.productID == CasebookProduct.fullUnlockID {
            isUnlocked = true
        }
        await transaction.finish()
    }
}
