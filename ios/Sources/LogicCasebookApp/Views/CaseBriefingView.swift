import SwiftUI
import LogicCasebookEngine

/// Spec §4.3: title, scenario, question, entities/categories, difficulty
/// and estimated time, shown before play and still reachable during it.
public struct CaseBriefingView: View {
    public let record: CaseRecord
    @State private var showWorkspace = false
    @State private var showPurchase = false
    @Environment(PurchaseStore.self) private var purchaseStore

    public init(record: CaseRecord) {
        self.record = record
    }

    private var isPlayable: Bool { record.isFree || purchaseStore.isUnlocked }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Tag(text: record.difficulty.labelJA, color: CasebookTheme.indigo, background: CasebookTheme.indigoWash)
                    Tag(text: "約\(record.estimatedMinutes)分", color: CasebookTheme.inkSoft, background: CasebookTheme.paperAlt)
                    Tag(text: "\(record.primaryCategory.values.count)件の対象", color: CasebookTheme.inkSoft, background: CasebookTheme.paperAlt)
                }

                Text(record.titleJA)
                    .font(CasebookTheme.display(28, weight: .extraBold))

                Text(record.scenarioJA)
                    .font(CasebookTheme.body(13.5))
                    .foregroundStyle(CasebookTheme.inkSoft)
                    .lineSpacing(6)

                VStack(alignment: .leading, spacing: 8) {
                    Text("問題").font(CasebookTheme.body(11, weight: .bold)).foregroundStyle(CasebookTheme.indigo)
                    Text(record.questionJA).font(CasebookTheme.body(14.5, weight: .bold)).lineSpacing(5)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(CasebookTheme.indigoWash))

                VStack(alignment: .leading, spacing: 10) {
                    Text("対象カテゴリ").font(CasebookTheme.body(12, weight: .bold)).foregroundStyle(CasebookTheme.inkSoft)
                    FlowLayout(spacing: 8) {
                        ForEach(record.categories, id: \.id) { category in
                            Tag(text: category.nameJA, color: CasebookTheme.inkSoft, background: CasebookTheme.paperAlt)
                        }
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    if isPlayable { showWorkspace = true } else { showPurchase = true }
                } label: {
                    Label(isPlayable ? "事件を開始する" : "解放して開始する", systemImage: isPlayable ? "arrow.right" : "lock.fill")
                        .font(CasebookTheme.body(15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(CasebookTheme.indigo)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .background(.bar)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showWorkspace) {
            WorkspaceView(record: record)
        }
        .sheet(isPresented: $showPurchase) {
            PurchaseView(lockedCaseTitle: record.titleJA)
        }
        .casebookScreen()
    }
}

/// A simple wrapping tag layout — SwiftUI's `Layout` protocol, the native
/// tool for custom flow layouts, rather than a fixed `HStack`/`LazyVGrid`
/// that would either overflow or waste space with a variable tag count.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width.isFinite ? width : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
