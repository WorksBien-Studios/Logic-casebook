import SwiftUI
import StoreKit

/// Spec §4.8: show StoreKit's own price, state what the purchase unlocks,
/// Purchase and Restore Purchases actions, and a safe return on
/// cancellation/failure — free-case progress is untouched either way.
public struct PurchaseView: View {
    public let lockedCaseTitle: String?
    @Environment(PurchaseStore.self) private var purchaseStore
    @Environment(\.dismiss) private var dismiss

    public init(lockedCaseTitle: String? = nil) {
        self.lockedCaseTitle = lockedCaseTitle
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CasebookTheme.inkSoft)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(CasebookTheme.paperAlt))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                RoundedRectangle(cornerRadius: 16).fill(CasebookTheme.vermillionWash)
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "lock.fill").foregroundStyle(CasebookTheme.vermillion).font(.system(size: 22)))

                VStack(spacing: 10) {
                    Text("全1,000事件を\n解放する")
                        .font(CasebookTheme.display(25, weight: .extraBold))
                        .multilineTextAlignment(.center)
                    Text("一度の購入で、残り970件の事件が\n永久に遊べるようになります。")
                        .font(CasebookTheme.body(13))
                        .foregroundStyle(CasebookTheme.inkSoft)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                VStack(spacing: 4) {
                    if let product = purchaseStore.product {
                        Text(product.displayPrice)
                            .font(CasebookTheme.display(38, weight: .extraBold))
                            .foregroundStyle(CasebookTheme.indigo)
                    } else {
                        ProgressView().padding(.vertical, 8)
                    }
                    Text("買い切り・追加課金なし")
                        .font(CasebookTheme.body(11.5, weight: .bold))
                        .foregroundStyle(CasebookTheme.inkFaint)
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .casebookCard()

                VStack(alignment: .leading, spacing: 14) {
                    bullet("970件の新しい事件を追加")
                    bullet("広告・購読は一切なし")
                    bullet("通信不要、オフラインで動作")
                    bullet("一度購入すれば永久に利用可能")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let error = purchaseStore.lastError {
                    Text(error).font(CasebookTheme.body(11.5)).foregroundStyle(CasebookTheme.vermillion)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 12)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    Task {
                        await purchaseStore.purchase()
                        if purchaseStore.isUnlocked { dismiss() }
                    }
                } label: {
                    if purchaseStore.isLoading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
                    } else {
                        Text("購入する").font(CasebookTheme.body(15, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 15)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(CasebookTheme.indigo)
                .disabled(purchaseStore.product == nil || purchaseStore.isLoading)

                Button("購入を復元") {
                    Task {
                        await purchaseStore.restore()
                        if purchaseStore.isUnlocked { dismiss() }
                    }
                }
                .font(CasebookTheme.body(13.5, weight: .medium))
                .foregroundStyle(CasebookTheme.inkSoft)

                Text("無料の30事件は、購入状況にかかわらずいつでもプレイできます。")
                    .font(CasebookTheme.body(10.5))
                    .foregroundStyle(CasebookTheme.inkFaint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 12)
            .background(.bar)
        }
        .task { await purchaseStore.start() }
        .casebookScreen()
    }

    private func bullet(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(CasebookTheme.indigo)
            Text(text).font(CasebookTheme.body(13))
        }
    }
}
