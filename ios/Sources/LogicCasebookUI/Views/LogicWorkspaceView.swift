import SwiftUI
import SwiftData
import TipKit
import LogicCasebookEngine

/// Shown once, the first time the board appears.
struct LongPressTip: Tip {
    var title: Text { Text("長押しで直接選べます") }
    var message: Text? { Text("マスを長押しすると、○ × △ を直接選べます。") }
    var image: Image? { Image(systemName: "hand.tap") }
}

/// The logic workspace (docs/logic-casebook-locked-process-flow.md, sections
/// 4.4 to 4.6).
///
/// Three layouts from one set of components:
/// - iPhone: one category pair at a time at 44pt cells, a mini-map to switch
///   pairs, and the clue list below.
/// - iPad single column (portrait or a narrow window): the same layout, wider
///   cells and larger type, in a centred readable column.
/// - iPad wide (landscape, split view): every pair as a staircase grid beside
///   the clue list.
public struct LogicWorkspaceView: View {
    public let gameCase: Case

    @State private var model: WorkspaceModel
    @State private var showingBriefing = false
    @Environment(\.modelContext) private var modelContext

    public init(gameCase: Case) {
        self.gameCase = gameCase
        _model = State(initialValue: WorkspaceModel(gameCase: gameCase))
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = WorkspaceLayout(width: proxy.size.width, gameCase: gameCase)
            Group {
                if layout.isWide {
                    wideLayout(layout)
                } else {
                    compactLayout(layout)
                }
            }
            .overlay(alignment: .bottom) {
                if let banner = model.banner {
                    CheckBannerView(
                        result: banner,
                        onContinue: { model.banner = nil },
                        onUndo: { model.undo() },
                        onHint: { model.requestHint() }
                    )
                    .padding(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.default, value: model.banner)
        }
        .background(Theme.background)
        .navigationTitle(gameCase.titleJA.replacingOccurrences(of: #"（.*）"#, with: "", options: .regularExpression))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingBriefing = true } label: { Label("概要", systemImage: "info.circle") }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button { model.undo() } label: { Label("元に戻す", systemImage: "arrow.uturn.backward") }
                    .disabled(!model.history.canUndo)
                Button { model.redo() } label: { Label("やり直す", systemImage: "arrow.uturn.forward") }
                    .disabled(!model.history.canRedo)
                Button { model.requestHint() } label: { Label("ヒント", systemImage: "lightbulb") }
                Spacer()
                Button(action: checkSolution) {
                    Label("解答を確認", systemImage: "checkmark").fontWeight(.bold)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
        .sheet(isPresented: Binding(get: { model.isHintPresented }, set: { model.isHintPresented = $0 })) {
            HintSheetView(
                gameCase: gameCase,
                step: model.currentHint,
                onApply: { model.applyHint($0) },
                onDismiss: { model.isHintPresented = false }
            )
        }
        .sheet(isPresented: $showingBriefing) {
            NavigationStack {
                ScrollView {
                    CaseBriefingContent(gameCase: gameCase).padding(20)
                }
                .background(Theme.background)
                .navigationTitle("概要")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("盤面に戻る") { showingBriefing = false } }
                }
            }
        }
        .navigationDestination(isPresented: Binding(get: { model.isSolvedPresented }, set: { model.isSolvedPresented = $0 })) {
            CompletionView(
                gameCase: gameCase,
                elapsedSeconds: model.elapsedSeconds,
                hintsUsed: model.hintsUsed,
                validationAttempts: model.validationAttempts,
                isPerfect: model.isPerfect
            )
        }
        .onAppear { model.load(from: modelContext) }
        .onChange(of: model.marks) { _, _ in model.save(to: modelContext) }
        .onChange(of: model.checkedClueIDs) { _, _ in model.save(to: modelContext) }
        .onChange(of: model.hintsUsed) { _, _ in model.save(to: modelContext) }
        .onChange(of: model.validationAttempts) { _, _ in model.save(to: modelContext) }
        .sensoryFeedback(.selection, trigger: model.marks)
        .sensoryFeedback(.success, trigger: model.isSolved)
    }

    // MARK: Layouts

    private var actions: PairGridActions {
        PairGridActions(
            marks: model.marks,
            onTap: { model.cycle($0) },
            onSet: { model.set($0, $1) }
        )
    }

    private func compactLayout(_ layout: WorkspaceLayout) -> some View {
        VStack(spacing: 0) {
            boardCard(layout)
                .padding(.horizontal, 12)
                .padding(.top, 6)
            clueList
        }
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    private func wideLayout(_ layout: WorkspaceLayout) -> some View {
        HStack(spacing: 0) {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 12) {
                    legend
                    StaircaseView(gameCase: gameCase, metrics: layout.metrics, actions: actions)
                    TipView(LongPressTip())
                }
                .padding(20)
            }
            Divider()
            clueList.frame(width: 360)
        }
    }

    private func boardCard(_ layout: WorkspaceLayout) -> some View {
        let pair = model.selectedPair
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                PairMiniMap(
                    gameCase: gameCase,
                    marks: model.marks,
                    selection: Binding(get: { model.selectedPair }, set: { model.selectedPair = $0 })
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(gameCase.categories[pair.rowIndex].nameJA) × \(gameCase.categories[pair.columnIndex].nameJA)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    legend
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                PairBlockView(gameCase: gameCase, pair: pair, metrics: layout.metrics, actions: actions)
            }
            .scrollBounceBehavior(.basedOnSize)
            TipView(LongPressTip())
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach([MarkState.confirmed, .excluded, .candidate], id: \.self) { state in
                HStack(spacing: 2) {
                    MarkGlyph(mark: state, size: 18)
                    Text(state.labelJA.split(separator: " ").first.map(String.init) ?? "")
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.inkSoft)
        .accessibilityHidden(true)
    }

    private var clueList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                Text("問い：\(gameCase.questionJA)")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                HStack {
                    Text("手がかり（タップで確認済み）")
                    Spacer()
                    Text("\(model.checkedClueIDs.count)/\(gameCase.clues.count)").monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 4)

                ForEach(Array(gameCase.clues.enumerated()), id: \.element.id) { index, clue in
                    ClueRow(
                        gameCase: gameCase,
                        clue: clue,
                        index: index,
                        isChecked: model.checkedClueIDs.contains(clue.id),
                        onToggle: { model.toggleClue(clue.id) }
                    )
                }
            }
            .padding(12)
        }
    }

    // MARK: Actions

    private func checkSolution() {
        if model.check() == .correct {
            model.markCompleted(in: modelContext)
        } else {
            model.save(to: modelContext)
        }
    }
}

/// Picks cell size and header sizes for the available width. Cells are never
/// below 44pt; the board scrolls sideways instead if a phone is too narrow.
private struct WorkspaceLayout {
    let isWide: Bool
    let metrics: GridMetrics

    init(width: CGFloat, gameCase: Case) {
        let wide = width >= 900
        let roomy = width >= 600
        let probe = GridMetrics(gameCase: gameCase, cell: 44, characterWidth: roomy ? 17 : 15)
        let values = CGFloat(gameCase.primaryCategory.values.count)
        let resolvedCell: CGFloat
        if wide {
            resolvedCell = 48
        } else {
            let available = min(width, 680) - 24 - 20 - probe.rowHeaderWidth
            let cap: CGFloat = roomy ? 56 : 44
            resolvedCell = min(cap, max(44, (available / values).rounded(.down)))
        }
        isWide = wide
        metrics = GridMetrics(gameCase: gameCase, cell: resolvedCell, characterWidth: roomy ? 17 : 15)
    }
}

private struct CheckBannerView: View {
    let result: CheckResult
    let onContinue: () -> Void
    let onUndo: () -> Void
    let onHint: () -> Void

    var body: some View {
        switch result {
        case .correct:
            EmptyView()
        case .incomplete:
            card(
                title: "まだ確定していないマスがあります",
                message: "どのマスかはお知らせしません。手がかりを見直して、続けてみましょう。",
                color: Theme.amber
            ) {
                Button("編集を続ける", action: onContinue).buttonStyle(.borderedProminent).tint(Theme.accent)
                Button("ヒントを見る", action: onHint).buttonStyle(.bordered)
            }
        case .contradiction:
            card(
                title: "盤面のどこかに矛盾があります",
                message: "答えは表示しません。入力は消えていません。元に戻すか、ヒントで確認できます。",
                color: Theme.accent
            ) {
                Button("元に戻す", action: onUndo).buttonStyle(.borderedProminent).tint(Theme.accent)
                Button("ヒント", action: onHint).buttonStyle(.bordered)
                Button("続ける", action: onContinue).buttonStyle(.bordered)
            }
        }
    }

    private func card<Actions: View>(title: String, message: String, color: Color, @ViewBuilder actions: () -> Actions) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
            Text(message).font(.footnote).foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8, content: actions).padding(.top, 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
    }
}

/// The hint half-sheet: the clue involved, the logic in one sentence, and the
/// mark it justifies. The board stays visible and usable above it. It never
/// reveals more than the next deduction.
private struct HintSheetView: View {
    let gameCase: Case
    let step: DeductionStep?
    let onApply: (DeductionStep) -> Void
    let onDismiss: () -> Void

    private let detent = PresentationDetent.height(400)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let step {
                    Text("次の推論 ・ \(step.step)/\(gameCase.deductionSteps.count)")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.accent)
                    ForEach(step.clueIDs, id: \.self) { id in
                        if let index = gameCase.clues.firstIndex(where: { $0.id == id }) {
                            ClueRow(gameCase: gameCase, clue: gameCase.clues[index], index: index)
                                .background(Theme.surfaceAlt, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    Text(ClueRow.attributed(step.explanationJA, in: gameCase))
                        .font(.callout)
                        .lineSpacing(4)
                        .foregroundStyle(Theme.ink)
                    FlowLayout(spacing: 6) {
                        ForEach(Array(step.deducedFacts.enumerated()), id: \.offset) { _, fact in
                            if let left = gameCase.entity(fact.left), let right = gameCase.entity(fact.right) {
                                Text("\(left.name) ＝ \(right.name)")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        Button("反映せず戻る", action: onDismiss)
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        Button("盤面に反映") { onApply(step) }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                } else {
                    Text("ヒント").font(.footnote.weight(.bold)).foregroundStyle(Theme.accent)
                    Text("すべての手順が盤面に反映されています。「解答を確認」を押してください。")
                        .font(.callout)
                        .foregroundStyle(Theme.ink)
                    Button("閉じる", action: onDismiss).buttonStyle(.bordered).controlSize(.large)
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .presentationDetents([detent, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: detent))
        .presentationDragIndicator(.visible)
    }
}
