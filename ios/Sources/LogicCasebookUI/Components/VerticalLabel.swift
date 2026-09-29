import SwiftUI

/// Vertical (縦書き) label for grid column headers. SwiftUI has no vertical
/// writing mode, so each character is stacked. Runs of up to two digits stay
/// together (13時 reads as "13" over "時") and the long-vowel mark ー is
/// rotated, as in printed vertical Japanese.
struct VerticalLabel: View {
    let text: String
    var font: Font = .footnote.weight(.medium)

    private struct Token: Identifiable {
        let id: Int
        let text: String
        var rotated: Bool { text == "ー" }
    }

    private var tokens: [Token] {
        var result: [String] = []
        var digits = ""
        for character in text {
            if character.isASCII, character.isNumber {
                if digits.count == 2 { result.append(digits); digits = "" }
                digits.append(character)
            } else {
                if !digits.isEmpty { result.append(digits); digits = "" }
                result.append(String(character))
            }
        }
        if !digits.isEmpty { result.append(digits) }
        return result.enumerated().map { Token(id: $0.offset, text: $0.element) }
    }

    /// Number of stacked lines this label needs; used to size header rows.
    static func lineCount(_ text: String) -> Int {
        VerticalLabel(text: text).tokens.count
    }

    var body: some View {
        VStack(spacing: 1) {
            ForEach(tokens) { token in
                Text(token.text)
                    .rotationEffect(token.rotated ? .degrees(90) : .zero)
            }
        }
        .font(font)
        .foregroundStyle(Theme.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
