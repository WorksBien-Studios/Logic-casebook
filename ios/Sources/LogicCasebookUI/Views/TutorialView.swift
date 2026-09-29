import SwiftUI
import LogicCasebookEngine

/// The first-launch tutorial (docs/logic-casebook-locked-process-flow.md,
/// section 4.1): one miniature case, the four cell states, clue check-off,
/// undo/redo/hints, then into the library. No account request, tracking
/// prompt, paywall or marketing screen precedes it. Replayable from Help via
/// `TutorialView(onFinish:)` reused outside first launch.
public struct TutorialView: View {
    public let onFinish: () -> Void

    @State private var page = 0
    @State private var demoMark: MarkState = .blank

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    private let pages: [(title: String, body: String)] = [
        ("完全論理事件簿へ", "手がかりを読み、確実にわかることだけを盤面に記していく推理パズルです。当てずっぽうは必要ありません。"),
        ("4つのマス状態", "マスをタップすると、空欄 → ○（確定） → ×（除外） → △（候補）の順に切り替わります。もう一度タップすると空欄に戻ります。"),
        ("手がかりと確認", "使い終わった手がかりはタップして確認済みにできます。「戻す」「やり直す」でいつでも操作を取り消せます。迷ったら「ヒント」が次の一手を教えてくれます。"),
    ]

    public var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 20) {
                        Spacer()
                        if index == 1 {
                            demoCell
                        }
                        Text(pages[index].title).font(Theme.display(24)).multilineTextAlignment(.center)
                        Text(pages[index].body)
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    page += 1
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "次へ" : "はじめる")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(20)
        }
        .background(Theme.background)
    }

    private var demoCell: some View {
        Button {
            demoMark = demoMark.next
        } label: {
            Text(symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 72, height: 72)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
        }
        .buttonStyle(.plain)
    }

    private var symbol: String {
        switch demoMark {
        case .blank: return "タップ"
        case .confirmed: return "○"
        case .excluded: return "×"
        case .candidate: return "△"
        }
    }

    private var color: Color {
        switch demoMark {
        case .blank: return Theme.inkFaint
        case .confirmed: return Theme.good
        case .excluded: return Theme.inkSoft
        case .candidate: return Theme.amber
        }
    }
}
