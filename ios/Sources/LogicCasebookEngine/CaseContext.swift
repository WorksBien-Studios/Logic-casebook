import Foundation

/// Precomputed lookups for one case's category/value structure, plus the
/// exhaustive assignment space used to check solution uniqueness. Mirrors
/// `numeric_context()` in `tools/validate_cases.py`.
public struct CaseContext: Sendable {
    public let categories: [Category]
    /// Number of entities in the primary category (people).
    public let n: Int
    /// Number of categories.
    public let k: Int
    let catIndex: [String: Int]
    let valueIndex: [String: [String: Int]]
    /// Every candidate assignment: `k - 1` permutations of `0..<n`, one per
    /// non-primary category, giving the primary-entity position holding
    /// each value.
    public let assignments: [[[Int]]]

    public init(case c: Case) {
        categories = c.categories
        n = categories[0].values.count
        k = categories.count

        var ci: [String: Int] = [:]
        var vi: [String: [String: Int]] = [:]
        for (index, category) in categories.enumerated() {
            ci[category.id] = index
            var positions: [String: Int] = [:]
            for (position, value) in category.values.enumerated() {
                positions[value.id] = position
            }
            vi[category.id] = positions
        }
        catIndex = ci
        valueIndex = vi
        assignments = Solver.allAssignments(n: n, k: k)
    }

    /// The primary-entity position that holds `value` in `category`.
    func owner(_ assignment: [[Int]], category: Int, value: Int) -> Int {
        category == 0 ? value : assignment[category - 1].firstIndex(of: value)!
    }

    func orderedValue(_ assignment: [[Int]], entity: (category: Int, value: Int), orderedCategory: Int) -> Int {
        assignment[orderedCategory - 1][owner(assignment, category: entity.category, value: entity.value)]
    }

    /// Converts a JSON `EntityRef` (category id, value id) into the numeric
    /// (category index, value position) pair the solver works with.
    public func numeric(_ ref: EntityRef) -> (category: Int, value: Int) {
        (catIndex[ref.categoryID]!, valueIndex[ref.categoryID]![ref.valueID]!)
    }

    /// Rebuilds the assignment implied by a case's stored `solution.rows`,
    /// for comparing against the solver's own output. Mirrors
    /// `expected_assignment()` in `tools/validate_cases.py`.
    public func expectedAssignment(_ solution: CaseSolution) -> [[Int]] {
        let primaryID = categories[0].id
        var rowsByPosition: [Int: [String: String]] = [:]
        for row in solution.rows {
            guard let primaryValueID = row[primaryID],
                  let position = valueIndex[primaryID]?[primaryValueID] else { continue }
            rowsByPosition[position] = row
        }
        var result: [[Int]] = []
        for categoryIndex in 1..<k {
            let categoryID = categories[categoryIndex].id
            var column = [Int](repeating: 0, count: n)
            for position in 0..<n {
                guard let row = rowsByPosition[position],
                      let valueID = row[categoryID],
                      let value = valueIndex[categoryID]?[valueID] else { continue }
                column[position] = value
            }
            result.append(column)
        }
        return result
    }
}
