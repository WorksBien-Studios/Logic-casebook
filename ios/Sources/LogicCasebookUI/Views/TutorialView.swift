import SwiftUI
import LogicCasebookEngine

/// The first-launch tutorial (docs/logic-casebook-locked-process-flow.md,
/// section 4.1): the objective, the four cell states with a real cell to
/// tap, clue check-off, undo/redo/hints, then into the library. No account
/// request, tracking prompt, paywall or marketing screen precedes it. Also
/// replayed from Help.
public struct TutorialView: View {
    public let onFinish: () -> Void

    @State private var page = 0
    @State private var demoMark: MarkState = .blank

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    private let pages: [(title: String, body: String)] = [
        ("小さな事件で、ルールを確かめましょう", "手がかりだけを頼りに、人・物・時刻などの正しい組み合わせを見つけます。推測は必要ありません。全部で1分ほどです。"),
        ("マスは4つの状態に切り替わります", "タップするたびに 未入力 → ○ → × → △ の順に変わります。試してみてください。"),
        ("読んだ手がかりは、チェックして整理しましょう", "手がかりをタップすると確認済みになります。間違えたら「元に戻す」、行き詰まったら「ヒント」。ヒントは次の一手だけを教えます。"),
        ("準備ができました", "無料で30事件が遊べます。広告はなく、タイマーや時間制限もありません。いつでもヘルプから、この説明を見返せます。"),
    ]

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("スキップ", action: onFinish)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 12)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 20) {
                        Spacer()
                        illustration(for: index)
                        Text(pages[index].title)
                            .font(Theme.display(26))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.ink)
                        Text(pages[index].body)
                            .font(.body)
                            .lineSpacing(5)
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .frame(maxWidth: 560)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < pages.count - 1 { withAnimation { page += 1 } } else { onFinish() }
            } label: {
                Text(page < pages.count - 1 ? "次へ" : "事件簿を開く")
                    .font(.headline)
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .frame(maxWidth: 420)
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    @ViewBuilder
    private func illustration(for index: Int) -> some View {
        switch index {
        case 0:
            miniCase
        case 1:
            VStack(spacing: 14) {
                Button {
                    demoMark = demoMark.next
                } label: {
                    Group {
                        if demoMark == .blank {
                            Text("タップ").font(.footnote).foregroundStyle(Theme.inkFaint)
                        } else {
                            MarkGlyph(mark: demoMark, size: 64)
                        }
                    }
                    .frame(width: 96, height: 96)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.border, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("練習マス")
                .accessibilityValue(demoMark.labelJA)
                Text(demoMark.labelJA)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
        case 2:
            HStack(spacing: 18) {
                ForEach([("arrow.uturn.backward", "元に戻す"), ("arrow.uturn.forward", "やり直す"), ("lightbulb", "ヒント")], id: \.0) { icon, label in
                    VStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 60, height: 52)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border, lineWidth: 1))
                        Text(label).font(.caption).foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        default:
            HankoSeal(text: "開始", size: 96)
        }
    }

    /// One miniature case: a clue and the blank grid it will be solved on.
    private var miniCase: some View {
        let people = ["凛", "葵", "千尋"]
        let items = ["傘", "鍵", "帽子"]
        return VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("手がかり")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.accent)
                Text("「凛」の傘は、「葵」の傘より先に返されました。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .leading) { Rectangle().fill(Theme.accent).frame(width: 3) }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    Color.clear.frame(width: 44, height: 1)
                    ForEach(items, id: \.self) { item in
                        Text(item).font(.footnote.weight(.bold)).foregroundStyle(Theme.ink)
                            .frame(width: 54, height: 26)
                    }
                }
                ForEach(people, id: \.self) { person in
                    GridRow {
                        Text(person).font(.footnote.weight(.bold)).foregroundStyle(Theme.ink)
                            .frame(width: 44, alignment: .trailing).padding(.trailing, 8)
                        ForEach(items, id: \.self) { _ in
                            Rectangle().fill(Theme.surface)
                                .frame(width: 54, height: 54)
                                .overlay(Rectangle().strokeBorder(Theme.border, lineWidth: 0.5))
                        }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("凛、葵、千尋と、傘、鍵、帽子の空の表")

            Text("人と物の組み合わせを、マス目で整理します。")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: 360)
    }
}
