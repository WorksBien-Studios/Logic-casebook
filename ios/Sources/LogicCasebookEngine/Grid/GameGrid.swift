import Foundation

/// A single logic-grid cell's state. Spec: "Cell input cycles through
/// blank → ○ → × → △ → blank."
public enum CellState: Int, Codable, Hashable, Sendable {
    case blank, confirmed, excluded, candidate

    public var next: CellState {
        switch self {
        case .blank: .confirmed
        case .confirmed: .excluded
        case .excluded: .candidate
        case .candidate: .blank
        }
    }
}

/// The player's marks for one case: one `CellState` per (owner, assigned
/// category, value) triple, i.e. one classic n×n cross-out grid per
/// non-primary category. Pure value data — `Codable` for local save/restore,
/// no UI or persistence-framework dependency.
public struct GameGrid: Codable, Equatable, Sendable {
    /// `cells[categoryOffset][owner][value]`, where `categoryOffset` indexes
    /// `record.assignedCategories` (category 1..<k).
    private var cells: [[[CellState]]]
    public let n: Int
    public let categoryCount: Int

    public init(case record: CaseRecord) {
        n = record.categories[0].values.count
        categoryCount = record.categories.count
        cells = Array(repeating: Array(repeating: Array(repeating: .blank, count: n), count: n), count: categoryCount - 1)
    }

    public func state(owner: Int, category: Int, value: Int) -> CellState {
        cells[category - 1][owner][value]
    }

    /// Every (owner, category) pair with an unambiguous confirmed value.
    public var isComplete: Bool {
        for categoryOffset in cells.indices {
            for owner in 0..<n {
                guard cells[categoryOffset][owner].filter({ $0 == .confirmed }).count == 1 else { return false }
            }
        }
        return true
    }

    /// The single edit needed to undo a `set`, so a view-model can register
    /// it with `UndoManager` without the engine knowing UndoManager exists.
    public struct Edit: Sendable {
        public let owner: Int, category: Int, value: Int
        public let before: CellState
        public let after: CellState
    }

    /// Cycles one cell to its next state. When landing on `.confirmed` and
    /// `autoEliminate` is set (the default — standard logic-grid UX), every
    /// other value in that owner's row and every other owner's claim on
    /// that value are marked `.excluded`, mirroring what a player would
    /// otherwise do by hand. Returns every cell actually changed, in order,
    /// so the caller can build one undo step from them.
    @discardableResult
    public mutating func cycle(owner: Int, category: Int, value: Int, autoEliminate: Bool = true) -> [Edit] {
        let before = cells[category - 1][owner][value]
        let after = before.next
        var edits = [Edit(owner: owner, category: category, value: value, before: before, after: after)]
        cells[category - 1][owner][value] = after
        if autoEliminate, after == .confirmed {
            edits.append(contentsOf: eliminateConflicts(owner: owner, category: category, value: value))
        }
        return edits
    }

    /// Sets one cell to `.confirmed` directly regardless of its current
    /// state — how a hint applies a deduced fact, as opposed to `cycle`'s
    /// tap-driven state machine.
    @discardableResult
    public mutating func confirm(owner: Int, category: Int, value: Int, autoEliminate: Bool = true) -> [Edit] {
        let before = cells[category - 1][owner][value]
        guard before != .confirmed else { return [] }
        cells[category - 1][owner][value] = .confirmed
        var edits = [Edit(owner: owner, category: category, value: value, before: before, after: .confirmed)]
        if autoEliminate {
            edits.append(contentsOf: eliminateConflicts(owner: owner, category: category, value: value))
        }
        return edits
    }

    private mutating func eliminateConflicts(owner: Int, category: Int, value: Int) -> [Edit] {
        var edits: [Edit] = []
        for otherValue in 0..<n where otherValue != value {
            edits.append(contentsOf: forceExclude(owner: owner, category: category, value: otherValue))
        }
        for otherOwner in 0..<n where otherOwner != owner {
            edits.append(contentsOf: forceExclude(owner: otherOwner, category: category, value: value))
        }
        return edits
    }

    private mutating func forceExclude(owner: Int, category: Int, value: Int) -> [Edit] {
        let before = cells[category - 1][owner][value]
        guard before != .excluded else { return [] }
        cells[category - 1][owner][value] = .excluded
        return [Edit(owner: owner, category: category, value: value, before: before, after: .excluded)]
    }

    /// Sets one cell directly, bypassing the tap-cycle and auto-elimination.
    /// This is how a view-model replays an `Edit`'s `before` (undo) or
    /// `after` (redo) state — the engine keeps no history of its own, so
    /// `UndoManager` on the App side owns ordering the replay.
    public mutating func set(owner: Int, category: Int, value: Int, to state: CellState) {
        cells[category - 1][owner][value] = state
    }

    /// The player's confirmed/excluded marks translated into solver
    /// constraints. Candidate marks carry no logical weight — they're
    /// scratch notes, not assertions — so they're intentionally omitted.
    public func asConstraints(solver: CaseSolver) -> [@Sendable (Assignment) -> Bool] {
        var constraints: [@Sendable (Assignment) -> Bool] = []
        for categoryOffset in cells.indices {
            let category = categoryOffset + 1
            for owner in 0..<n {
                for value in 0..<n {
                    switch cells[categoryOffset][owner][value] {
                    case .confirmed:
                        constraints.append { a in a.owner(category: category, value: value) == owner }
                    case .excluded:
                        constraints.append { a in a.owner(category: category, value: value) != owner }
                    case .blank, .candidate:
                        break
                    }
                }
            }
        }
        return constraints
    }
}
