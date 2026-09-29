import Foundation

/// Re-proves, independently of the Python content pipeline, that a bundled
/// case still has exactly one solution and that its precomputed deduction
/// path is internally consistent. This is the Swift-side counterpart to
/// `tools/validate_cases.py`'s `validate_case()` — it does not recompute
/// checksums or structural signatures, since those are pipeline concerns
/// already enforced before content ships; it proves the app's own solver and
/// the bundled solve path agree.
public enum ContentValidator {
    public struct Failure: Sendable {
        public let caseID: String
        public let reason: String
    }

    public static func validate(_ gameCase: Case) -> [Failure] {
        var failures: [Failure] = []
        func fail(_ reason: String) {
            failures.append(Failure(caseID: gameCase.caseID, reason: reason))
        }

        let orderedCategories = gameCase.categories.filter(\.ordered)
        if orderedCategories.count != 1 || gameCase.categories.last?.ordered != true {
            fail("expected exactly one ordered category, as the last category")
        }

        let context = CaseContext(case: gameCase)
        let survivors = Solver.solve(gameCase.clues, context: context)
        guard survivors.count == 1 else {
            fail("solver found \(survivors.count) solutions, expected 1")
            return failures
        }
        let expected = context.expectedAssignment(gameCase.solution)
        if survivors[0] != expected {
            fail("bundled solution does not match the solver's unique solution")
        }

        var current = context.assignments
        var applied = Set<String>()
        let cluesByID = Dictionary(uniqueKeysWithValues: gameCase.clues.map { ($0.id, $0) })

        for step in gameCase.deductionSteps {
            if step.candidateCountBefore != current.count {
                fail("step \(step.step): candidateCountBefore \(step.candidateCountBefore) != actual \(current.count)")
            }
            for clueID in step.clueIDs {
                guard let clue = cluesByID[clueID] else {
                    fail("step \(step.step): unknown clue \(clueID)")
                    continue
                }
                if applied.contains(clueID) {
                    fail("step \(step.step): clue \(clueID) reused in deduction path")
                }
                applied.insert(clueID)
                current = current.filter { Solver.evaluate(clue, assignment: $0, context: context) }
            }
            if step.candidateCountAfter != current.count {
                fail("step \(step.step): candidateCountAfter \(step.candidateCountAfter) != actual \(current.count)")
            }
            for fact in step.deducedFacts {
                let left = context.numeric(fact.left)
                let right = context.numeric(fact.right)
                let consistent = !current.isEmpty && current.allSatisfy {
                    context.owner($0, category: left.category, value: left.value)
                        == context.owner($0, category: right.category, value: right.value)
                }
                if !consistent {
                    fail("step \(step.step): deduced fact does not hold across all surviving candidates")
                }
            }
        }
        if current.count != 1 {
            fail("deduction path leaves \(current.count) candidates, expected exactly 1")
        }
        if applied != Set(gameCase.clues.map(\.id)) {
            fail("deduction path does not cite every clue")
        }

        if gameCase.proofMetrics.solutionCount != survivors.count {
            fail("proofMetrics.solutionCount \(gameCase.proofMetrics.solutionCount) != actual \(survivors.count)")
        }
        if gameCase.proofMetrics.requiresGuess {
            fail("proofMetrics.requiresGuess must be false")
        }

        return failures
    }
}
