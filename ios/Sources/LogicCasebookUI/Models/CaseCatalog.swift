import SwiftUI
import LogicCasebookEngine
import LogicCasebookContent

/// The bundled cases, indexed once for the library, search and "next case".
enum CaseCatalog {
    static let cases: [Case] = BundledContent.bundle().cases

    static let byID: [String: Case] = Dictionary(uniqueKeysWithValues: cases.map { ($0.caseID, $0) })

    static let byDifficulty: [Difficulty: [Case]] = Dictionary(grouping: cases, by: \.difficulty)

    /// The next case in library order that the player can open, wrapping to the start.
    static func next(after gameCase: Case, isUnlocked: (Case) -> Bool) -> Case? {
        guard let index = cases.firstIndex(where: { $0.caseID == gameCase.caseID }) else { return nil }
        let ordered = cases[(index + 1)...] + cases[..<index]
        return ordered.first(where: isUnlocked)
    }
}

/// What the rest of the app can ask the shell to do: pop the current tab back
/// to its list, or open a case's briefing from anywhere (used after a solve).
struct CaseNavigation {
    var popToRoot: () -> Void = {}
    var open: (Case) -> Void = { _ in }
}

private struct CaseNavigationKey: EnvironmentKey {
    static let defaultValue = CaseNavigation()
}

extension EnvironmentValues {
    var caseNavigation: CaseNavigation {
        get { self[CaseNavigationKey.self] }
        set { self[CaseNavigationKey.self] = newValue }
    }
}
