import SwiftUI
import LogicCasebookEngine

/// Spec §4.5: identify the relevant clue(s), state the relationship,
/// explain the next justified mark, then let the player apply it or return
/// without applying it.
public struct HintSheetView: View {
    public let hint: Hint
    public let onApply: () -> Void
    public let onDismiss: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("ヒント", systemImage: "lightbulb")
                    .font(CasebookTheme.display(19, weight: .semiBold))
                Spacer()
            }

            if !hint.referencedClueIDs.isEmpty {
                HStack(spacing: 6) {
                    ForEach(hint.referencedClueIDs, id: \.self) { id in
                        Tag(text: clueLabel(id), color: CasebookTheme.indigo, background: CasebookTheme.indigoWash)
                    }
                }
            }

            Text(hint.explanationJA)
                .font(CasebookTheme.body(13.5))
                .lineSpacing(6)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(CasebookTheme.indigoWash))

            Spacer()

            Button {
                onApply()
            } label: {
                Text("このマークを適用する")
                    .font(CasebookTheme.body(15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .tint(CasebookTheme.indigo)

            Button("閉じる") { onDismiss() }
                .font(CasebookTheme.body(14, weight: .medium))
                .frame(maxWidth: .infinity)
                .foregroundStyle(CasebookTheme.inkSoft)
        }
        .padding(24)
        .casebookScreen()
    }

    private func clueLabel(_ id: String) -> String {
        // Clue IDs are authored as "clue-01", "clue-02", … — a friendlier
        // "手がかり 1" reads better than the raw content ID.
        if let number = Int(id.split(separator: "-").last.map(String.init) ?? "") {
            return "手がかり \(number)"
        }
        return id
    }
}
