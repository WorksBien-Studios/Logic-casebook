import SwiftUI
import SwiftData
import LogicCasebookEngine
import iOS18Shell

/// Spec §4.2: continue banner, all four difficulties visible from first
/// launch, free/locked/progress status per case, and search/filters
/// practical across 1,000 cases. The library tab carries `role: .search`
/// (see `CasebookRootView`), so `appShellSearchQuery` — not local `@State` —
/// is the query source, per `iOS18Shell`'s own searchable-tab convention.
public struct CaseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appShellSearchQuery) private var query
    @State private var viewModel = LibraryViewModel()
    @State private var selectedCase: CaseRecord?

    public init() {}

    public var body: some View {
        Group {
            if let error = viewModel.loadError {
                ContentUnavailableView("コンテンツを読み込めません", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                List {
                    if query.isEmpty, let continuing = viewModel.continuing {
                        Section {
                            ContinueRow(entry: continuing) { selectedCase = continuing.record }
                        }
                        .listRowSeparator(.hidden)
                    }
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        let entries = viewModel.entries(for: difficulty).filter { viewModel.matches($0.record, query: query) }
                        if !entries.isEmpty {
                            Section {
                                ForEach(entries) { entry in
                                    CaseRow(entry: entry) { selectedCase = entry.record }
                                }
                            } header: {
                                DifficultyHeader(difficulty: difficulty, total: viewModel.entries(for: difficulty).count)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .accessibilityIdentifier("casebook.library.list")
            }
        }
        .navigationTitle("事件簿")
        .navigationDestination(item: $selectedCase) { record in
            CaseBriefingView(record: record)
        }
        .task {
            viewModel.load(modelContext: modelContext)
        }
        .onChange(of: selectedCase) { _, newValue in
            if newValue == nil { viewModel.refreshProgress(modelContext: modelContext) }
        }
        .casebookScreen()
    }
}

private struct DifficultyHeader: View {
    let difficulty: Difficulty
    let total: Int
    var body: some View {
        HStack {
            Circle().fill(CasebookTheme.diffuse(difficulty)).frame(width: 7, height: 7)
            Text(difficulty.labelJA).font(CasebookTheme.body(13, weight: .bold)).foregroundStyle(CasebookTheme.ink)
            Text("\(total)件").font(CasebookTheme.body(11)).foregroundStyle(CasebookTheme.inkFaint)
        }
        .textCase(nil)
    }
}

private struct ContinueRow: View {
    let entry: CaseLibraryEntry
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10).fill(CasebookTheme.vermillionWash)
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "bookmark.fill").foregroundStyle(CasebookTheme.vermillion))
                VStack(alignment: .leading, spacing: 4) {
                    Text("継続中").font(CasebookTheme.body(10, weight: .bold)).foregroundStyle(CasebookTheme.vermillion)
                    Text(entry.record.titleJA).font(CasebookTheme.body(14, weight: .bold)).foregroundStyle(CasebookTheme.ink)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(CasebookTheme.inkFaint).font(.system(size: 13))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        }
        .buttonStyle(.plain)
    }
}

private struct CaseRow: View {
    let entry: CaseLibraryEntry
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                statusIcon
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.record.titleJA).font(CasebookTheme.body(13.5, weight: .semibold)).foregroundStyle(CasebookTheme.ink)
                    Text("約\(entry.record.estimatedMinutes)分・\(entry.status)").font(CasebookTheme.body(11)).foregroundStyle(CasebookTheme.inkFaint)
                }
                Spacer()
                if entry.record.isFree {
                    Tag(text: "無料", color: CasebookTheme.vermillion, background: CasebookTheme.vermillionWash)
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(CasebookTheme.indigo)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var statusIcon: some View {
        switch entry.status {
        case "完了": Image(systemName: "checkmark.circle.fill").foregroundStyle(CasebookTheme.indigoSoft)
        case "進行中": Circle().strokeBorder(CasebookTheme.gold, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2])).frame(width: 16, height: 16)
        default: Circle().strokeBorder(CasebookTheme.line, lineWidth: 1.5).frame(width: 16, height: 16)
        }
    }
}

struct Tag: View {
    let text: String
    let color: Color
    let background: Color
    var body: some View {
        Text(text)
            .font(CasebookTheme.body(11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(background))
    }
}
