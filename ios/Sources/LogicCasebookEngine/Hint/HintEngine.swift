import Foundation

/// One offerable hint: the authored explanation for the next deduction the
/// player hasn't yet reflected in their grid, plus the concrete cell
/// confirmations applying it means.
public struct Hint: Sendable {
    public let step: DeductionStep
    /// (owner, category, value) triples to mark `.confirmed` if the player
    /// accepts the hint.
    public let confirmations: [(owner: Int, category: Int, value: Int)]

    public var explanationJA: String { step.explanationJA }
    public var referencedClueIDs: [String] { step.clueIDs }
}

/// Hints replay the case's own pre-authored, exhaustively-validated
/// deduction path (`CaseRecord.deductionSteps`) rather than re-deriving
/// inference live: the content pipeline already proved every step follows
/// from known facts and wrote natural Japanese for it
/// (`tools/validate_cases.py`'s deduction-path gate), so a hint can never
/// introduce information the case doesn't contain — the spec's hard
/// requirement (§4.5) is satisfied by construction, not by re-checking a
/// live solve.
public enum HintEngine {
    /// The first deduction step whose facts aren't all already confirmed on
    /// the grid, or `nil` once every step has been applied.
    public static func nextHint(for grid: GameGrid, case record: CaseRecord, solver: CaseSolver) -> Hint? {
        for step in record.deductionSteps {
            let confirmations = step.deducedFacts.compactMap { fact -> (owner: Int, category: Int, value: Int)? in
                confirmation(for: fact, solver: solver)
            }
            let alreadyApplied = confirmations.allSatisfy { grid.state(owner: $0.owner, category: $0.category, value: $0.value) == .confirmed }
            if !alreadyApplied {
                return Hint(step: step, confirmations: confirmations)
            }
        }
        return nil
    }

    /// A deduced fact is always "this primary-category entity has this
    /// value" (`relation == "same"`, one side in the primary category, the
    /// other in an assigned category) — translate it into the concrete grid
    /// cell that asserts it.
    private static func confirmation(for fact: DeducedFact, solver: CaseSolver) -> (owner: Int, category: Int, value: Int)? {
        let left = solver.ref(fact.left)
        let right = solver.ref(fact.right)
        if left.category == 0 { return (owner: left.value, category: right.category, value: right.value) }
        if right.category == 0 { return (owner: right.value, category: left.category, value: left.value) }
        return nil
    }
}
