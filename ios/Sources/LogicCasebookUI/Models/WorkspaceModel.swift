import Foundation
import Observation
import SwiftData
import LogicCasebookEngine

/// Everything about one play-through of a case: the pair grid, undo/redo,
/// reviewed clues, hint and check counters, and autosave. The view only draws
/// this; the rules live in `LogicCasebookEngine`.
@MainActor
@Observable
final class WorkspaceModel {
    let gameCase: Case

    private(set) var marks: [PairKey: MarkState] = [:]
    private(set) var history = MarkHistory()
    private(set) var checkedClueIDs: Set<String> = []
    private(set) var hintsUsed = 0
    private(set) var validationAttempts = 0
    private(set) var isSolved = false

    var selectedPair: CategoryPair
    var isHintPresented = false
    var banner: CheckResult?
    var isSolvedPresented = false

    private var priorSeconds = 0
    private var sessionStart = Date()
    private var wasCompleted = false

    init(gameCase: Case) {
        self.gameCase = gameCase
        self.selectedPair = gameCase.categoryPairs.first ?? CategoryPair(rowIndex: 0, columnIndex: 1)
    }

    var elapsedSeconds: Int { priorSeconds + Int(Date().timeIntervalSince(sessionStart)) }
    var isPerfect: Bool { hintsUsed == 0 && validationAttempts <= 1 }

    // MARK: Editing

    /// Tap: blank → ○ → × → △ → blank.
    func cycle(_ key: PairKey) {
        set(key, (marks[key] ?? .blank).next)
    }

    func set(_ key: PairKey, _ mark: MarkState) {
        guard marks[key] != mark, !(marks[key] == nil && mark == .blank) else { return }
        history.record(marks)
        if mark == .blank { marks.removeValue(forKey: key) } else { marks[key] = mark }
        banner = nil
    }

    func undo() {
        if let previous = history.undo(from: marks) { marks = previous; banner = nil }
    }

    func redo() {
        if let next = history.redo(from: marks) { marks = next; banner = nil }
    }

    func toggleClue(_ id: String) {
        if checkedClueIDs.contains(id) { checkedClueIDs.remove(id) } else { checkedClueIDs.insert(id) }
    }

    // MARK: Hints and checking

    func requestHint() {
        banner = nil
        isHintPresented = true
    }

    /// The next deduction the player has not put on the grid yet, or `nil`
    /// when every step is already there.
    var currentHint: DeductionStep? { HintPlanner.nextStep(in: gameCase, marks: marks) }

    func applyHint(_ step: DeductionStep) {
        history.record(marks)
        marks = HintPlanner.applying(step, to: marks, in: gameCase)
        hintsUsed += 1
        isHintPresented = false
    }

    /// Returns the result and, when correct, flips `isSolved`. Never changes the grid.
    @discardableResult
    func check() -> CheckResult {
        validationAttempts += 1
        let result = PairSolutionChecker.check(gameCase, marks: marks)
        if result == .correct {
            banner = nil
            isSolved = true
            isSolvedPresented = true
        } else {
            banner = result
        }
        return result
    }

    // MARK: Persistence

    func load(from context: ModelContext) {
        let progress = ProgressStore.progress(for: gameCase.caseID, in: context)
        wasCompleted = progress.status == .completed
        sessionStart = Date()
        if wasCompleted {
            // A solved case starts clean when opened again; its solved status stays.
            priorSeconds = 0
            return
        }
        marks = progress.marks
        checkedClueIDs = progress.checkedClueIDs
        hintsUsed = progress.hintsUsed
        validationAttempts = progress.validationAttempts
        priorSeconds = progress.timeSpentSeconds
        if progress.status == .notStarted { progress.status = .inProgress }
        progress.lastPlayedAt = .now
        try? context.save()
    }

    func save(to context: ModelContext) {
        let progress = ProgressStore.progress(for: gameCase.caseID, in: context)
        progress.lastPlayedAt = .now
        if !wasCompleted {
            progress.marks = marks
            progress.checkedClueIDs = checkedClueIDs
            progress.hintsUsed = hintsUsed
            progress.validationAttempts = validationAttempts
            progress.timeSpentSeconds = elapsedSeconds
            if progress.status == .notStarted { progress.status = .inProgress }
        }
        try? context.save()
    }

    /// Records a solve. A case that was already perfect stays perfect.
    func markCompleted(in context: ModelContext) {
        let progress = ProgressStore.progress(for: gameCase.caseID, in: context)
        progress.isPerfect = (wasCompleted && progress.isPerfect) || isPerfect
        progress.status = .completed
        progress.hintsUsed = hintsUsed
        progress.validationAttempts = validationAttempts
        progress.timeSpentSeconds = elapsedSeconds
        progress.lastPlayedAt = .now
        try? context.save()
    }
}
