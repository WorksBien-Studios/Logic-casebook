import Foundation

/// One cell of a pair grid: does `rowValueID` (in `rowCategoryID`) belong to
/// `columnValueID` (in `columnCategoryID`)?
///
/// The row category always comes before the column category in
/// `Case.categories`, so a given pair of values has exactly one key no matter
/// which order a clue or hint names them in. Unlike `GridKey`, a pair key can
/// relate any two categories (e.g. an object to a time), not only the primary
/// category to another one.
public struct PairKey: Hashable, Codable, Sendable {
    public let rowCategoryID: String
    public let rowValueID: String
    public let columnCategoryID: String
    public let columnValueID: String

    public init(rowCategoryID: String, rowValueID: String, columnCategoryID: String, columnValueID: String) {
        self.rowCategoryID = rowCategoryID
        self.rowValueID = rowValueID
        self.columnCategoryID = columnCategoryID
        self.columnValueID = columnValueID
    }
}

/// A pair of categories that share one grid block: rows come from
/// `categories[rowIndex]`, columns from `categories[columnIndex]`, with
/// `rowIndex < columnIndex`.
public struct CategoryPair: Hashable, Identifiable, Sendable {
    public let rowIndex: Int
    public let columnIndex: Int

    public var id: String { "\(rowIndex)-\(columnIndex)" }

    public init(rowIndex: Int, columnIndex: Int) {
        self.rowIndex = rowIndex
        self.columnIndex = columnIndex
    }
}

extension Case {
    /// Every category pair, in reading order: (0,1), (0,2), ..., (1,2), ...
    public var categoryPairs: [CategoryPair] {
        var pairs: [CategoryPair] = []
        for row in categories.indices {
            for column in categories.indices where column > row {
                pairs.append(CategoryPair(rowIndex: row, columnIndex: column))
            }
        }
        return pairs
    }

    /// The key for the cell relating two entities, or `nil` if they are in
    /// the same category or either category is unknown.
    public func pairKey(_ first: EntityRef, _ second: EntityRef) -> PairKey? {
        guard let firstIndex = categories.firstIndex(where: { $0.id == first.categoryID }),
              let secondIndex = categories.firstIndex(where: { $0.id == second.categoryID }),
              firstIndex != secondIndex else { return nil }
        let (row, column) = firstIndex < secondIndex ? (first, second) : (second, first)
        return PairKey(
            rowCategoryID: row.categoryID,
            rowValueID: row.valueID,
            columnCategoryID: column.categoryID,
            columnValueID: column.valueID
        )
    }

    /// The key for the cell at `pair`, row value `rowValue`, column value `columnValue`.
    public func pairKey(_ pair: CategoryPair, row rowValue: CategoryValue, column columnValue: CategoryValue) -> PairKey {
        PairKey(
            rowCategoryID: categories[pair.rowIndex].id,
            rowValueID: rowValue.id,
            columnCategoryID: categories[pair.columnIndex].id,
            columnValueID: columnValue.id
        )
    }
}

/// Checks a player's pair grid against the bundled solution.
///
/// - A confirmed `○` on a pairing the solution does not contain, or an
///   excluded `×` on one it does, is a contradiction.
/// - Otherwise the grid is correct once every pairing in the solution is
///   confirmed, and incomplete until then. `×` and `△` marks never count
///   towards completeness, so a player is not forced to fill in every `×`.
///
/// Like `SolutionChecker`, this never reports *which* cells are missing or
/// wrong (locked spec, section 4.6).
public enum PairSolutionChecker {
    public static func check(_ gameCase: Case, marks: [PairKey: MarkState]) -> CheckResult {
        // category id -> value id -> index of the solution row that holds it.
        var rowOf: [String: [String: Int]] = [:]
        for (index, row) in gameCase.solution.rows.enumerated() {
            for (categoryID, valueID) in row {
                rowOf[categoryID, default: [:]][valueID] = index
            }
        }

        var confirmedTrue = 0
        for (key, mark) in marks {
            guard let rowIndex = rowOf[key.rowCategoryID]?[key.rowValueID],
                  let columnIndex = rowOf[key.columnCategoryID]?[key.columnValueID] else { continue }
            let isTrue = rowIndex == columnIndex
            switch mark {
            case .confirmed:
                if isTrue { confirmedTrue += 1 } else { return .contradiction }
            case .excluded:
                if isTrue { return .contradiction }
            case .blank, .candidate:
                break
            }
        }

        let valueCount = gameCase.primaryCategory.values.count
        let needed = gameCase.categoryPairs.count * valueCount
        return confirmedTrue == needed ? .correct : .incomplete
    }
}

/// Derives hints from the bundled deduction path (locked spec, section 4.5).
public enum HintPlanner {
    /// The first deduction step whose facts are not all confirmed on the grid yet.
    public static func nextStep(in gameCase: Case, marks: [PairKey: MarkState]) -> DeductionStep? {
        gameCase.deductionSteps.first { !isApplied($0, in: gameCase, marks: marks) }
    }

    /// `marks` with every `same` fact of `step` confirmed.
    public static func applying(_ step: DeductionStep, to marks: [PairKey: MarkState], in gameCase: Case) -> [PairKey: MarkState] {
        var updated = marks
        for fact in step.deducedFacts where fact.relation == "same" {
            if let key = gameCase.pairKey(fact.left, fact.right) {
                updated[key] = .confirmed
            }
        }
        return updated
    }

    public static func isApplied(_ step: DeductionStep, in gameCase: Case, marks: [PairKey: MarkState]) -> Bool {
        step.deducedFacts.allSatisfy { fact in
            guard fact.relation == "same", let key = gameCase.pairKey(fact.left, fact.right) else { return true }
            return marks[key] == .confirmed
        }
    }
}

/// Undo/redo over whole-grid snapshots. A grid has at most a few hundred
/// cells, so snapshots are cheaper to reason about than per-cell diffs.
public struct MarkHistory: Sendable {
    public static let limit = 200

    private var undoStack: [[PairKey: MarkState]] = []
    private var redoStack: [[PairKey: MarkState]] = []

    public init() {}

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Call with the grid as it is *before* a change is applied.
    public mutating func record(_ current: [PairKey: MarkState]) {
        undoStack.append(current)
        if undoStack.count > Self.limit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    public mutating func undo(from current: [PairKey: MarkState]) -> [PairKey: MarkState]? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }

    public mutating func redo(from current: [PairKey: MarkState]) -> [PairKey: MarkState]? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }
}
