import SwiftUI
import SwiftData
import LogicCasebookEngine

/// Spec §4.4: the primary workspace — matrix grid(s), clue list, undo/redo,
/// hint and check-solution actions, autosaving after each meaningful
/// change. iPad shows grid and clues in a permanent split; iPhone switches
/// between them with a segmented control while preserving both states.
public struct WorkspaceView: View {
    public let record: CaseRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel: WorkspaceViewModel
    @State private var selectedTab: WorkspaceTab = .grid
    @State private var showCompletion = false
    @State private var alertResult: SolutionCheckResult?
    @State private var existingProgress: CaseProgressRecord?

    public init(record: CaseRecord) {
        self.record = record
        _viewModel = State(initialValue: WorkspaceViewModel(record: record))
    }

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    public var body: some View {
        Group {
            if isRegularWidth {
                HStack(spacing: 0) {
                    GridPane(viewModel: viewModel).frame(maxWidth: .infinity)
                    Divider()
                    ClueListPane(viewModel: viewModel).frame(width: 320)
                }
            } else {
                VStack(spacing: 0) {
                    Picker("表示", selection: $selectedTab) {
                        Text("グリッド").tag(WorkspaceTab.grid)
                        Text("手がかり (\(record.clues.count))").tag(WorkspaceTab.clues)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    if selectedTab == .grid {
                        GridPane(viewModel: viewModel)
                    } else {
                        ClueListPane(viewModel: viewModel)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            WorkspaceToolbar(viewModel: viewModel)
        }
        .navigationTitle(record.titleJA)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { viewModel.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!viewModel.canUndo)
                Button { viewModel.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .disabled(!viewModel.canRedo)
            }
        }
        .sheet(isPresented: hintSheetBinding) {
            if let hint = viewModel.activeHint {
                HintSheetView(hint: hint, onApply: { viewModel.applyActiveHint() }, onDismiss: { viewModel.dismissHint() })
                    .presentationDetents([.medium, .large])
            }
        }
        .fullScreenCover(isPresented: $showCompletion) {
            CompletionView(record: record, viewModel: viewModel)
        }
        .alert(alertTitle, isPresented: alertBinding, presenting: alertResult) { result in
            if result == .contradiction {
                Button("ヒントを見る") { viewModel.requestHint() }
            }
            Button("続ける", role: .cancel) {}
        } message: { result in
            Text(alertMessage(for: result))
        }
        .onAppear { loadProgress() }
        .onChange(of: viewModel.checkResult) { _, newValue in
            guard let newValue else { return }
            if newValue == .solved { showCompletion = true } else { alertResult = newValue }
            saveProgress(isSolved: newValue == .solved)
        }
        .onChange(of: viewModel.grid) { _, _ in saveProgress(isSolved: viewModel.isSolved) }
        .casebookScreen()
    }

    private var hintSheetBinding: Binding<Bool> {
        Binding(get: { viewModel.activeHint != nil }, set: { if !$0 { viewModel.dismissHint() } })
    }
    private var alertBinding: Binding<Bool> {
        Binding(get: { alertResult != nil }, set: { if !$0 { alertResult = nil } })
    }
    private var alertTitle: String {
        alertResult == .contradiction ? "矛盾があります" : "未解決のマスがあります"
    }
    private func alertMessage(for result: SolutionCheckResult) -> String {
        switch result {
        case .contradiction: "現在の確定マスの組み合わせは、手がかりと矛盾しています。マスの位置は表示されません。"
        case .incomplete: "まだ確定していないマスが残っています。位置は表示されません。"
        case .solved: ""
        }
    }

    private func loadProgress() {
        let caseID = record.caseID
        let descriptor = FetchDescriptor<CaseProgressRecord>(predicate: #Predicate { $0.caseID == caseID })
        guard let saved = try? modelContext.fetch(descriptor).first else { return }
        existingProgress = saved
        viewModel.restore(
            grid: saved.restoreGrid(for: record),
            hintsUsed: saved.hintsUsed,
            incorrectChecks: saved.incorrectChecks,
            previousSecondsSpent: saved.secondsSpent
        )
    }

    private func saveProgress(isSolved: Bool) {
        if let existingProgress {
            existingProgress.update(grid: viewModel.grid, secondsSpent: viewModel.elapsedSeconds, hintsUsed: viewModel.hintsUsed, incorrectChecks: viewModel.incorrectChecks, isSolved: isSolved)
        } else {
            let newProgress = CaseProgressRecord(caseID: record.caseID, grid: viewModel.grid, secondsSpent: viewModel.elapsedSeconds, hintsUsed: viewModel.hintsUsed, incorrectChecks: viewModel.incorrectChecks, isSolved: isSolved)
            modelContext.insert(newProgress)
            existingProgress = newProgress
        }
        try? modelContext.save()
    }
}

private enum WorkspaceTab { case grid, clues }

private struct GridPane: View {
    let viewModel: WorkspaceViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(viewModel.record.assignedCategories.enumerated()), id: \.element.id) { offset, category in
                    CategoryGrid(viewModel: viewModel, category: category, categoryIndex: offset + 1)
                }
            }
            .padding(16)
        }
    }
}

private struct CategoryGrid: View {
    let viewModel: WorkspaceViewModel
    let category: CaseCategory
    let categoryIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.nameJA).font(CasebookTheme.body(12, weight: .bold)).foregroundStyle(CasebookTheme.inkSoft)
            Grid(horizontalSpacing: 5, verticalSpacing: 5) {
                GridRow {
                    Color.clear.frame(width: 56, height: 1)
                    ForEach(category.values, id: \.id) { value in
                        Text(value.nameJA).font(CasebookTheme.body(10, weight: .bold)).foregroundStyle(CasebookTheme.inkFaint)
                            .lineLimit(1).frame(maxWidth: .infinity)
                    }
                }
                ForEach(Array(viewModel.record.primaryCategory.values.enumerated()), id: \.element.id) { owner, ownerValue in
                    GridRow {
                        Text(ownerValue.nameJA).font(CasebookTheme.body(11.5, weight: .bold)).foregroundStyle(CasebookTheme.inkSoft)
                            .frame(width: 56, alignment: .leading).lineLimit(1)
                        ForEach(Array(category.values.enumerated()), id: \.element.id) { valueIndex, _ in
                            CellView(state: viewModel.grid.state(owner: owner, category: categoryIndex, value: valueIndex), isFocused: false) {
                                viewModel.tap(owner: owner, category: categoryIndex, value: valueIndex)
                            }
                            .frame(width: 40, height: 40)
                        }
                    }
                }
            }
        }
        .padding(12)
        .casebookCard()
    }
}

private struct ClueListPane: View {
    let viewModel: WorkspaceViewModel
    @State private var checkedOff: Set<String> = []

    var body: some View {
        List {
            ForEach(viewModel.record.clues, id: \.id) { clue in
                Button {
                    if checkedOff.contains(clue.id) { checkedOff.remove(clue.id) } else { checkedOff.insert(clue.id) }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: checkedOff.contains(clue.id) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(checkedOff.contains(clue.id) ? CasebookTheme.indigo : CasebookTheme.line)
                        Text(clue.textJA)
                            .font(CasebookTheme.body(13))
                            .foregroundStyle(checkedOff.contains(clue.id) ? CasebookTheme.inkFaint : CasebookTheme.ink)
                            .strikethrough(checkedOff.contains(clue.id))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }
}

private struct WorkspaceToolbar: View {
    let viewModel: WorkspaceViewModel
    var body: some View {
        VStack(spacing: 10) {
            Button { viewModel.requestHint() } label: {
                Label("ヒントを見る", systemImage: "lightbulb")
                    .font(CasebookTheme.body(14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(CasebookTheme.indigo)

            Button { viewModel.checkSolution() } label: {
                Text("解答を確認")
                    .font(CasebookTheme.body(14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.bordered)
            .tint(CasebookTheme.indigo)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }
}
