import Foundation

/// A reference to one value inside one category, e.g. `["people", "person-1"]`
/// in the JSON. Decodes from and encodes to a two-element array to match the
/// bundled content exactly (schema/case-bundle.schema.json `#/$defs/reference`).
public struct EntityRef: Codable, Hashable, Sendable {
    public let categoryID: String
    public let valueID: String

    public init(categoryID: String, valueID: String) {
        self.categoryID = categoryID
        self.valueID = valueID
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        categoryID = try container.decode(String.self)
        valueID = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(categoryID)
        try container.encode(valueID)
    }
}

public struct CategoryValue: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let nameJA: String
}

// Named `CaseCategory`, not `Category` -- the bare name collides with
// `ObjectiveC.Category`, which is implicitly visible on Apple platforms.
public struct CaseCategory: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let nameJA: String
    public let ordered: Bool
    public let values: [CategoryValue]
}

public enum ClueType: String, Codable, Sendable {
    case same
    case different
    case either
    case pairSet
    case before
    case immediatelyBefore
    case offsetBefore
}

/// The arguments of a clue. Shape depends on `ClueType`, mirroring
/// `tools/build_cases.py`'s `evaluate()` / `convert_args()` exactly.
public enum ClueArgs: Sendable {
    case sameOrDifferent(left: EntityRef, right: EntityRef)
    case either(subject: EntityRef, optionA: EntityRef, optionB: EntityRef)
    case pairSet(left: [EntityRef], right: [EntityRef])
    case ordering(left: EntityRef, right: EntityRef, orderedCategory: String, offset: Int?)
}

public struct Clue: Identifiable, Hashable, Sendable {
    public let id: String
    public let type: ClueType
    public let args: ClueArgs
    public let textJA: String

    public static func == (lhs: Clue, rhs: Clue) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Clue: Codable {
    private enum CodingKeys: String, CodingKey { case id, type, args, textJA }
    private enum ArgKeys: String, CodingKey {
        case left, right, subject, optionA, optionB, orderedCategory, offset
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(ClueType.self, forKey: .type)
        textJA = try container.decode(String.self, forKey: .textJA)

        let argsContainer = try container.nestedContainer(keyedBy: ArgKeys.self, forKey: .args)
        switch type {
        case .same, .different:
            args = .sameOrDifferent(
                left: try argsContainer.decode(EntityRef.self, forKey: .left),
                right: try argsContainer.decode(EntityRef.self, forKey: .right)
            )
        case .either:
            args = .either(
                subject: try argsContainer.decode(EntityRef.self, forKey: .subject),
                optionA: try argsContainer.decode(EntityRef.self, forKey: .optionA),
                optionB: try argsContainer.decode(EntityRef.self, forKey: .optionB)
            )
        case .pairSet:
            args = .pairSet(
                left: try argsContainer.decode([EntityRef].self, forKey: .left),
                right: try argsContainer.decode([EntityRef].self, forKey: .right)
            )
        case .before, .immediatelyBefore, .offsetBefore:
            args = .ordering(
                left: try argsContainer.decode(EntityRef.self, forKey: .left),
                right: try argsContainer.decode(EntityRef.self, forKey: .right),
                orderedCategory: try argsContainer.decode(String.self, forKey: .orderedCategory),
                offset: try argsContainer.decodeIfPresent(Int.self, forKey: .offset)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(textJA, forKey: .textJA)

        var argsContainer = container.nestedContainer(keyedBy: ArgKeys.self, forKey: .args)
        switch args {
        case let .sameOrDifferent(left, right):
            try argsContainer.encode(left, forKey: .left)
            try argsContainer.encode(right, forKey: .right)
        case let .either(subject, optionA, optionB):
            try argsContainer.encode(subject, forKey: .subject)
            try argsContainer.encode(optionA, forKey: .optionA)
            try argsContainer.encode(optionB, forKey: .optionB)
        case let .pairSet(left, right):
            try argsContainer.encode(left, forKey: .left)
            try argsContainer.encode(right, forKey: .right)
        case let .ordering(left, right, orderedCategory, offset):
            try argsContainer.encode(left, forKey: .left)
            try argsContainer.encode(right, forKey: .right)
            try argsContainer.encode(orderedCategory, forKey: .orderedCategory)
            try argsContainer.encodeIfPresent(offset, forKey: .offset)
        }
    }
}

public struct DeducedFact: Codable, Hashable, Sendable {
    public let relation: String
    public let left: EntityRef
    public let right: EntityRef
    public let textJA: String
}

public struct DeductionStep: Codable, Identifiable, Hashable, Sendable {
    public let step: Int
    public let clueIDs: [String]
    public let candidateCountBefore: Int
    public let candidateCountAfter: Int
    public let deducedFacts: [DeducedFact]
    public let explanationJA: String

    public var id: Int { step }
}

public struct ProofMetrics: Codable, Hashable, Sendable {
    public let searchSpace: Int
    public let solutionCount: Int
    public let clueCount: Int
    public let deductionStepCount: Int
    public let requiresGuess: Bool
}

public struct CaseSolution: Codable, Hashable, Sendable {
    /// One dictionary per primary-category entity, keyed by category id,
    /// valued by that entity's value id in that category.
    public let rows: [[String: String]]
}

public enum Difficulty: String, Codable, CaseIterable, Sendable {
    case beginner
    case standard
    case advanced
    case expert

    public var labelJA: String {
        switch self {
        case .beginner: return "初級"
        case .standard: return "標準"
        case .advanced: return "上級"
        case .expert: return "超級"
        }
    }
}

public enum EditorialStatus: String, Codable, Sendable {
    case pendingNativeReview = "pending_native_review"
    case approved
    case rejected
}

public struct Case: Codable, Identifiable, Hashable, Sendable {
    public let schemaVersion: Int
    public let caseID: String
    public let contentVersion: Int
    public let titleJA: String
    public let scenarioJA: String
    public let questionJA: String
    public let difficulty: Difficulty
    public let difficultyScore: Double
    public let estimatedMinutes: Int
    public let isFree: Bool
    public let categories: [CaseCategory]
    public let clues: [Clue]
    public let solution: CaseSolution
    public let deductionSteps: [DeductionStep]
    public let proofMetrics: ProofMetrics
    public let structuralSignature: String
    public let editorialStatus: EditorialStatus
    public let checksum: String

    public var id: String { caseID }

    /// The sole ordered category (always the last one — see
    /// schema/case-bundle.schema.json and ContentValidator).
    public var orderedCategory: CaseCategory? { categories.last(where: { $0.ordered }) }

    public var primaryCategory: CaseCategory { categories[0] }
}

public struct CaseBundle: Codable, Sendable {
    public let bundleSchemaVersion: Int
    public let bundleID: String
    public let contentVersion: Int
    public let generatedAt: String
    public let generatorSeed: Int
    public let releaseStatus: String
    public let caseCount: Int
    public let cases: [Case]
}
