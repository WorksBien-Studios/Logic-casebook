import Testing
@testable import LogicCasebookEngine

@Suite("CaseSolver")
struct CaseSolverTests {
    /// A representative sample rather than all 1,000 — the content
    /// pipeline's own `tools/validate_cases.py` already exhaustively checks
    /// every case at build time; these tests exist to prove the on-device
    /// Swift solver agrees with that Python validator's semantics, not to
    /// duplicate its full sweep.
    private func sampleCases() throws -> [CaseRecord] {
        let all = try CaseBundleLoader.loadAll()
        return stride(from: 0, to: all.count, by: 47).map { all[$0] }
    }

    @Test("every sampled case has exactly one solution, matching its stored solution")
    func exactlyOneSolutionMatchingStored() throws {
        for record in try sampleCases() {
            let solver = CaseSolver(case: record)
            let solutions = solver.solutions()
            #expect(solutions.count == 1, "case \(record.caseID) should have exactly one solution")
            guard let found = solutions.first else { continue }

            let primaryID = record.primaryCategory.id
            for row in record.solution.rows {
                guard let primaryValueID = row.assignments[primaryID] else {
                    Issue.record("case \(record.caseID): solution row missing primary category")
                    continue
                }
                let owner = solver.ref(EntityRef(categoryID: primaryID, valueID: primaryValueID)).value
                for category in record.assignedCategories {
                    guard let expectedValueID = row.assignments[category.id] else { continue }
                    let expectedValue = solver.ref(EntityRef(categoryID: category.id, valueID: expectedValueID)).value
                    let categoryIndex = solver.categoryIndex[category.id]!
                    #expect(
                        found.values[categoryIndex - 1][owner] == expectedValue,
                        "case \(record.caseID): solver disagrees with stored solution"
                    )
                }
            }
        }
    }

    @Test("confirming the real solution's cells checks as solved")
    func solutionSatisfiesItself() throws {
        for record in try sampleCases() {
            var grid = GameGrid(case: record)
            let solver = CaseSolver(case: record)
            let primaryID = record.primaryCategory.id
            for row in record.solution.rows {
                guard let primaryValueID = row.assignments[primaryID] else { continue }
                let owner = solver.ref(EntityRef(categoryID: primaryID, valueID: primaryValueID)).value
                for category in record.assignedCategories {
                    guard let valueID = row.assignments[category.id] else { continue }
                    let value = solver.ref(EntityRef(categoryID: category.id, valueID: valueID)).value
                    let categoryIndex = solver.categoryIndex[category.id]!
                    grid.set(owner: owner, category: categoryIndex, value: value, to: .confirmed)
                }
            }
            #expect(grid.isComplete, "case \(record.caseID): full solution should read as a complete grid")
            #expect(
                SolutionChecker.check(grid: grid, solver: solver) == .solved,
                "case \(record.caseID): confirming the real solution should check as solved"
            )
        }
    }

    @Test("confirming a cell the real solution excludes is a contradiction")
    func wrongConfirmationIsContradiction() throws {
        for record in try sampleCases() {
            var grid = GameGrid(case: record)
            let solver = CaseSolver(case: record)
            let primaryID = record.primaryCategory.id
            let category = record.assignedCategories[0]
            let categoryIndex = solver.categoryIndex[category.id]!

            guard let firstRow = record.solution.rows.first,
                  let primaryValueID = firstRow.assignments[primaryID],
                  let correctValueID = firstRow.assignments[category.id] else {
                Issue.record("case \(record.caseID): missing expected solution fields")
                continue
            }
            let owner = solver.ref(EntityRef(categoryID: primaryID, valueID: primaryValueID)).value
            let correctValue = solver.ref(EntityRef(categoryID: category.id, valueID: correctValueID)).value
            let n = record.categories[0].values.count
            let wrongValue = (correctValue + 1) % n

            grid.set(owner: owner, category: categoryIndex, value: wrongValue, to: .confirmed)
            #expect(
                SolutionChecker.check(grid: grid, solver: solver) == .contradiction,
                "case \(record.caseID): confirming a value the real solution excludes should contradict"
            )
        }
    }

    @Test("an empty grid is always incomplete, never a contradiction")
    func emptyGridIsIncomplete() throws {
        for record in try sampleCases() {
            let grid = GameGrid(case: record)
            let solver = CaseSolver(case: record)
            #expect(
                SolutionChecker.check(grid: grid, solver: solver) == .incomplete,
                "case \(record.caseID): a blank grid should never read as solved or contradictory"
            )
        }
    }
}
