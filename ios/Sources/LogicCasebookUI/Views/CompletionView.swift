import SwiftUI
import LogicCasebookEngine

/// The completion screen (docs/logic-casebook-locked-process-flow.md,
/// section 4.7): solved status, time as optional information, hints and
/// validation attempts used, perfect-completion status, and a deduction
/// summary.
public struct CompletionView: View {
    public let gameCase: Case
    public let elapsedSeconds: Int
    public let hintsUsed: Int
    public let validationAttempts: Int
    public let isPerfect: Bool

    @Environment(\.dismiss) private var dismiss

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
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Theme.goodSoft)
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Theme.good)
                }
                .frame(width: 84, height: 84)
                .padding(.top, 8)

                Text("解決しました").font(Theme.display(24))
                Text(gameCase.titleJA).font(.subheadline).foregroundStyle(Theme.inkSoft)

                if isPerfect {
                    Label("パーフェクト・ノーヒントクリア", systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.amber)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Theme.amberSoft)
                        .clipShape(Capsule())
                }

                HStack(spacing: 10) {
                    StatTile(value: elapsedLabel, label: "経過時間")
                    StatTile(value: "\(hintsUsed)", label: "使用ヒント")
                    StatTile(value: "\(validationAttempts)", label: "確認回数")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("解法の要約").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                    ForEach(gameCase.deductionSteps) { step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(step.step)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.inkSoft)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Theme.surfaceAlt))
                                .overlay(Circle().stroke(Theme.border))
                            Text(step.explanationJA)
                                .font(.footnote)
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))

                VStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Text("事件簿に戻る")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.display(18))
            Text(label).font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
    }
}
