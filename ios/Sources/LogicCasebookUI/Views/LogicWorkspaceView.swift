import SwiftUI
import SwiftData
import LogicCasebookEngine

/// The primary workspace: matrix grid, clue list, undo/redo, hint and check
/// solution (docs/logic-casebook-locked-process-flow.md, section 4.4-4.6).
///
/// The grid shows the primary category (people) as rows against every other
/// category as grouped columns. A deduced fact that relates two *secondary*
/// categories to each other (e.g. an object directly to a time) has no cell
/// on this single grid to land on — a full implementation would give every
/// category pair its own sub-grid. Hints still surface that fact as text;
/// only the primary-linked half of a step is applied to a cell here.
public struct LogicWorkspaceView: View {
    public let gameCase: Case

    @Environment(\.modelContext) private var modelContext
    @State private var marks: [GridKey: MarkState] = [:]
    @State private var checkedClueIDs: Set<String> = []
    @State private var appliedHintSteps = 0
    @State private var hintOpen = false
    @State private var checkBanner: CheckResult?
    @State private var validationAttempts = 0
    @State private var hintsUsed = 0
    @State private var startedAt = Date()
    @State private var isSolved = false

    public init(gameCase: Case) {
        self.gameCase = gameCase
    }

    private var otherCategories: [Category] {
        gameCase.categories.filter { $0.id != gameCase.primaryCategory.id }
    }

    private var nextHintStep: DeductionStep? {
        guard appliedHintSteps < gameCase.deductionSteps.count else { return nil }
        return gameCase.deductionSteps[appliedHintSteps]
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(gameCase.questionJA)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                grid

                if let banner = checkBanner {
                    CheckBannerView(result: banner)
                }

                clueList
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle(gameCase.titleJA)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { toolbar }
        .overlay(alignment: .bottom) {
            if hintOpen, let step = nextHintStep {
                HintCardView(
                    step: step,
                    onApply: { applyHint(step) },
                    onDismiss: { hintOpen = false }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 84)
            }
        }
        .navigationDestination(isPresented: $isSolved) {
            CompletionView(
                gameCase: gameCase,
                elapsedSeconds: Int(Date().timeIntervalSince(startedAt)),
                hintsUsed: hintsUsed,
                validationAttempts: validationAttempts,
                isPerfect: hintsUsed == 0 && validationAttempts == 1
            )
        }
        .onAppear(perform: loadProgress)
    }

    // MARK: Grid

    private var grid: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                Color.clear.frame(width: 64, height: 34)
                ForEach(otherCategories) { category in
                    Text(category.nameJA)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(height: 34)
                        .frame(maxWidth: .infinity)
                        .background(Theme.surfaceAlt)
                        .gridCellColumns(category.values.count)
                }
            }
            GridRow {
                Color.clear.frame(width: 64, height: 28)
                ForEach(otherCategories) { category in
                    ForEach(category.values) { value in
                        Text(value.nameJA)
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft)
                            .frame(height: 28)
                            .frame(maxWidth: .infinity)
                            .background(Theme.surfaceAlt)
                    }
                }
            }
            ForEach(gameCase.primaryCategory.values) { primaryValue in
                GridRow {
                    Text(primaryValue.nameJA)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 64, height: 40, alignment: .leading)
                        .padding(.leading, 8)
                        .background(Theme.surfaceAlt)
                    ForEach(otherCategories) { category in
                        ForEach(category.values) { value in
                            let key = GridKey(primaryValueID: primaryValue.id, categoryID: category.id, valueID: value.id)
                            Button {
                                marks[key] = (marks[key] ?? .blank).next
                            } label: {
                                Text(symbol(for: marks[key] ?? .blank))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(color(for: marks[key] ?? .blank))
                                    .frame(height: 40)
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.surface)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func symbol(for mark: MarkState) -> String {
        switch mark {
        case .blank: return ""
        case .confirmed: return "○"
        case .excluded: return "×"
        case .candidate: return "△"
        }
    }

    private func color(for mark: MarkState) -> Color {
        switch mark {
        case .blank: return Theme.inkFaint
        case .confirmed: return Theme.good
        case .excluded: return Theme.inkSoft
        case .candidate: return Theme.amber
        }
    }

    // MARK: Clues

    private var clueList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手がかり")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
            ForEach(gameCase.clues) { clue in
                let isChecked = checkedClueIDs.contains(clue.id)
                Button {
                    if isChecked { checkedClueIDs.remove(clue.id) } else { checkedClueIDs.insert(clue.id) }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .strokeBorder(isChecked ? Theme.good : Theme.border, lineWidth: 2)
                            .background(Circle().fill(isChecked ? Theme.good : .clear))
                            .frame(width: 18, height: 18)
                            .padding(.top, 2)
                        Text(clue.textJA)
                            .font(.footnote)
                            .foregroundStyle(isChecked ? Theme.inkFaint : Theme.ink)
                            .strikethrough(isChecked)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 4) {
            ToolbarButton(systemImage: "arrow.uturn.backward", label: "戻す") {}
            ToolbarButton(systemImage: "arrow.uturn.forward", label: "やり直す") {}
            ToolbarButton(systemImage: "lightbulb", label: "ヒント", tint: Theme.amber) {
                hintOpen.toggle()
            }
            Button {
                checkSolution()
            } label: {
                Text("回答を確認")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: Actions

    private func loadProgress() {
        let progress = ProgressStore.progress(for: gameCase.caseID, in: modelContext)
        marks = progress.marks
        hintsUsed = progress.hintsUsed
        validationAttempts = progress.validationAttempts
        if progress.status == .notStarted {
            progress.status = .inProgress
        }
    }

    private func saveProgress() {
        let progress = ProgressStore.progress(for: gameCase.caseID, in: modelContext)
        progress.marks = marks
        progress.hintsUsed = hintsUsed
        progress.validationAttempts = validationAttempts
        progress.lastPlayedAt = .now
        try? modelContext.save()
    }

    private func applyHint(_ step: DeductionStep) {
        let primaryID = gameCase.primaryCategory.id
        for fact in step.deducedFacts {
            if fact.left.categoryID == primaryID {
                marks[GridKey(primaryValueID: fact.left.valueID, categoryID: fact.right.categoryID, valueID: fact.right.valueID)] = .confirmed
            } else if fact.right.categoryID == primaryID {
                marks[GridKey(primaryValueID: fact.right.valueID, categoryID: fact.left.categoryID, valueID: fact.left.valueID)] = .confirmed
            }
        }
        appliedHintSteps += 1
        hintsUsed += 1
        hintOpen = false
        saveProgress()
    }

    private func checkSolution() {
        validationAttempts += 1
        let result = SolutionChecker.check(gameCase, marks: marks)
        checkBanner = result
        if result == .correct {
            let progress = ProgressStore.progress(for: gameCase.caseID, in: modelContext)
            progress.status = .completed
            progress.isPerfect = hintsUsed == 0 && validationAttempts == 1
            progress.timeSpentSeconds = Int(Date().timeIntervalSince(startedAt))
            try? modelContext.save()
            isSolved = true
        } else {
            saveProgress()
        }
    }
}

private struct ToolbarButton: View {
    let systemImage: String
    let label: String
    var tint: Color = Theme.inkSoft
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(label).font(.caption2)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct CheckBannerView: View {
    let result: CheckResult

    var body: some View {
        Group {
            switch result {
            case .correct:
                EmptyView()
            case .incomplete:
                banner(text: "まだ確定していないマスがあります。", color: Theme.amber)
            case .contradiction:
                banner(text: "現在の盤面に矛盾があります。手がかりを見直してください。", color: Theme.accent)
            }
        }
    }

    private func banner(text: String, color: Color) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct HintCardView: View {
    let step: DeductionStep
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("次の一手", systemImage: "lightbulb")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.amber)
            Text(step.explanationJA)
                .font(.footnote)
                .foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                Button("反映する", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.amber)
                Button("閉じる", action: onDismiss)
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.amber))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}
