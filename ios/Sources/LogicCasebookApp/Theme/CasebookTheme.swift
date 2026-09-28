import SwiftUI
import LogicCasebookEngine

/// The look established in the product mockup, carried into real SwiftUI
/// code: warm washi-paper neutrals, indigo (藍) as the primary UI color, and
/// a muted vermillion (朱) reserved for the free-case tag and the
/// completion stamp — restrained rather than gamified, matching spec §4.4's
/// "no timers, lives, energy systems" tone. `Shippori Mincho` (a literary,
/// detective-novel register) titles paired with `Zen Kaku Gothic New` body
/// text; both degrade to the system Japanese font if unavailable.
public enum CasebookTheme {
    public static let paper = Color(red: 0.969, green: 0.949, blue: 0.906)
    public static let paperAlt = Color(red: 0.937, green: 0.906, blue: 0.831)
    public static let ink = Color(red: 0.129, green: 0.110, blue: 0.082)
    public static let inkSoft = Color(red: 0.420, green: 0.384, blue: 0.314)
    public static let inkFaint = Color(red: 0.651, green: 0.604, blue: 0.510)
    public static let line = Color(red: 0.863, green: 0.816, blue: 0.706)

    public static let indigo = Color(red: 0.169, green: 0.227, blue: 0.337)
    public static let indigoSoft = Color(red: 0.298, green: 0.365, blue: 0.502)
    public static let indigoWash = Color(red: 0.906, green: 0.918, blue: 0.945)

    public static let vermillion = Color(red: 0.675, green: 0.227, blue: 0.161)
    public static let vermillionWash = Color(red: 0.953, green: 0.882, blue: 0.855)

    public static let gold = Color(red: 0.663, green: 0.506, blue: 0.184)
    public static let goldWash = Color(red: 0.945, green: 0.902, blue: 0.788)

    /// `Font.custom(_:).weight(_:)` does not switch to a different physical
    /// font file for a custom family — each weight below names that
    /// weight's own bundled PostScript name (`Fonts/` in the app target,
    /// registered in `Info.plist`'s `UIAppFonts`) directly.
    public enum DisplayWeight { case regular, semiBold, extraBold
        var postScriptName: String {
            switch self {
            case .regular: "ShipporiMincho-Regular"
            case .semiBold: "ShipporiMincho-SemiBold"
            case .extraBold: "ShipporiMincho-ExtraBold"
            }
        }
    }
    public enum BodyWeight { case regular, medium, bold
        var postScriptName: String {
            switch self {
            case .regular: "ZenKakuGothicNew-Regular"
            case .medium: "ZenKakuGothicNew-Medium"
            case .bold: "ZenKakuGothicNew-Bold"
            }
        }
    }

    public static func display(_ size: CGFloat, weight: DisplayWeight = .semiBold) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: .title)
    }
    public static func body(_ size: CGFloat, weight: BodyWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: .body)
    }

    public static func diffuse(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .beginner: Color(red: 0.431, green: 0.545, blue: 0.416)
        case .standard: indigoSoft
        case .advanced: gold
        case .expert: vermillion
        }
    }
}

public extension View {
    /// Wraps the view in the casebook's paper background and default text
    /// color — applied once at each screen's root.
    func casebookScreen() -> some View {
        self
            .background(CasebookTheme.paper)
            .foregroundStyle(CasebookTheme.ink)
    }

    /// A hairline-bordered white card — the workspace, briefing and
    /// completion screens' shared surface. `Shape.fill(_:)` returns a plain
    /// `View`, which has no `.stroke`, so the border is a separate overlay
    /// rather than a chained shape modifier.
    func casebookCard(cornerRadius: CGFloat = 14) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(CasebookTheme.line, lineWidth: 1)
                )
        )
    }
}
