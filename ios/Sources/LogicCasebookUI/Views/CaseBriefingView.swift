import SwiftUI
import LogicCasebookEngine

/// The case briefing (docs/logic-casebook-locked-process-flow.md, section
/// 4.3): title, scenario, question, entities and categories, before play.
public struct CaseBriefingView: View {
    public let gameCase: Case

    public init(gameCase: Case) {
        self.gameCase = gameCase
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Badge(text: gameCase.difficulty.labelJA, color: gameCase.difficulty.badgeColor, background: gameCase.difficulty.badgeSoftColor)
                    if gameCase.isFree {
                        Badge(text: "無料", color: Theme.accent, background: Theme.accentSoft)
                    }
                    Badge(text: "目安\(gameCase.estimatedMinutes)分", color: Theme.inkSoft, background: Theme.surfaceAlt)
                }

                Text(gameCase.titleJA)
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.ink)

                Text(gameCase.scenarioJA)
                    .font(.subheadline)
                    .lineSpacing(4)
                    .foregroundStyle(Theme.ink)

                VStack(alignment: .leading, spacing: 6) {
                    Text("設問").font(.caption).foregroundStyle(Theme.inkFaint)
                    Text(gameCase.questionJA).font(.subheadline.weight(.semibold))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))

                ForEach(gameCase.categories) { category in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(category.nameJA).font(.caption).foregroundStyle(Theme.inkFaint)
                        FlowChips(labels: category.values.map(\.nameJA))
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            NavigationLink {
                LogicWorkspaceView(gameCase: gameCase)
            } label: {
                Text("はじめる")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(20)
            .background(Theme.background)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Badge: View {
    let text: String
    let color: Color
    let background: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }
}

private struct FlowChips: View {
    let labels: [String]

    var body: some View {
        // A simple wrapping row; the case's category cardinality is small
        // (3-5 values), so a plain HStack with wrapping via LazyVGrid-style
        // flexible columns is unnecessary — a scrollable row reads cleanly
        // at this size.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Theme.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.border))
                }
            }
        }
    }
}
