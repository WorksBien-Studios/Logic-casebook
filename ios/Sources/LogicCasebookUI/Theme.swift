import SwiftUI
import UIKit
import LogicCasebookEngine

/// The app's visual language: warm paper, 朱 (vermilion) accent, calm and
/// uncluttered per the locked spec (docs/logic-casebook-locked-process-flow.md,
/// section 9). Every colour has a light and a dark value, matching
/// docs/ui-mock/index.html.
public enum Theme {
    public static let background = Color(light: 0xF7_F4_EE, dark: 0x15_12_10)
    public static let surface = Color(light: 0xFF_FF_FF, dark: 0x20_1C_19)
    public static let surfaceAlt = Color(light: 0xFB_F9_F4, dark: 0x1B_18_15)
    public static let border = Color(light: 0xE4_DB_C9, dark: 0x3A_34_2E)

    public static let ink = Color(light: 0x22_1D_17, dark: 0xED_E6_DA)
    public static let inkSoft = Color(light: 0x6E_63_57, dark: 0xB0_A6_9A)
    public static let inkFaint = Color(light: 0xA7_9C_8C, dark: 0x7C_73_68)

    public static let accent = Color(light: 0xA8_40_2E, dark: 0xE0_82_67)
    public static let accentSoft = Color(light: 0xF3_DE_D7, dark: 0x3A_26_21)

    public static let good = Color(light: 0x3F_7D_5C, dark: 0x6F_BF_93)
    public static let goodSoft = Color(light: 0xE1_EE_E6, dark: 0x1F_2E_26)

    public static let amber = Color(light: 0xB8_86_2B, dark: 0xDD_AE_55)
    public static let amberSoft = Color(light: 0xF5_EA_D4, dark: 0x37_2C_16)

    /// Text on a filled accent button. Dark accent is light, so it needs dark text.
    public static let onAccent = Color(light: 0xFF_FF_FF, dark: 0x1A_13_10)

    /// One colour per category (人物, 物, 場所, 時刻...), reused on the grid
    /// headers, the briefing chips and the names inside clue sentences so
    /// players learn the mapping once.
    public static func categoryColor(_ index: Int) -> Color {
        switch index % 4 {
        case 0: return Color(light: 0xA8_40_2E, dark: 0xE0_82_67)
        case 1: return Color(light: 0x2F_5D_8A, dark: 0x7F_B0_E0)
        case 2: return Color(light: 0x3F_7D_5C, dark: 0x7C_C3_9E)
        default: return Color(light: 0x9A_6E_14, dark: 0xDD_AE_55)
        }
    }

    public static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Difficulty {
    public var badgeColor: Color {
        switch self {
        case .beginner: return Theme.good
        case .standard: return Theme.amber
        case .advanced: return Theme.accent
        case .expert: return Theme.ink
        }
    }

    public var badgeSoftColor: Color {
        switch self {
        case .beginner: return Theme.goodSoft
        case .standard: return Theme.amberSoft
        case .advanced: return Theme.accentSoft
        case .expert: return Theme.surfaceAlt
        }
    }
}

extension MarkState {
    /// Spoken and written name of a cell state.
    var labelJA: String {
        switch self {
        case .blank: return "未入力"
        case .confirmed: return "確定 ○"
        case .excluded: return "除外 ×"
        case .candidate: return "候補 △"
        }
    }
}
