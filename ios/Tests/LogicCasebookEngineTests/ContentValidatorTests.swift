import Testing
@testable import LogicCasebookEngine
import LogicCasebookContent

@Suite("Content validator (independent re-proof of every bundled case)")
struct ContentValidatorTests {
    @Test("every bundled case has exactly one solution and a consistent deduction path")
    func allCasesValidate() throws {
        let bundle = try BundledContent.load()
        var failures: [ContentValidator.Failure] = []
        for gameCase in bundle.cases {
            failures.append(contentsOf: ContentValidator.validate(gameCase))
        }
        #expect(failures.isEmpty, "\(failures.count) failure(s), first: \(failures.first.map { "\($0.caseID): \($0.reason)" } ?? "none")")
    }

    @Test("case jp.logic.0001 solves to its bundled solution")
    func firstCaseSolves() throws {
        let bundle = try BundledContent.load()
        let gameCase = try #require(bundle.cases.first { $0.caseID == "jp.logic.0001" })
        let context = CaseContext(case: gameCase)
        let survivors = Solver.solve(gameCase.clues, context: context)
        #expect(survivors.count == 1)
        #expect(survivors.first == context.expectedAssignment(gameCase.solution))
    }
}
