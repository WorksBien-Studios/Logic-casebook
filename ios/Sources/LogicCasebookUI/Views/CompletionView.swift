import SwiftUI
import LogicCasebookEngine

/// The completion screen (docs/logic-casebook-locked-process-flow.md,
/// section 4.7): solved status, time as optional information, hints and
/// validation attempts used, perfect-completion status, and a deduction
/// summary. The single moment of celebration is one hanko stamp; there is no
/// confetti, ranking or streak.
public struct CompletionView: View {
    public let gameCase: Case
    public let elapsedSeconds: Int
    public let hintsUsed: Int
    public let validationAttempts: Int
    public let isPerfect: Bool

    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.caseNavigation) private var navigation

    public init(gameCase: Case, elapsedSeconds: Int, hintsUsed: Int, validationAttempts: Int, isPerfect: Bool) {
        self.gameCase = gameCase
        self.elapsedSeconds = elapsedSeconds
        self.hintsUsed = hintsUsed
        self.validationAttempts = validationAttempts
        self.isPerfect = isPerfect
    }

    private var elapsedLabel: String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HankoSeal(text: "解決", perfect: isPerfect, size: 120, animated: true)
                    .padding(.top, 24)
                    .padding(.bottom, isPerfect ? 8 : 0)

                Text(gameCase.titleJA)
                    .font(Theme.display(24))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                Text(isPerfect ? "ヒントも誤答もなしで解決しました。" : "事件を解決しました。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)

                HStack(spacing: 0) {
                    stat("\(hintsUsed)", "ヒント")
                    Divider().frame(height: 36)
                    stat("\(validationAttempts)", "確認")
                    Divider().frame(height: 36)
                    stat(elapsedLabel, "所要時間（参考）")
                }
                .padding(.vertical, 12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))

                deductionSummary

                VStack(spacing: 8) {
                    Button(action: nextCase) {
                        Text("次の事件へ")
                            .font(.headline)
                            .foregroundStyle(Theme.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button("もう一度解く") { navigation.open(gameCase) }
                        .frame(height: 40)
                    Button("事件簿に戻る") { navigation.popToRoot() }
                        .frame(height: 40)
                }
                .foregroundStyle(Theme.accent)
                .padding(.top, 6)
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.display(22)).monospacedDigit().foregroundStyle(Theme.ink)
            Text(label).font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var deductionSummary: some View {
        let space = log(Double(max(gameCase.proofMetrics.searchSpace, 2)))
        return VStack(alignment: .leading, spacing: 0) {
            Text("推理の道筋")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
                .padding(.vertical, 10)
            ForEach(gameCase.deductionSteps) { step in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("手順 \(step.step) ・ 手がかり \(step.clueIDs.map { String(Int($0.suffix(2)) ?? 0) }.joined(separator: "・"))")
                        Spacer()
                        Text("\(step.candidateCountBefore) → \(step.candidateCountAfter)通り").monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    narrowingBar(fraction: max(0.03, log(Double(max(step.candidateCountAfter, 1))) / space))
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                Divider()
            }
        }
        .padding(.horizontal, 14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func narrowingBar(fraction: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border)
                Capsule().fill(Theme.accent).frame(width: proxy.size.width * min(1, fraction))
            }
        }
        .frame(height: 5)
    }

    private func nextCase() {
        let next = CaseCatalog.next(after: gameCase) { $0.isFree || entitlements.isFullUnlockPurchased }
        if let next { navigation.open(next) } else { navigation.popToRoot() }
    }
}
