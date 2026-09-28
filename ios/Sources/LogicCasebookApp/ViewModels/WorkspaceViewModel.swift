import Foundation
import Observation
import LogicCasebookEngine

/// Drives the logic workspace: owns the mutable `GameGrid`, wires cell edits
/// through Apple's native `UndoManager` (Foundation's own command-stack
/// primitive — the "most appropriate native tool" for undo/redo, rather
/// than a hand-rolled stack) and exposes hinting and solution-checking via
/// the engine's `HintEngine`/`SolutionChecker`.
@Observable
@MainActor
public final class WorkspaceViewModel {
    public let record: CaseRecord
    public private(set) var grid: GameGrid
    public let undoManager = UndoManager()

    public private(set) var activeHint: Hint?
    public private(set) var checkResult: SolutionCheckResult?
    public private(set) var hintsUsed = 0
    public private(set) var incorrectChecks = 0
    public private(set) var startedAt = Date.now

    private let solver: CaseSolver

    public init(record: CaseRecord, savedGrid: GameGrid? = nil, hintsUsed: Int = 0, incorrectChecks: Int = 0) {
        self.record = record
        self.solver = CaseSolver(case: record)
        self.grid = savedGrid ?? GameGrid(case: record)
        self.hintsUsed = hintsUsed
        self.incorrectChecks = incorrectChecks
    }

    public var isSolved: Bool { checkResult == .solved }
    public var elapsedSeconds: TimeInterval { Date.now.timeIntervalSince(startedAt) }

    /// Replaces the grid and counters with a previously-saved state —
    /// loading a `CaseProgressRecord` back in. Clears any pending undo
    /// history, since it described edits to the grid this replaces.
    /// `previousSecondsSpent` backdates `startedAt` so `elapsedSeconds` keeps
    /// accumulating across sessions instead of restarting from zero.
    public func restore(grid: GameGrid, hintsUsed: Int, incorrectChecks: Int, previousSecondsSpent: TimeInterval = 0) {
        self.grid = grid
        self.hintsUsed = hintsUsed
        self.incorrectChecks = incorrectChecks
        self.checkResult = nil
        self.startedAt = Date.now.addingTimeInterval(-previousSecondsSpent)
        undoManager.removeAllActions(withTarget: self)
    }

    public func tap(owner: Int, category: Int, value: Int) {
        checkResult = nil
        let edits = grid.cycle(owner: owner, category: category, value: value)
        registerUndo(for: edits)
    }

    /// Registers one undo step that replays `edits`' `before` states, and —
    /// inside that undo closure — registers the matching redo step that
    /// replays their `after` states, and so on. This is the standard
    /// `UndoManager` ping-pong pattern: each invocation re-arms the other
    /// direction so the stack stays walkable both ways indefinitely.
    private func registerUndo(for edits: [GameGrid.Edit]) {
        undoManager.registerUndo(withTarget: self) { viewModel in
            for edit in edits.reversed() {
                viewModel.grid.set(owner: edit.owner, category: edit.category, value: edit.value, to: edit.before)
            }
            viewModel.checkResult = nil
            viewModel.registerRedo(for: edits)
        }
    }

    private func registerRedo(for edits: [GameGrid.Edit]) {
        undoManager.registerUndo(withTarget: self) { viewModel in
            for edit in edits {
                viewModel.grid.set(owner: edit.owner, category: edit.category, value: edit.value, to: edit.after)
            }
            viewModel.checkResult = nil
            viewModel.registerUndo(for: edits)
        }
    }

    public func undo() { undoManager.undo() }
    public func redo() { undoManager.redo() }
    public var canUndo: Bool { undoManager.canUndo }
    public var canRedo: Bool { undoManager.canRedo }

    /// Spec §4.5: identify the clue(s), state the relationship, let the
    /// player apply the mark or return without applying it.
    public func requestHint() {
        activeHint = HintEngine.nextHint(for: grid, case: record, solver: solver)
    }

    public func dismissHint() {
        activeHint = nil
    }

    public func applyActiveHint() {
        guard let hint = activeHint else { return }
        var edits: [GameGrid.Edit] = []
        for confirmation in hint.confirmations {
            edits.append(contentsOf: grid.confirm(owner: confirmation.owner, category: confirmation.category, value: confirmation.value))
        }
        registerUndo(for: edits)
        hintsUsed += 1
        activeHint = nil
        checkResult = nil
    }

    /// Spec §4.6: complete+correct finishes the case; incomplete explains
    /// unresolved cells remain (without naming them); inconsistent reports
    /// a contradiction (without exposing the answer). Never erases work.
    public func checkSolution() {
        let result = SolutionChecker.check(grid: grid, solver: solver)
        checkResult = result
        if result == .contradiction { incorrectChecks += 1 }
    }

    public var isPerfectCompletion: Bool { isSolved && hintsUsed == 0 && incorrectChecks == 0 }
}
