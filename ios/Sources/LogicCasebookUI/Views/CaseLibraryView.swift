import SwiftUI
import SwiftData
import LogicCasebookEngine

/// The case library (docs/logic-casebook-locked-process-flow.md, section
/// 4.2). All four difficulty levels are visible from first launch; players
/// may attempt any available difficulty immediately. Lives inside the shell's
/// per-tab `NavigationStack`, so it declares destinations but no stack.
public struct CaseLibraryView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @Query(sort: \CaseProgress.lastPlayedAt, order: .reverse) private var records: [CaseProgress]
    @State private var tier: Difficulty = .beginner
    @State private var showingPurchase = false

    public init() {}

    public var body: some View {
        let progress = Dictionary(records.map { ($0.caseID, $0) }, uniquingKeysWith: { first, _ in first })
        let cases = CaseCatalog.byDifficulty[tier] ?? []
        let free = cases.filter(\.isFree)
        let paid = cases.filter { !$0.isFree }
        let solved = cases.filter { progress[$0.caseID]?.status == .completed }.count

        List {
            if let resume = continueCase(progress) {
                Section {
                    NavigationLink(value: resume) { ContinueRow(gameCase: resume, record: progress[resume.caseID]) }
                        .listRowBackground(Theme.accentSoft)
                }
            }

            Section {
                Picker("難易度", selection: $tier) {
                    ForEach(Difficulty.allCases, id: \.self) { Text($0.labelJA).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            } footer: {
                HStack {
                    Text("\(tier.labelJA) ・ \(cases.count)問")
                    Spacer()
                    Text("解決 \(solved) / \(cases.count)")
                }
                .padding(.top, 6)
            }

            Section("無料の事件 \(free.count)件") {
                ForEach(free) { row($0, progress: progress) }
            }

            Section {
                ForEach(paid) { row($0, progress: progress) }
            } header: {
                HStack {
                    Text("全編 \(paid.count)件")
                    Spacer()
                    if !entitlements.isFullUnlockPurchased {
                        Button("\(entitlements.fullUnlockProduct?.displayPrice ?? "¥1,800") で解放") {
                            showingPurchase = true
                        }
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("事件簿")
        .navigationDestination(for: Case.self) { CaseBriefingView(gameCase: $0) }
        .sheet(isPresented: $showingPurchase) { PurchaseSheetView() }
    }

    private func row(_ gameCase: Case, progress: [String: CaseProgress]) -> some View {
        CaseListRow(
            gameCase: gameCase,
            progress: progress[gameCase.caseID],
            isUnlocked: gameCase.isFree || entitlements.isFullUnlockPurchased,
            onLockedTap: { showingPurchase = true }
        )
        .listRowBackground(Theme.surface)
    }

    private func continueCase(_ progress: [String: CaseProgress]) -> Case? {
        guard let record = records.first(where: { $0.status == .inProgress }) else { return nil }
        return CaseCatalog.byID[record.caseID]
    }
}

private struct ContinueRow: View {
    let gameCase: Case
    let record: CaseProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("続きから")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text(gameCase.titleJA)
                .font(Theme.display(17))
                .foregroundStyle(Theme.ink)
            Text("第\(gameCase.number)号 ・ \(gameCase.difficulty.labelJA) ・ ヒント\(record?.hintsUsed ?? 0)回使用")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.vertical, 4)
    }
}
