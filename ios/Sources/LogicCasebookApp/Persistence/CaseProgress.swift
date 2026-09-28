import Foundation
import SwiftData
import LogicCasebookEngine
import iOS18Shell

/// One case's saved progress. SwiftData is the "most appropriate native
/// tool" here per spec §5 ("Player progress | SwiftData") — no third-party
/// persistence layer, and it plays directly into `AppShellModelContainer`'s
/// throwing container setup so storage failures surface as a real UI state
/// (`ContentUnavailableView`) instead of a silent crash.
@Model
public final class CaseProgressRecord {
    @Attribute(.unique) public var caseID: String
    /// The grid's cell states, flattened as `[category][owner][value]` in
    /// row-major order — `GameGrid` itself has no public initializer from
    /// raw storage, so progress round-trips through this flat form.
    public var gridCategoryCount: Int
    public var gridN: Int
    public var flatCells: [Int]
    public var secondsSpent: Double
    public var hintsUsed: Int
    public var incorrectChecks: Int
    public var isSolved: Bool
    public var lastPlayedAt: Date

    public init(caseID: String, grid: GameGrid, secondsSpent: Double = 0, hintsUsed: Int = 0, incorrectChecks: Int = 0, isSolved: Bool = false) {
        self.caseID = caseID
        self.gridCategoryCount = grid.categoryCount
        self.gridN = grid.n
        self.flatCells = Self.flatten(grid)
        self.secondsSpent = secondsSpent
        self.hintsUsed = hintsUsed
        self.incorrectChecks = incorrectChecks
        self.isSolved = isSolved
        self.lastPlayedAt = .now
    }

    public func update(grid: GameGrid, secondsSpent: Double, hintsUsed: Int, incorrectChecks: Int, isSolved: Bool) {
        self.flatCells = Self.flatten(grid)
        self.secondsSpent = secondsSpent
        self.hintsUsed = hintsUsed
        self.incorrectChecks = incorrectChecks
        self.isSolved = isSolved
        self.lastPlayedAt = .now
    }

    public func restoreGrid(for record: CaseRecord) -> GameGrid {
        var grid = GameGrid(case: record)
        var i = 0
        for category in 1...(gridCategoryCount - 1) {
            for owner in 0..<gridN {
                for value in 0..<gridN {
                    if let state = CellState(rawValue: flatCells[i]) {
                        grid.set(owner: owner, category: category, value: value, to: state)
                    }
                    i += 1
                }
            }
        }
        return grid
    }

    private static func flatten(_ grid: GameGrid) -> [Int] {
        var flat: [Int] = []
        flat.reserveCapacity(grid.categoryCount * grid.n * grid.n)
        for category in 1...(grid.categoryCount - 1) {
            for owner in 0..<grid.n {
                for value in 0..<grid.n {
                    flat.append(grid.state(owner: owner, category: category, value: value).rawValue)
                }
            }
        }
        return flat
    }
}

public enum CasebookModelContainer {
    public static func make() throws -> ModelContainer {
        try AppShellModelContainer.make(for: [CaseProgressRecord.self])
    }
}
