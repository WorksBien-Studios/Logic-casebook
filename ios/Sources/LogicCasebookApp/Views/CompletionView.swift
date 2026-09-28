import SwiftUI
import LogicCasebookEngine

/// Spec §4.7: solved status, optional time, hints/validation attempts used,
/// perfect-completion status, a concise deduction summary, and replay/next/
/// return actions.
public struct CompletionView: View {
    public let record: CaseRecord
    public let viewModel: WorkspaceViewModel
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        VStack(spacing: 22) {
            Spacer()

            HankoStamp()

            if viewModel.isPerfectCompletion {
                Tag(text: "完全達成", color: CasebookTheme.gold, background: CasebookTheme.goldWash)
            }

            Text(record.titleJA)
                .font(CasebookTheme.display(22, weight: .extraBold))

            HStack(spacing: 10) {
                StatTile(label: "所要時間", value: formattedElapsed)
                StatTile(label: "ヒント使用", value: "\(viewModel.hintsUsed) 回")
                StatTile(label: "誤答", value: "\(viewModel.incorrectChecks) 回")
            }
            .padding(.horizontal, 24)

            if let summary = record.deductionSteps.last?.explanationJA {
                VStack(alignment: .leading, spacing: 6) {
                    Text("推理の要約").font(CasebookTheme.body(11, weight: .bold)).foregroundStyle(CasebookTheme.inkSoft)
                    Text(summary).font(CasebookTheme.body(12.5)).foregroundStyle(CasebookTheme.inkSoft).lineSpacing(5)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .casebookCard()
                .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("ライブラリに戻る")
                        .font(CasebookTheme.body(15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent)
                .tint(CasebookTheme.indigo)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .casebookScreen()
    }

    private var formattedElapsed: String {
        let total = Int(viewModel.elapsedSeconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// The completion mark: a hanko (印章) reading 解決, "solved" — the detail
/// carried over from the product mockup rather than a generic checkmark or
/// confetti burst.
private struct HankoStamp: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(CasebookTheme.vermillion, lineWidth: 3)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(CasebookTheme.vermillion, lineWidth: 1)
                .padding(7)
            Text("解決")
                .font(CasebookTheme.display(34, weight: .extraBold))
                .foregroundStyle(CasebookTheme.vermillion)
                .fixedSize()
                .rotationEffect(.degrees(90))
        }
        .frame(width: 118, height: 118)
        .rotationEffect(.degrees(-7))
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 5) {
            Text(label).font(CasebookTheme.body(10.5, weight: .bold)).foregroundStyle(CasebookTheme.inkFaint)
            Text(value).font(CasebookTheme.display(16, weight: .semiBold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .casebookCard(cornerRadius: 12)
    }
}
