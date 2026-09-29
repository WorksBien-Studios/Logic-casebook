import SwiftUI
import SwiftData
import LogicCasebookEngine
import LogicCasebookContent

/// The case library (docs/logic-casebook-locked-process-flow.md, section
/// 4.2). All four difficulty levels are visible from first launch; players
/// may attempt any available difficulty immediately.
public struct CaseLibraryView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @Query(sort: \CaseProgress.lastPlayedAt, order: .reverse) private var progressRecords: [CaseProgress]
    @State private var showingPurchaseSheet = false

    private let cases = BundledContent.bundle().cases

    public init() {}

    private var continueEntry: (Case, CaseProgress)? {
        guard let record = progressRecords.first(where: { $0.status == .inProgress }),
              let gameCase = cases.first(where: { $0.caseID == record.caseID }) else { return nil }
        return (gameCase, record)
    }

    public var body: some View {
        NavigationStack {
            List {
                if let (gameCase, record) = continueEntry {
                    Section {
                        NavigationLink(value: gameCase) {
                            ContinueRow(gameCase: gameCase, record: record)
                        }
                    }
                }
                ForEach(Difficulty.allCases, id: \.self) { difficulty in
                    let casesInTier = cases.filter { $0.difficulty == difficulty }
                    Section {
                        ForEach(casesInTier) { gameCase in
                            row(for: gameCase)
                        }
                    } header: {
                        DifficultyHeader(difficulty: difficulty, cases: casesInTier)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("事件簿")
            .navigationDestination(for: Case.self) { gameCase in
                CaseBriefingView(gameCase: gameCase)
            }
        }
        .sheet(isPresented: $showingPurchaseSheet) {
            PurchaseSheetView()
        }
    }

    @ViewBuilder
    private func row(for gameCase: Case) -> some View {
        let unlocked = gameCase.isFree || entitlements.isFullUnlockPurchased
        let status = progressRecords.first { $0.caseID == gameCase.caseID }?.status ?? .notStarted
        if unlocked {
            NavigationLink(value: gameCase) {
                CaseRow(gameCase: gameCase, isUnlocked: true, status: status)
            }
        } else {
            Button {
                showingPurchaseSheet = true
            } label: {
                CaseRow(gameCase: gameCase, isUnlocked: false, status: status)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct DifficultyHeader: View {
    let difficulty: Difficulty
    let cases: [Case]

    var body: some View {
        HStack {
            Text(difficulty.labelJA)
            Spacer()
            Text("\(cases.count)問 · \(cases.filter(\.isFree).count)問無料")
        }
    }
}

private struct CaseRow: View {
    let gameCase: Case
    let isUnlocked: Bool
    let status: ProgressStatus

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isUnlocked ? Theme.goodSoft : Theme.accentSoft)
                Image(systemName: isUnlocked ? "checkmark.circle" : "lock.fill")
                    .foregroundStyle(isUnlocked ? Theme.good : Theme.accent)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(gameCase.titleJA)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let priceOrFree = isUnlocked ? (gameCase.isFree ? "無料" : "購入済み") : "¥1,800で解放"
        let statusText: String
        switch status {
        case .notStarted: statusText = "未着手"
        case .inProgress: statusText = "進行中"
        case .completed: statusText = "クリア済み"
        }
        return "\(priceOrFree) · 目安\(gameCase.estimatedMinutes)分 · \(statusText)"
    }
}

private struct ContinueRow: View {
    let gameCase: Case
    let record: CaseProgress

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Theme.amberSoft)
                Image(systemName: "star.fill").foregroundStyle(Theme.amber)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("続きから").font(.caption).foregroundStyle(Theme.inkFaint)
                Text(gameCase.titleJA).font(.subheadline.weight(.semibold))
                Text("進行中 · ヒント\(record.hintsUsed)回使用")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }
}
