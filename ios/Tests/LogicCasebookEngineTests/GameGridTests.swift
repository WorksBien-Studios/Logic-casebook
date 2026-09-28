import Testing
@testable import LogicCasebookEngine

@Suite("GameGrid")
struct GameGridTests {
    private func firstCase() throws -> CaseRecord {
        try CaseBundleLoader.loadAll()[0]
    }

    @Test("a cell cycles blank -> confirmed -> excluded -> candidate -> blank")
    func cycleOrder() throws {
        let record = try firstCase()
        var grid = GameGrid(case: record)
        #expect(grid.state(owner: 0, category: 1, value: 0) == .blank)

        grid.cycle(owner: 0, category: 1, value: 0, autoEliminate: false)
        #expect(grid.state(owner: 0, category: 1, value: 0) == .confirmed)

        grid.cycle(owner: 0, category: 1, value: 0, autoEliminate: false)
        #expect(grid.state(owner: 0, category: 1, value: 0) == .excluded)

        grid.cycle(owner: 0, category: 1, value: 0, autoEliminate: false)
        #expect(grid.state(owner: 0, category: 1, value: 0) == .candidate)

        grid.cycle(owner: 0, category: 1, value: 0, autoEliminate: false)
        #expect(grid.state(owner: 0, category: 1, value: 0) == .blank)
    }

    @Test("confirming a cell auto-excludes the rest of its row and column")
    func autoElimination() throws {
        let record = try firstCase()
        var grid = GameGrid(case: record)
        let n = record.categories[0].values.count
        guard n > 1 else { return }

        grid.cycle(owner: 0, category: 1, value: 0, autoEliminate: true)

        for otherValue in 1..<n {
            #expect(grid.state(owner: 0, category: 1, value: otherValue) == .excluded)
        }
        for otherOwner in 1..<n {
            #expect(grid.state(owner: otherOwner, category: 1, value: 0) == .excluded)
        }
        #expect(grid.state(owner: 0, category: 1, value: 0) == .confirmed)
    }

    @Test("replaying an edit's before/after states via set() reproduces undo and redo")
    func undoRedoViaEditReplay() throws {
        let record = try firstCase()
        var grid = GameGrid(case: record)

        let edits = grid.cycle(owner: 0, category: 1, value: 0, autoEliminate: false)
        #expect(grid.state(owner: 0, category: 1, value: 0) == .confirmed)

        // Undo: replay every edit's `before` state.
        for edit in edits.reversed() {
            grid.set(owner: edit.owner, category: edit.category, value: edit.value, to: edit.before)
        }
        #expect(grid.state(owner: 0, category: 1, value: 0) == .blank)

        // Redo: replay every edit's `after` state.
        for edit in edits {
            grid.set(owner: edit.owner, category: edit.category, value: edit.value, to: edit.after)
        }
        #expect(grid.state(owner: 0, category: 1, value: 0) == .confirmed)
    }

    @Test("candidate marks are not solver constraints")
    func candidateMarksAreNotConstraints() throws {
        let record = try firstCase()
        var grid = GameGrid(case: record)
        let solver = CaseSolver(case: record)

        // blank -> confirmed -> excluded -> candidate
        grid.cycle(owner: 0, category: 1, value: 0, autoEliminate: false)
        grid.cycle(owner: 0, category: 1, value: 0, autoEliminate: false)
        grid.cycle(owner: 0, category: 1, value: 0, autoEliminate: false)
        #expect(grid.state(owner: 0, category: 1, value: 0) == .candidate)

        // A candidate-only grid should behave exactly like an empty one:
        // still incomplete, never a contradiction.
        #expect(SolutionChecker.check(grid: grid, solver: solver) == .incomplete)
    }
}
