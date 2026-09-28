import Testing
@testable import LogicCasebookEngine

@Suite("HintEngine")
struct HintEngineTests {
    private func firstCase() throws -> CaseRecord {
        try CaseBundleLoader.loadAll()[0]
    }

    @Test("an empty grid's first hint is the case's first deduction step")
    func firstHintMatchesFirstStep() throws {
        let record = try firstCase()
        let grid = GameGrid(case: record)
        let solver = CaseSolver(case: record)

        let hint = HintEngine.nextHint(for: grid, case: record, solver: solver)
        #expect(hint != nil)
        #expect(hint?.explanationJA == record.deductionSteps.first?.explanationJA)
        #expect(hint?.referencedClueIDs == record.deductionSteps.first?.clueIDs)
    }

    @Test("applying every hint in order reaches a solved grid")
    func applyingEveryHintSolves() throws {
        let record = try firstCase()
        var grid = GameGrid(case: record)
        let solver = CaseSolver(case: record)

        var stepsApplied = 0
        while let hint = HintEngine.nextHint(for: grid, case: record, solver: solver), stepsApplied <= record.deductionSteps.count {
            for confirmation in hint.confirmations {
                grid.set(owner: confirmation.owner, category: confirmation.category, value: confirmation.value, to: .confirmed)
            }
            stepsApplied += 1
        }
        #expect(stepsApplied <= record.deductionSteps.count, "hint loop did not converge")

        #expect(SolutionChecker.check(grid: grid, solver: solver) == .solved)
    }

    @Test("once every step is applied, no further hint is offered")
    func noHintOnceSolved() throws {
        let record = try firstCase()
        var grid = GameGrid(case: record)
        let solver = CaseSolver(case: record)

        while let hint = HintEngine.nextHint(for: grid, case: record, solver: solver) {
            for confirmation in hint.confirmations {
                grid.set(owner: confirmation.owner, category: confirmation.category, value: confirmation.value, to: .confirmed)
            }
        }
        #expect(HintEngine.nextHint(for: grid, case: record, solver: solver) == nil)
    }
}
