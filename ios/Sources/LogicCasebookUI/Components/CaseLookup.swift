import Foundation
import LogicCasebookEngine

extension Case {
    /// The display name and category index of an entity reference.
    func entity(_ ref: EntityRef) -> (name: String, categoryIndex: Int)? {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == ref.categoryID }),
              let value = categories[categoryIndex].values.first(where: { $0.id == ref.valueID }) else { return nil }
        return (value.nameJA, categoryIndex)
    }

    /// The category index that a quoted name in a clue sentence belongs to.
    func categoryIndex(forValueNamed name: String) -> Int? {
        categories.firstIndex { category in category.values.contains { $0.nameJA == name } }
    }

    /// The four-digit case number shown in lists ("0001").
    var number: String { String(caseID.suffix(4)) }
}
