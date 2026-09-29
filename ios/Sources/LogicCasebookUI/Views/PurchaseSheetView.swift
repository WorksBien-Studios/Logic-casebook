import SwiftUI

/// The purchase flow (docs/logic-casebook-locked-process-flow.md, section
/// 4.8): shows the exact price StoreKit returns, states what the purchase
/// unlocks, offers Purchase and Restore, and returns safely on cancel or
/// failure without losing free-case progress.
public struct PurchaseSheetView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Theme.border)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)

            Text("すべてのケースを解放")
                .font(Theme.display(20))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entitlements.fullUnlockProduct?.displayPrice ?? "¥1,800")
                    .font(Theme.display(30, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("一回限りの購入").font(.footnote).foregroundStyle(Theme.inkSoft)
            }

            VStack(alignment: .leading, spacing: 8) {
                bullet("残り970件のケースが遊び放題")
                bullet("追加料金・サブスクリプションなし")
                bullet("広告なし")
            }

            if entitlements.isFullUnlockPurchased {
                Label("購入済みです", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.good)
            } else {
                Button {
                    Task {
                        isPurchasing = true
                        await entitlements.purchaseFullUnlock()
                        isPurchasing = false
                        if entitlements.isFullUnlockPurchased { dismiss() }
                    }
                } label: {
                    Text("購入する")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isPurchasing)

                Button {
                    Task { await entitlements.restorePurchases() }
                } label: {
                    Text("購入を復元")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
                }
            }

            if let error = entitlements.lastError {
                Text(error).font(.caption).foregroundStyle(Theme.accent)
            }

            Button("閉じる") { dismiss() }
                .font(.footnote)
                .foregroundStyle(Theme.inkFaint)
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .task { await entitlements.refreshProducts() }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark").foregroundStyle(Theme.good).font(.footnote)
            Text(text).font(.footnote)
        }
    }
}
