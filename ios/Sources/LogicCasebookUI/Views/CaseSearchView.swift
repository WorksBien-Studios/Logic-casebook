import SwiftUI
import SwiftData
import iOS18Shell
import LogicCasebookEngine

/// Search across all 1,000 cases by title or case number. The shell wires
/// `.searchable` for the search-role tab; this view only reads the query.
public struct CaseSearchView: View {
    @Environment(\.appShellSearchQuery) private var query
    @EnvironmentObject private var entitlements: EntitlementStore
    @Query private var records: [CaseProgress]
    @State private var scope: Difficulty?
    @State private var showingPurchase = false

    public init() {}

    private var results: [Case] {
        let text = query.trimmingCharacters(in: .whitespaces)
        return CaseCatalog.cases.filter { gameCase in
            guard scope == nil || gameCase.difficulty == scope else { return false }
            guard !text.isEmpty else { return true }
            if gameCase.titleJA.contains(text) { return true }
            // "741" finds 0741 as well as "0741".
            if let number = Int(text), Int(gameCase.number) == number { return true }
            return gameCase.number.contains(text)
        }
    }

    public var body: some View {
        let progress = Dictionary(records.map { ($0.caseID, $0) }, uniquingKeysWith: { first, _ in first })
        let found = results

        List {
            Section {
                Picker("難易度", selection: $scope) {
                    Text("すべて").tag(Difficulty?.none)
                    ForEach(Difficulty.allCases, id: \.self) { Text($0.labelJA).tag(Difficulty?.some($0)) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            if !found.isEmpty {
                Section("\(found.count)件") {
                    ForEach(found.prefix(100)) { gameCase in
                        CaseListRow(
                            gameCase: gameCase,
                            progress: progress[gameCase.caseID],
                            isUnlocked: gameCase.isFree || entitlements.isFullUnlockPurchased,
                            onLockedTap: { showingPurchase = true }
                        )
                        .listRowBackground(Theme.surface)
                    }
                    if found.count > 100 {
                        Text("ほか \(found.count - 100) 件。ことばを足して絞り込めます。")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .overlay {
            if found.isEmpty { ContentUnavailableView.search(text: query) }
        }
        .navigationTitle("検索")
        .navigationDestination(for: Case.self) { CaseBriefingView(gameCase: $0) }
        .sheet(isPresented: $showingPurchase) { PurchaseSheetView() }
    }
}
