import SwiftUI
import SwiftData
import LogicCasebookEngine

/// The briefing body: title, scenario, the question, category values and
/// facts about the case. Shared by the pre-play screen and the sheet that
/// stays available during play (locked spec, section 4.3).
struct CaseBriefingContent: View {
    let gameCase: Case

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text(gameCase.difficulty.labelJA)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(gameCase.difficulty.badgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(gameCase.difficulty.badgeSoftColor, in: Capsule())
                Text("第\(gameCase.number)号")
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaint)
            }

            Text(gameCase.titleJA)
                .font(Theme.display(26))
                .foregroundStyle(Theme.ink)

            Text(gameCase.scenarioJA)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(Theme.ink)

            VStack(alignment: .leading, spacing: 4) {
                Text("問い").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                Text(gameCase.questionJA).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.accent).frame(width: 3).clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 14) {
                Label("約\(gameCase.estimatedMinutes)分", systemImage: "clock")
                Label("手がかり\(gameCase.clues.count)件", systemImage: "list.bullet")
                Label("推測は不要", systemImage: "checkmark.seal")
            }
            .font(.footnote)
            .foregroundStyle(Theme.inkSoft)

            VStack(spacing: 0) {
                ForEach(Array(gameCase.categories.enumerated()), id: \.element.id) { index, category in
                    HStack(alignment: .top, spacing: 12) {
                        Text(category.nameJA)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.categoryColor(index))
                            .frame(width: 64, alignment: .leading)
                            .padding(.top, 4)
                        FlowLayout(spacing: 6) {
                            ForEach(category.values) { value in
                                Text(value.nameJA)
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Theme.surfaceAlt, in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border, lineWidth: 1))
                            }
                            if category.ordered {
                                Text("左から早い順").font(.caption).foregroundStyle(Theme.inkFaint).padding(.leading, 4)
                            }
                        }
                    }
                    .padding(12)
                    if index < gameCase.categories.count - 1 { Divider() }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// The case briefing (docs/logic-casebook-locked-process-flow.md, section 4.3).
public struct CaseBriefingView: View {
    public let gameCase: Case
    @Query private var records: [CaseProgress]

    public init(gameCase: Case) {
        self.gameCase = gameCase
        let id = gameCase.caseID
        _records = Query(filter: #Predicate<CaseProgress> { $0.caseID == id })
    }

    private var isInProgress: Bool { records.first?.status == .inProgress }

    public var body: some View {
        ScrollView {
            CaseBriefingContent(gameCase: gameCase)
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            NavigationLink {
                LogicWorkspaceView(gameCase: gameCase)
            } label: {
                Text(isInProgress ? "続きから再開" : "捜査を始める")
                    .font(.headline)
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
