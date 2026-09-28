import Foundation

/// The three outcomes spec §4.6 requires "Check solution" to distinguish —
/// note neither failure case names the offending cell.
public enum SolutionCheckResult: Sendable, Equatable {
    /// Every owner has one confirmed value per category, and it's the
    /// case's actual unique solution.
    case solved
    /// Not every owner has a confirmed value in every category yet.
    case incomplete
    /// The player's confirmed/excluded marks are unsatisfiable together
    /// with the case's own clues — a contradiction somewhere on the grid.
    case contradiction
}

public enum SolutionChecker {
    public static func check(grid: GameGrid, solver: CaseSolver) -> SolutionCheckResult {
        let constraints = grid.asConstraints(solver: solver)
        let matches = solver.solutions(extraConstraints: constraints)
        if matches.isEmpty { return .contradiction }
        return grid.isComplete ? .solved : .incomplete
    }
}
