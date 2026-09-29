import SwiftUI
import LogicCasebookEngine

/// Sizes shared by every piece of the pair grid so headers, rows and cells
/// line up exactly.
struct GridMetrics {
    let cell: CGFloat
    let rowHeaderWidth: CGFloat
    let columnHeaderHeight: CGFloat

    init(gameCase: Case, cell: CGFloat, characterWidth: CGFloat = 15) {
        self.cell = cell
        let names = gameCase.categories.flatMap { $0.values.map(\.nameJA) }
        let longestRow = names.map(\.count).max() ?? 3
        let longestColumn = names.map { VerticalLabel.lineCount($0) }.max() ?? 3
        rowHeaderWidth = max(64, CGFloat(longestRow) * characterWidth + 22)
        columnHeaderHeight = max(62, CGFloat(longestColumn) * (characterWidth + 1) + 14)
    }
}

/// Which marks a cell shows, and what to do when it is tapped or chosen from
/// the long-press menu.
struct PairGridActions {
    let marks: [PairKey: MarkState]
    let onTap: (PairKey) -> Void
    let onSet: (PairKey, MarkState) -> Void
}

struct PairColumnHeaders: View {
    let category: CaseCategory
    let categoryIndex: Int
    let metrics: GridMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(category.nameJA)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.categoryColor(categoryIndex))
                if category.ordered {
                    Spacer(minLength: 4)
                    Text("早 → 遅").font(.caption2).foregroundStyle(Theme.inkFaint)
                }
            }
            .frame(width: metrics.cell * CGFloat(category.values.count))
            HStack(spacing: 0) {
                ForEach(category.values) { value in
                    VerticalLabel(text: value.nameJA)
                        .padding(.top, 6)
                        .frame(width: metrics.cell, height: metrics.columnHeaderHeight, alignment: .top)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.categoryColor(categoryIndex)).frame(height: 2.5)
            }
        }
    }
}

struct PairRowHeaders: View {
    let category: CaseCategory
    let categoryIndex: Int
    let metrics: GridMetrics

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(category.values) { value in
                Text(value.nameJA)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.trailing, 8)
                    .frame(width: metrics.rowHeaderWidth, height: metrics.cell, alignment: .trailing)
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.categoryColor(categoryIndex)).frame(width: 2.5)
        }
    }
}

/// The cells of one category pair. Tap cycles ○ → × → △ → blank; a long press
/// opens a menu to pick a state directly (also the accessible path).
struct PairCells: View {
    let gameCase: Case
    let pair: CategoryPair
    let metrics: GridMetrics
    let actions: PairGridActions

    private var rowCategory: CaseCategory { gameCase.categories[pair.rowIndex] }
    private var columnCategory: CaseCategory { gameCase.categories[pair.columnIndex] }

    var body: some View {
        // A confirmed ○ rules out the rest of its row and column: blank cells
        // there get a faint fill, but are never filled in for the player.
        let confirmedRows = Set(rowCategory.values.filter { row in
            columnCategory.values.contains { actions.marks[gameCase.pairKey(pair, row: row, column: $0)] == .confirmed }
        }.map(\.id))
        let confirmedColumns = Set(columnCategory.values.filter { column in
            rowCategory.values.contains { actions.marks[gameCase.pairKey(pair, row: $0, column: column)] == .confirmed }
        }.map(\.id))

        VStack(spacing: 0) {
            ForEach(rowCategory.values) { row in
                HStack(spacing: 0) {
                    ForEach(columnCategory.values) { column in
                        let key = gameCase.pairKey(pair, row: row, column: column)
                        let mark = actions.marks[key] ?? .blank
                        let ruledOut = mark == .blank && (confirmedRows.contains(row.id) || confirmedColumns.contains(column.id))
                        cell(key: key, mark: mark, ruledOut: ruledOut, row: row.nameJA, column: column.nameJA)
                    }
                }
            }
        }
        .overlay(Rectangle().strokeBorder(Theme.border, lineWidth: 1))
    }

    private func cell(key: PairKey, mark: MarkState, ruledOut: Bool, row: String, column: String) -> some View {
        Button {
            actions.onTap(key)
        } label: {
            MarkGlyph(mark: mark, size: metrics.cell * 0.6)
                .frame(width: metrics.cell, height: metrics.cell)
                .background(ruledOut ? Theme.border.opacity(0.35) : Theme.surface)
                .overlay(Rectangle().strokeBorder(Theme.border, lineWidth: 0.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            ForEach(MarkState.allCases, id: \.self) { state in
                Button(state.labelJA) { actions.onSet(key, state) }
            }
        }
        .accessibilityLabel("\(row)と\(column)")
        .accessibilityValue(mark.labelJA)
        .accessibilityHint("ダブルタップで切り替え")
    }
}

/// One category pair on its own: corner label, column headers, row headers
/// and cells. This is the iPhone and iPad single-column board.
struct PairBlockView: View {
    let gameCase: Case
    let pair: CategoryPair
    let metrics: GridMetrics
    let actions: PairGridActions

    var body: some View {
        let rowCategory = gameCase.categories[pair.rowIndex]
        let columnCategory = gameCase.categories[pair.columnIndex]
        Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow(alignment: .bottom) {
                Text(rowCategory.nameJA)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.categoryColor(pair.rowIndex))
                    .frame(width: metrics.rowHeaderWidth, alignment: .trailing)
                    .padding(.bottom, 4)
                PairColumnHeaders(category: columnCategory, categoryIndex: pair.columnIndex, metrics: metrics)
            }
            GridRow {
                PairRowHeaders(category: rowCategory, categoryIndex: pair.rowIndex, metrics: metrics)
                PairCells(gameCase: gameCase, pair: pair, metrics: metrics, actions: actions)
            }
        }
    }
}

/// Every category pair at once, in the classic staircase: column headers
/// across the top for categories 2...n, row headers down the left for
/// categories 1...n-1, and one block of cells wherever a row category
/// precedes a column category. Used on wide iPads next to the clue list.
struct StaircaseView: View {
    let gameCase: Case
    let metrics: GridMetrics
    let actions: PairGridActions

    var body: some View {
        let count = gameCase.categories.count
        Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 16) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                ForEach(1..<count, id: \.self) { column in
                    PairColumnHeaders(category: gameCase.categories[column], categoryIndex: column, metrics: metrics)
                }
            }
            ForEach(0..<(count - 1), id: \.self) { row in
                GridRow {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(gameCase.categories[row].nameJA)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.categoryColor(row))
                        PairRowHeaders(category: gameCase.categories[row], categoryIndex: row, metrics: metrics)
                    }
                    ForEach(1..<count, id: \.self) { column in
                        if column > row {
                            PairCells(
                                gameCase: gameCase,
                                pair: CategoryPair(rowIndex: row, columnIndex: column),
                                metrics: metrics,
                                actions: actions
                            )
                        } else {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    }
                }
            }
        }
    }
}

enum PairProgress {
    case none, partial, complete

    /// `complete` once every row of the pair has a confirmed ○; `partial`
    /// once any mark has been made. Says nothing about correctness.
    static func state(of pair: CategoryPair, in gameCase: Case, marks: [PairKey: MarkState]) -> PairProgress {
        let rows = gameCase.categories[pair.rowIndex].values
        let columns = gameCase.categories[pair.columnIndex].values
        var anyMark = false
        var confirmedRows = 0
        for row in rows {
            var rowConfirmed = false
            for column in columns {
                let mark = marks[gameCase.pairKey(pair, row: row, column: column)] ?? .blank
                if mark != .blank { anyMark = true }
                if mark == .confirmed { rowConfirmed = true }
            }
            if rowConfirmed { confirmedRows += 1 }
        }
        if confirmedRows == rows.count { return .complete }
        return anyMark ? .partial : .none
    }
}

/// Overview of every category pair. Tapping a tile selects that pair on the
/// board; tile colour shows how far along it is.
struct PairMiniMap: View {
    let gameCase: Case
    let marks: [PairKey: MarkState]
    @Binding var selection: CategoryPair

    var body: some View {
        let count = gameCase.categories.count
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            ForEach(0..<(count - 1), id: \.self) { row in
                GridRow {
                    ForEach(1..<count, id: \.self) { column in
                        if column > row {
                            tile(CategoryPair(rowIndex: row, columnIndex: column))
                        } else {
                            Color.clear.frame(width: 44, height: 32)
                        }
                    }
                }
            }
        }
    }

    private func tile(_ pair: CategoryPair) -> some View {
        let state = PairProgress.state(of: pair, in: gameCase, marks: marks)
        let isSelected = pair == selection
        return Button {
            selection = pair
        } label: {
            HStack(spacing: 4) {
                Circle().fill(Theme.categoryColor(pair.rowIndex)).frame(width: 9, height: 9)
                Circle().fill(Theme.categoryColor(pair.columnIndex)).frame(width: 9, height: 9)
            }
            .frame(width: 44, height: 32)
            .background(fill(state), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(stroke(state), lineWidth: 1.5))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.accent, lineWidth: 2).padding(-2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(gameCase.categories[pair.rowIndex].nameJA)と\(gameCase.categories[pair.columnIndex].nameJA)")
        .accessibilityValue(state == .complete ? "確定済み" : state == .partial ? "入力中" : "未入力")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func fill(_ state: PairProgress) -> Color {
        switch state {
        case .none: return Theme.surfaceAlt
        case .partial: return Theme.amberSoft
        case .complete: return Theme.goodSoft
        }
    }

    private func stroke(_ state: PairProgress) -> Color {
        switch state {
        case .none: return Theme.border
        case .partial: return Theme.amber
        case .complete: return Theme.good
        }
    }
}
