import SwiftUI
import LogicCasebookEngine

extension ClueType {
    /// Short tag shown above a clue so players can scan by kind.
    var tagJA: String {
        switch self {
        case .same: return "同じ組"
        case .different: return "別の組"
        case .either: return "どちらか"
        case .pairSet: return "組み合わせ"
        case .before: return "順序"
        case .immediatelyBefore: return "直前"
        case .offsetBefore: return "間隔"
        }
    }
}

/// One clue as a checklist row: kind tag, the full reviewed Japanese sentence
/// with names coloured by category, and a small strip for order clues.
/// Tapping toggles "reviewed" (locked spec, section 9).
struct ClueRow: View {
    let gameCase: Case
    let clue: Clue
    let index: Int
    var isChecked = false
    /// `nil` renders a static row (used inside the hint sheet).
    var onToggle: (() -> Void)?

    var body: some View {
        if let onToggle {
            Button(action: onToggle) { content }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isChecked ? .isSelected : [])
                .accessibilityHint("タップで確認済みを切り替え")
        } else {
            content
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 10) {
            if onToggle != nil {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isChecked ? Theme.good : Theme.inkFaint)
                    .padding(.top, 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("手がかり \(index + 1)")
                    Text(clue.type.tagJA)
                        .padding(.horizontal, 6)
                        .background(Theme.surfaceAlt, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.border, lineWidth: 1))
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.inkSoft)

                Text(Self.attributed(clue.textJA, in: gameCase))
                    .font(.callout)
                    .strikethrough(isChecked, color: Theme.border)
                    .foregroundStyle(isChecked ? Theme.inkFaint : Theme.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                OrderingStrip(gameCase: gameCase, clue: clue)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isChecked ? Color.clear : Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    /// The sentence with each 「name」 coloured by the category it belongs to.
    static func attributed(_ text: String, in gameCase: Case) -> AttributedString {
        var result = AttributedString()
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "「"), let close = rest[open...].firstIndex(of: "」") {
            result += AttributedString(String(rest[..<open]))
            result += AttributedString("「")
            let name = String(rest[rest.index(after: open)..<close])
            var part = AttributedString(name)
            if let category = gameCase.categoryIndex(forValueNamed: name) {
                part.foregroundColor = Theme.categoryColor(category)
            }
            part.font = .callout.bold()
            result += part
            result += AttributedString("」")
            rest = rest[rest.index(after: close)...]
        }
        result += AttributedString(String(rest))
        return result
    }
}

/// A tiny picture of an ordering clue: 前 (somewhere before), 直前 (next to)
/// or n つ前 (n steps before). Text stays the source of truth; this is a
/// glance aid, so it is hidden from VoiceOver.
private struct OrderingStrip: View {
    let gameCase: Case
    let clue: Clue

    var body: some View {
        if case let .ordering(left, right, orderedCategory, offset) = clue.args,
           let leftEntity = gameCase.entity(left),
           let rightEntity = gameCase.entity(right) {
            let categoryName = gameCase.categories.first { $0.id == orderedCategory }?.nameJA ?? ""
            HStack(spacing: 4) {
                chip(leftEntity.name, category: leftEntity.categoryIndex)
                connector(offset: offset)
                chip(rightEntity.name, category: rightEntity.categoryIndex)
                Text("\(categoryName)：\(caption(offset: offset))")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.leading, 4)
            }
            .accessibilityHidden(true)
        }
    }

    private func chip(_ name: String, category: Int) -> some View {
        Text(name)
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.categoryColor(category))
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.categoryColor(category), lineWidth: 1.5))
    }

    @ViewBuilder
    private func connector(offset: Int?) -> some View {
        HStack(spacing: 3) {
            switch clue.type {
            case .immediatelyBefore:
                line(width: 12)
            case .offsetBefore:
                ForEach(0..<max(0, (offset ?? 2) - 1), id: \.self) { _ in
                    Circle().fill(Theme.border).frame(width: 8, height: 8)
                }
                line(width: 10)
            default:
                line(width: 24, dashed: true)
            }
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 7))
                .foregroundStyle(Theme.inkFaint)
        }
    }

    private func line(width: CGFloat, dashed: Bool = false) -> some View {
        Rectangle()
            .fill(Theme.inkFaint)
            .frame(width: width, height: 2)
            .mask {
                if dashed {
                    HStack(spacing: 3) {
                        ForEach(0..<Int(width / 6), id: \.self) { _ in Rectangle().frame(width: 3) }
                    }
                } else {
                    Rectangle()
                }
            }
    }

    private func caption(offset: Int?) -> String {
        switch clue.type {
        case .immediatelyBefore: return "すぐ前（隣）"
        case .offsetBefore: return "\(offset ?? 2)つ前"
        default: return "どこかで前"
        }
    }
}
