import SwiftUI
import LogicCasebookEngine

/// Help: tutorial replay (locked spec, section 4.1), the four cell states,
/// purchase and restore, and the launch promises.
public struct HelpView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @State private var showingTutorial = false
    @State private var showingPurchase = false

    public init() {}

    public var body: some View {
        List {
            Section("遊び方") {
                Button {
                    showingTutorial = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("チュートリアルをもう一度").foregroundStyle(Theme.ink)
                        Text("ミニ事件で基本操作を確認").font(.caption).foregroundStyle(Theme.inkSoft)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("マスの4つの状態").foregroundStyle(Theme.ink)
                    HStack {
                        ForEach(MarkState.allCases, id: \.self) { state in
                            VStack(spacing: 4) {
                                MarkGlyph(mark: state, size: 36, blankAsDash: true)
                                    .frame(width: 52, height: 44)
                                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border, lineWidth: 1))
                                Text(state.labelJA.split(separator: " ").first.map(String.init) ?? "")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("マスの状態は、未入力、確定 ○、除外 ×、候補 △ の4つです")
            }

            Section("購入") {
                if entitlements.isFullUnlockPurchased {
                    Label("全1,000事件を解放済みです", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.good)
                } else {
                    Button {
                        showingPurchase = true
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("全1,000事件を解放").foregroundStyle(Theme.ink)
                            Text("\(entitlements.fullUnlockProduct?.displayPrice ?? "¥1,800") ・ 買い切り")
                                .font(.caption).foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
                Button("購入を復元") { Task { await entitlements.restorePurchases() } }
                    .foregroundStyle(Theme.accent)
            }

            Section("このアプリについて") {
                ForEach(["広告は一切表示しません", "サブスクリプションはありません", "アカウント登録は不要です", "すべてオフラインで遊べます"], id: \.self) { text in
                    Label(text, systemImage: "checkmark").foregroundStyle(Theme.ink)
                        .labelStyle(PromiseLabelStyle())
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("ヘルプ")
        .fullScreenCover(isPresented: $showingTutorial) {
            TutorialView { showingTutorial = false }
        }
        .sheet(isPresented: $showingPurchase) { PurchaseSheetView() }
    }
}

private struct PromiseLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon.foregroundStyle(Theme.good)
            configuration.title
        }
    }
}
