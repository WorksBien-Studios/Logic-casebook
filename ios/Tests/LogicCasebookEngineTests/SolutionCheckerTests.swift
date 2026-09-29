import Testing
@testable import LogicCasebookEngine
import LogicCasebookContent

@Suite("SolutionChecker")
struct SolutionCheckerTests {
    private func firstCase() throws -> Case {
        let bundle = try BundledContent.load()
        return try #require(bundle.cases.first { $0.caseID == "jp.logic.0001" })
    }

    /// The case's own bundled solution, expressed as confirmed marks.
    private func solvedMarks(for gameCase: Case) -> [GridKey: MarkState] {
        var marks: [GridKey: MarkState] = [:]
        let primaryID = gameCase.primaryCategory.id
        for row in gameCase.solution.rows {
            guard let primaryValueID = row[primaryID] else { continue }
            for (categoryID, valueID) in row where categoryID != primaryID {
                marks[GridKey(primaryValueID: primaryValueID, categoryID: categoryID, valueID: valueID)] = .confirmed
            }
        }
        return marks
    }

    @Test("a fully and correctly marked grid is correct")
    func correctGrid() throws {
        let gameCase = try firstCase()
        let marks = solvedMarks(for: gameCase)
        #expect(SolutionChecker.check(gameCase, marks: marks) == .correct)
    }

    @Test("a partially marked grid is incomplete")
    func incompleteGrid() throws {
        let gameCase = try firstCase()
        var marks = solvedMarks(for: gameCase)
        let firstKey = try #require(marks.keys.first)
        marks.removeValue(forKey: firstKey)
        #expect(SolutionChecker.check(gameCase, marks: marks) == .incomplete)
    }

    @Test("a grid confirming the wrong value is a contradiction")
    func contradictingGrid() throws {
        let gameCase = try firstCase()
        var marks = solvedMarks(for: gameCase)
        let objects = gameCase.categories.first { $0.id == "objects" }!
        let person1 = gameCase.primaryCategory.values.first { $0.nameJA == "凛" }!
        // The bundled solution has 凛 confirmed against 木箱 (object-1);
        // additionally confirming a second object for the same person is
        // an internal contradiction before it is even compared to the
        // canonical solution.
        let wrongObject = objects.values.first { $0.id != "object-1" }!
        marks[GridKey(primaryValueID: person1.id, categoryID: "objects", valueID: wrongObject.id)] = .confirmed
        #expect(SolutionChecker.check(gameCase, marks: marks) == .contradiction)
    }
}
