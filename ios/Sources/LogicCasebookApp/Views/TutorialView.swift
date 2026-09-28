import SwiftUI
import LogicCasebookEngine

/// Spec §4.1: a short interactive tutorial using one miniature case, teaching
/// the four cell states and clue check-off/undo/redo/hints, before the
/// player ever sees the case library — no account request, tracking prompt
/// or paywall precedes it. Also reachable again from Help (§4.1's replay
/// requirement), hence `isPresentedFromHelp` rather than a one-shot flag.
public struct TutorialView: View {
    public let isPresentedFromHelp: Bool
    public let onFinished: () -> Void

    @State private var page = 0
    private let pageCount = 3

    public init(isPresentedFromHelp: Bool = false, onFinished: @escaping () -> Void) {
        self.isPresentedFromHelp = isPresentedFromHelp
        self.onFinished = onFinished
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                if isPresentedFromHelp {
                    Button("閉じる") { onFinished() }
                        .font(CasebookTheme.body(14, weight: .medium))
                } else {
                    Spacer().frame(width: 1)
                }
                Spacer()
                if page < pageCount - 1 {
                    Button("スキップ") { onFinished() }
                        .font(CasebookTheme.body(14, weight: .medium))
                        .foregroundStyle(CasebookTheme.inkSoft)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            TabView(selection: $page) {
                CellStatesTutorialPage().tag(0)
                ClueCheckOffTutorialPage().tag(1)
                ToolsTutorialPage().tag(2)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif

            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == page ? CasebookTheme.indigo : CasebookTheme.line)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 18)

            Button {
                if page < pageCount - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinished()
                }
            } label: {
                Text(page < pageCount - 1 ? "次へ" : "事件簿へ進む")
                    .font(CasebookTheme.body(15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(CasebookTheme.indigo)
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .casebookScreen()
    }
}

private struct TutorialPageScaffold<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(CasebookTheme.body(11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(CasebookTheme.inkFaint)
            Text(title)
                .font(CasebookTheme.display(26))
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(CasebookTheme.body(13.5))
                .foregroundStyle(CasebookTheme.inkSoft)
            content
                .padding(.top, 12)
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
    }
}

private struct CellStatesTutorialPage: View {
    var body: some View {
        TutorialPageScaffold(
            eyebrow: "TUTORIAL · 1 / 3",
            title: "セルの状態を\n覚えましょう",
            subtitle: "セルをタップするたびに状態が切り替わります。"
        ) {
            HStack(spacing: 14) {
                cellSample(state: .blank, label: "空欄")
                arrow
                cellSample(state: .confirmed, label: "確定")
                arrow
                cellSample(state: .excluded, label: "除外")
                arrow
                cellSample(state: .candidate, label: "候補")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var arrow: some View {
        Text("→").font(.system(size: 14)).foregroundStyle(CasebookTheme.inkFaint)
    }

    @ViewBuilder
    private func cellSample(state: CellState, label: String) -> some View {
        VStack(spacing: 8) {
            CellView(state: state, isFocused: false) {}
                .frame(width: 42, height: 42)
            Text(label)
                .font(CasebookTheme.body(10.5, weight: .bold))
                .foregroundStyle(state == .blank ? CasebookTheme.inkFaint : CasebookTheme.ink)
        }
    }
}

private struct ClueCheckOffTutorialPage: View {
    @State private var checked = true
    var body: some View {
        TutorialPageScaffold(
            eyebrow: "TUTORIAL · 2 / 3",
            title: "手がかりに\nチェックを付ける",
            subtitle: "確認した手がかりはチェックして、見落としを防ぎましょう。"
        ) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(checked ? CasebookTheme.indigo : CasebookTheme.line)
                    .font(.system(size: 20))
                    .onTapGesture { withAnimation { checked.toggle() } }
                Text("「凛」の相手は「木箱」ではない。")
                    .font(CasebookTheme.body(13.5))
                    .strikethrough(checked, color: CasebookTheme.inkFaint)
                    .foregroundStyle(checked ? CasebookTheme.inkFaint : CasebookTheme.ink)
            }
            .padding(14)
            .casebookCard()
        }
    }
}

private struct ToolsTutorialPage: View {
    var body: some View {
        TutorialPageScaffold(
            eyebrow: "TUTORIAL · 3 / 3",
            title: "元に戻す・ヒント",
            subtitle: "迷ったらいつでも元に戻せます。ヒントは次の一手だけを教えます。"
        ) {
            VStack(spacing: 10) {
                toolRow(systemImage: "arrow.uturn.backward", title: "元に戻す / やり直す", detail: "操作は何度でも取り消せます。")
                toolRow(systemImage: "lightbulb", title: "ヒント", detail: "手がかりの組み合わせと、次に確定できるマスだけを教えます。")
                toolRow(systemImage: "checkmark.seal", title: "解答を確認", detail: "間違っている場合も、答えそのものは表示しません。")
            }
        }
    }

    private func toolRow(systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(CasebookTheme.indigo)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(CasebookTheme.body(13.5, weight: .bold))
                Text(detail).font(CasebookTheme.body(12)).foregroundStyle(CasebookTheme.inkSoft)
            }
        }
    }
}
