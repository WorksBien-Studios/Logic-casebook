import SwiftUI

/// The purchase flow (docs/logic-casebook-locked-process-flow.md, section
/// 4.8): shows the exact price StoreKit returns, states what the purchase
/// unlocks, offers Purchase and Restore, and returns safely on cancel or
/// failure without losing free-case progress. No countdowns, no struck-through
/// prices, no urgency.
public struct PurchaseSheetView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("全1,000事件を解放")
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.ink)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entitlements.fullUnlockProduct?.displayPrice ?? "¥1,800")
                        .font(Theme.display(44, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text("買い切り ・ 1回のお支払い")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }

                VStack(spacing: 0) {
                    promise("無料の30事件に加えて、残り970事件も遊べます")
                    Divider()
                    promise("サブスクリプションではありません")
                    Divider()
                    promise("広告は表示しません")
                    Divider()
                    promise("すべてオフラインで遊べます")
                    Divider()
                    promise("無料事件の進捗はそのまま引き継がれます")
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))

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
                            .foregroundStyle(Theme.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isPurchasing)

                    HStack(spacing: 28) {
                        Button("購入を復元") { Task { await entitlements.restorePurchases() } }
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.accent)
                        Button("あとで") { dismiss() }
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let error = entitlements.lastError {
                    Text(error).font(.caption).foregroundStyle(Theme.accent)
                }

                Text("価格はApp Storeから取得して表示しています。通信できない場合でも、無料の事件は遊べます。")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(22)
        }
        .background(Theme.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await entitlements.refreshProducts() }
    }

    private func promise(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark").foregroundStyle(Theme.good).font(.subheadline.weight(.bold))
            Text(text).font(.subheadline).foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}
