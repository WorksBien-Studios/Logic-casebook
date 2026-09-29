import SwiftUI

/// The app's visual language: a warm, calm "casebook" palette per the
/// locked spec's requirement to keep the experience calm and uncluttered
/// (docs/logic-casebook-locked-process-flow.md, section 9).
public enum Theme {
    public static let background = Color(hex: 0xF7_F4_EE)
    public static let surface = Color(hex: 0xFF_FF_FF)
    public static let surfaceAlt = Color(hex: 0xFB_F9_F4)
    public static let border = Color(hex: 0xE4_DB_C9)

    public static let ink = Color(hex: 0x22_1D_17)
    public static let inkSoft = Color(hex: 0x6E_63_57)
    public static let inkFaint = Color(hex: 0xA7_9C_8C)

    public static let accent = Color(hex: 0xA8_40_2E)
    public static let accentSoft = Color(hex: 0xF3_DE_D7)

    public static let good = Color(hex: 0x3F_7D_5C)
    public static let goodSoft = Color(hex: 0xE1_EE_E6)

    public static let amber = Color(hex: 0xB8_86_2B)
    public static let amberSoft = Color(hex: 0xF5_EA_D4)

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
