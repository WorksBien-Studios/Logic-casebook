import Foundation

/// The four cell states from the locked spec (section 4.4): blank → confirmed
/// → excluded → candidate → blank.
public enum MarkState: String, Codable, Sendable, CaseIterable {
    case blank
    case confirmed
    case excluded
    case candidate

    public var next: MarkState {
        switch self {
        case .blank: return .confirmed
        case .confirmed: return .excluded
        case .excluded: return .candidate
        case .candidate: return .blank
        }
    }
}

/// One grid cell: does `valueID` (in `categoryID`) belong to the primary
/// entity `primaryValueID`?
public struct GridKey: Hashable, Codable, Sendable {
    public let primaryValueID: String
    public let categoryID: String
    public let valueID: String

    public init(primaryValueID: String, categoryID: String, valueID: String) {
        self.primaryValueID = primaryValueID
        self.categoryID = categoryID
        self.valueID = valueID
    }
}

public enum CheckResult: Equatable, Sendable {
    /// Every cell resolved and it matches the bundled solution.
    case correct
    /// Some primary entity is still missing a confirmed value in some
    /// category. Per the locked spec (section 4.6), the app must not name
    /// which cells are missing.
    case incomplete
    /// Two confirmed marks conflict with each other, or with the bundled
    /// solution. Per the locked spec, the app must not reveal the answer.
    case contradiction
}

/// Reconstructs the player's implied solution from confirmed (`○`) marks and
/// compares it against the case's bundled `solution`. This is deliberately
/// independent of `Solver` / `CaseContext`: checking a submitted grid never
/// needs to re-enumerate the search space, only to compare confirmed marks.
public enum SolutionChecker {
    public static func check(_ gameCase: Case, marks: [GridKey: MarkState]) -> CheckResult {
        let primaryID = gameCase.primaryCategory.id
        let otherCategories = gameCase.categories.filter { $0.id != primaryID }

        var derived: [String: [String: String]] = [:]
        for primaryValue in gameCase.primaryCategory.values {
            derived[primaryValue.id] = [:]
        }

        for category in otherCategories {
            for primaryValue in gameCase.primaryCategory.values {
                let confirmed = category.values.filter { value in
                    marks[GridKey(primaryValueID: primaryValue.id, categoryID: category.id, valueID: value.id)] == .confirmed
                }
                if confirmed.count > 1 {
                    return .contradiction
                }
                if let value = confirmed.first {
                    derived[primaryValue.id]?[category.id] = value.id
                }
            }
        }

        let isComplete = gameCase.primaryCategory.values.allSatisfy { primaryValue in
            otherCategories.allSatisfy { derived[primaryValue.id]?[$0.id] != nil }
        }
        guard isComplete else { return .incomplete }

        for row in gameCase.solution.rows {
            guard let primaryValueID = row[primaryID] else { continue }
            for category in otherCategories {
                guard let expected = row[category.id],
                      derived[primaryValueID]?[category.id] == expected else {
                    return .contradiction
                }
            }
        }
        return .correct
    }
}
