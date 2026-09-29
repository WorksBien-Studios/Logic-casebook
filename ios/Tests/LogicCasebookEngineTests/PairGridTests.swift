import Testing
@testable import LogicCasebookEngine
import LogicCasebookContent

@Suite("Pair grid")
struct PairGridTests {
    private func solvedMarks(for gameCase: Case) -> [PairKey: MarkState] {
        var marks: [PairKey: MarkState] = [:]
        for row in gameCase.solution.rows {
            for pair in gameCase.categoryPairs {
                let rowCategory = gameCase.categories[pair.rowIndex]
                let columnCategory = gameCase.categories[pair.columnIndex]
                guard let rowValueID = row[rowCategory.id], let columnValueID = row[columnCategory.id] else { continue }
                marks[PairKey(
                    rowCategoryID: rowCategory.id,
                    rowValueID: rowValueID,
                    columnCategoryID: columnCategory.id,
                    columnValueID: columnValueID
                )] = .confirmed
            }
        }
        return marks
    }

    @Test("category pairs cover every pair once, row before column")
    func pairCount() throws {
        let bundle = try BundledContent.load()
        for gameCase in bundle.cases {
            let k = gameCase.categories.count
            let pairs = gameCase.categoryPairs
            #expect(pairs.count == k * (k - 1) / 2)
            #expect(pairs.allSatisfy { $0.rowIndex < $0.columnIndex })
            #expect(Set(pairs.map(\.id)).count == pairs.count)
        }
    }

    @Test("pairKey is order-independent and rejects same-category refs")
    func pairKeyNormalizes() throws {
        let bundle = try BundledContent.load()
        let gameCase = try #require(bundle.cases.first)
        let first = EntityRef(categoryID: gameCase.categories[0].id, valueID: gameCase.categories[0].values[0].id)
        let second = EntityRef(categoryID: gameCase.categories[2].id, valueID: gameCase.categories[2].values[1].id)
        let forward = try #require(gameCase.pairKey(first, second))
        let backward = try #require(gameCase.pairKey(second, first))
        #expect(forward == backward)
        #expect(forward.rowCategoryID == first.categoryID)
        let sibling = EntityRef(categoryID: first.categoryID, valueID: gameCase.categories[0].values[1].id)
        #expect(gameCase.pairKey(first, sibling) == nil)
    }

    @Test("the bundled solution, marked on every pair, is correct for all 1,000 cases")
    func solutionIsCorrect() throws {
        let bundle = try BundledContent.load()
        for gameCase in bundle.cases {
            #expect(PairSolutionChecker.check(gameCase, marks: solvedMarks(for: gameCase)) == .correct, "\(gameCase.caseID)")
        }
    }

    @Test("an empty grid is incomplete and a missing confirmation stays incomplete")
    func incomplete() throws {
        let bundle = try BundledContent.load()
        let gameCase = try #require(bundle.cases.first)
        #expect(PairSolutionChecker.check(gameCase, marks: [:]) == .incomplete)
        var marks = solvedMarks(for: gameCase)
        marks.removeValue(forKey: try #require(marks.keys.first))
        #expect(PairSolutionChecker.check(gameCase, marks: marks) == .incomplete)
    }

    @Test("a wrong ○ or a × on a true pairing is a contradiction")
    func contradictions() throws {
        let bundle = try BundledContent.load()
        let gameCase = try #require(bundle.cases.first)
        let solved = solvedMarks(for: gameCase)
        let trueKey = try #require(solved.keys.first)

        var excluded = solved
        excluded[trueKey] = .excluded
        #expect(PairSolutionChecker.check(gameCase, marks: excluded) == .contradiction)

        let pair = try #require(gameCase.categoryPairs.first)
        let rowCategory = gameCase.categories[pair.rowIndex]
        let columnCategory = gameCase.categories[pair.columnIndex]
        let row = rowCategory.values[0]
        let wrongColumn = try #require(columnCategory.values.first { value in
            gameCase.pairKey(pair, row: row, column: value) != trueKey
                && solved[gameCase.pairKey(pair, row: row, column: value)] == nil
        })
        var wrong = [PairKey: MarkState]()
        wrong[gameCase.pairKey(pair, row: row, column: wrongColumn)] = .confirmed
        #expect(PairSolutionChecker.check(gameCase, marks: wrong) == .contradiction)
    }

    @Test("candidate marks never make a grid wrong or complete")
    func candidatesAreNeutral() throws {
        let bundle = try BundledContent.load()
        let gameCase = try #require(bundle.cases.first)
        var marks = solvedMarks(for: gameCase)
        let key = try #require(marks.keys.first)
        marks[key] = .candidate
        #expect(PairSolutionChecker.check(gameCase, marks: marks) == .incomplete)
    }

    @Test("replaying every hint step never produces a contradiction and ends with no next hint")
    func hintsAreSound() throws {
        let bundle = try BundledContent.load()
        for gameCase in bundle.cases {
            var marks: [PairKey: MarkState] = [:]
            var applied = 0
            while let step = HintPlanner.nextStep(in: gameCase, marks: marks) {
                marks = HintPlanner.applying(step, to: marks, in: gameCase)
                applied += 1
                #expect(PairSolutionChecker.check(gameCase, marks: marks) != .contradiction, "\(gameCase.caseID) step \(step.step)")
                if applied > gameCase.deductionSteps.count { break }
            }
            #expect(applied <= gameCase.deductionSteps.count, "\(gameCase.caseID) hint loop did not terminate")
            #expect(HintPlanner.nextStep(in: gameCase, marks: marks) == nil)
        }
    }

    @Test("undo and redo restore snapshots and redo clears on a new change")
    func history() {
        let a: [PairKey: MarkState] = [:]
        let key = PairKey(rowCategoryID: "p", rowValueID: "1", columnCategoryID: "o", columnValueID: "1")
        let b: [PairKey: MarkState] = [key: .confirmed]
        var history = MarkHistory()
        #expect(!history.canUndo)
        history.record(a)
        #expect(history.canUndo && !history.canRedo)
        #expect(history.undo(from: b) == a)
        #expect(history.canRedo)
        #expect(history.redo(from: a) == b)
        _ = history.undo(from: b)
        history.record(a)
        #expect(!history.canRedo)
    }
}
