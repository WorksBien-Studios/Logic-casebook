import SwiftUI
import LogicCasebookEngine

/// The three drawn marks. Drawn as shapes, not font glyphs, so ○ × △ have the
/// same weight and optical size on every device and Dynamic Type setting.
struct MarkGlyph: View {
    let mark: MarkState
    var size: CGFloat = 26
    /// Legends and help show the empty state as a faint dash so the sample
    /// isn't a blank box; board cells leave it clear.
    var blankAsDash = false

    var body: some View {
        Group {
            switch mark {
            case .blank:
                if blankAsDash {
                    Capsule()
                        .fill(Theme.inkFaint)
                        .frame(width: size * 0.42, height: size * 0.08)
                } else {
                    Color.clear
                }
            case .confirmed:
                Circle()
                    .stroke(Theme.accent, lineWidth: size * 0.108)
                    .frame(width: size * 0.67, height: size * 0.67)
            case .excluded:
                CrossShape()
                    .stroke(Theme.inkFaint, style: StrokeStyle(lineWidth: size * 0.092, lineCap: .round))
                    .frame(width: size * 0.5, height: size * 0.5)
            case .candidate:
                TriangleShape()
                    .stroke(Theme.amber, style: StrokeStyle(lineWidth: size * 0.1, lineJoin: .round))
                    .frame(width: size * 0.67, height: size * 0.6)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct CrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
