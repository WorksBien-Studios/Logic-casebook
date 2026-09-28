import SwiftUI
import LogicCasebookEngine

/// One logic-grid cell. Shared between the tutorial illustration and the
/// real workspace grid so the two always look and animate identically.
struct CellView: View {
    let state: CellState
    let isFocused: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(stroke, style: StrokeStyle(lineWidth: lineWidth, dash: dash))
                    }
                    .overlay {
                        if isFocused {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(CasebookTheme.indigoSoft, lineWidth: 2)
                        }
                    }
                symbol
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .animation(.easeOut(duration: 0.12), value: state)
    }

    @ViewBuilder private var symbol: some View {
        switch state {
        case .blank: EmptyView()
        case .confirmed: Text("○").font(CasebookTheme.display(17, weight: .semiBold)).foregroundStyle(CasebookTheme.indigo)
        case .excluded: Text("×").font(.system(size: 15, weight: .semibold)).foregroundStyle(CasebookTheme.inkFaint)
        case .candidate: Text("△").font(.system(size: 13, weight: .bold)).foregroundStyle(CasebookTheme.gold)
        }
    }

    private var fill: Color {
        switch state {
        case .blank: CasebookTheme.paper
        case .confirmed: CasebookTheme.indigoWash
        case .excluded: CasebookTheme.paperAlt
        case .candidate: CasebookTheme.goldWash
        }
    }
    private var stroke: Color {
        switch state {
        case .blank: CasebookTheme.line
        case .confirmed: CasebookTheme.indigo
        case .excluded: CasebookTheme.line
        case .candidate: CasebookTheme.gold
        }
    }
    private var lineWidth: CGFloat { state == .confirmed || state == .candidate ? 1.5 : 1 }
    private var dash: [CGFloat] { state == .blank || state == .candidate ? [3, 3] : [] }

    private var accessibilityLabel: String {
        switch state {
        case .blank: "空欄"
        case .confirmed: "確定"
        case .excluded: "除外"
        case .candidate: "候補"
        }
    }
}
