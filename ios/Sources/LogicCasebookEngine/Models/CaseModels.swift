import Foundation

/// A reference to one value within one category, e.g. `["people", "person-2"]`
/// in the JSON content. This is the atomic unit every clue and deduced fact
/// points at.
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

public struct CategoryValue: Codable, Hashable, Sendable {
    public let id: String
    public let nameJA: String
}

public struct CaseCategory: Codable, Hashable, Sendable {
    public let id: String
    public let nameJA: String
    public let ordered: Bool
    public let values: [CategoryValue]
}

public enum Difficulty: String, Codable, Hashable, Sendable, CaseIterable {
    case beginner, standard, advanced, expert

    public var labelJA: String {
        switch self {
        case .beginner: "初級"
        case .standard: "中級"
        case .advanced: "上級"
        case .expert: "エキスパート"
        }
    }
}

/// One of the seven formal clue relations the content pipeline authors
/// against (`tools/validate_cases.py`'s `evaluate`). Kept as an enum with
/// associated values rather than a generic `[String: Any]` bag so the
/// solver can switch over it exhaustively and the compiler catches a
/// missing case if a new clue type is ever introduced.
public enum ClueLogic: Hashable, Sendable {
    case same(left: EntityRef, right: EntityRef)
    case different(left: EntityRef, right: EntityRef)
    case either(subject: EntityRef, optionA: EntityRef, optionB: EntityRef)
    case pairSet(left: [EntityRef], right: [EntityRef])
    case before(left: EntityRef, right: EntityRef, orderedCategory: String)
    case immediatelyBefore(left: EntityRef, right: EntityRef, orderedCategory: String)
    case offsetBefore(left: EntityRef, right: EntityRef, orderedCategory: String, offset: Int)
}

public struct Clue: Codable, Hashable, Sendable {
    public let id: String
    public let logic: ClueLogic
    public let textJA: String

    private enum CodingKeys: String, CodingKey {
        case id, type, args, textJA
    }

    private struct Args: Codable {
        let left: [EntityRef]?
        let right: [EntityRef]?
        let subject: EntityRef?
        let optionA: EntityRef?
        let optionB: EntityRef?
        let orderedCategory: String?
        let offset: Int?

        // `left`/`right` are either a single [categoryID, valueID] pair or an
        // array of such pairs (pairSet). Decode whichever shape is present.
        enum ArgKeys: String, CodingKey {
            case left, right, subject, optionA, optionB, orderedCategory, offset
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: ArgKeys.self)
            subject = try c.decodeIfPresent(EntityRef.self, forKey: .subject)
            optionA = try c.decodeIfPresent(EntityRef.self, forKey: .optionA)
            optionB = try c.decodeIfPresent(EntityRef.self, forKey: .optionB)
            orderedCategory = try c.decodeIfPresent(String.self, forKey: .orderedCategory)
            offset = try c.decodeIfPresent(Int.self, forKey: .offset)
            left = try Args.decodeRefOrRefList(c, key: .left)
            right = try Args.decodeRefOrRefList(c, key: .right)
        }

        // A JSON array of two strings (`["people", "person-1"]`) is a single
        // ref; an array of such arrays (`pairSet`'s left/right) is a ref
        // list. Both shapes decode as top-level JSON arrays, so try the list
        // shape first — a single ref fails it because its elements are
        // strings, not two-element arrays — and fall back to a single ref.
        private static func decodeRefOrRefList(_ c: KeyedDecodingContainer<ArgKeys>, key: ArgKeys) throws -> [EntityRef]? {
            if let list = try? c.decodeIfPresent([EntityRef].self, forKey: key), let list {
                return list
            }
            if let single = try? c.decodeIfPresent(EntityRef.self, forKey: key) {
                return single.map { [$0] }
            }
            return nil
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: ArgKeys.self)
            try c.encodeIfPresent(subject, forKey: .subject)
            try c.encodeIfPresent(optionA, forKey: .optionA)
            try c.encodeIfPresent(optionB, forKey: .optionB)
            try c.encodeIfPresent(orderedCategory, forKey: .orderedCategory)
            try c.encodeIfPresent(offset, forKey: .offset)
            if let left { left.count == 1 ? try c.encode(left[0], forKey: .left) : try c.encode(left, forKey: .left) }
            if let right { right.count == 1 ? try c.encode(right[0], forKey: .right) : try c.encode(right, forKey: .right) }
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        textJA = try c.decode(String.self, forKey: .textJA)
        let type = try c.decode(String.self, forKey: .type)
        let args = try c.decode(Args.self, forKey: .args)

        func req<T>(_ value: T?, _ field: String) throws -> T {
            guard let value else {
                throw DecodingError.dataCorruptedError(forKey: .args, in: c, debugDescription: "clue type \(type) missing \(field)")
            }
            return value
        }

        switch type {
        case "same":
            logic = .same(left: try req(args.left?.first, "left"), right: try req(args.right?.first, "right"))
        case "different":
            logic = .different(left: try req(args.left?.first, "left"), right: try req(args.right?.first, "right"))
        case "either":
            logic = .either(
                subject: try req(args.subject, "subject"),
                optionA: try req(args.optionA, "optionA"),
                optionB: try req(args.optionB, "optionB")
            )
        case "pairSet":
            logic = .pairSet(left: try req(args.left, "left"), right: try req(args.right, "right"))
        case "before":
            logic = .before(
                left: try req(args.left?.first, "left"),
                right: try req(args.right?.first, "right"),
                orderedCategory: try req(args.orderedCategory, "orderedCategory")
            )
        case "immediatelyBefore":
            logic = .immediatelyBefore(
                left: try req(args.left?.first, "left"),
                right: try req(args.right?.first, "right"),
                orderedCategory: try req(args.orderedCategory, "orderedCategory")
            )
        case "offsetBefore":
            logic = .offsetBefore(
                left: try req(args.left?.first, "left"),
                right: try req(args.right?.first, "right"),
                orderedCategory: try req(args.orderedCategory, "orderedCategory"),
                offset: try req(args.offset, "offset")
            )
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "unknown clue type \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(textJA, forKey: .textJA)
        let (type, args): (String, Args)
        switch logic {
        case let .same(l, r): (type, args) = ("same", Args(left: [l], right: [r], subject: nil, optionA: nil, optionB: nil, orderedCategory: nil, offset: nil))
        case let .different(l, r): (type, args) = ("different", Args(left: [l], right: [r], subject: nil, optionA: nil, optionB: nil, orderedCategory: nil, offset: nil))
        case let .either(s, a, b): (type, args) = ("either", Args(left: nil, right: nil, subject: s, optionA: a, optionB: b, orderedCategory: nil, offset: nil))
        case let .pairSet(l, r): (type, args) = ("pairSet", Args(left: l, right: r, subject: nil, optionA: nil, optionB: nil, orderedCategory: nil, offset: nil))
        case let .before(l, r, oc): (type, args) = ("before", Args(left: [l], right: [r], subject: nil, optionA: nil, optionB: nil, orderedCategory: oc, offset: nil))
        case let .immediatelyBefore(l, r, oc): (type, args) = ("immediatelyBefore", Args(left: [l], right: [r], subject: nil, optionA: nil, optionB: nil, orderedCategory: oc, offset: nil))
        case let .offsetBefore(l, r, oc, off): (type, args) = ("offsetBefore", Args(left: [l], right: [r], subject: nil, optionA: nil, optionB: nil, orderedCategory: oc, offset: off))
        }
        try c.encode(type, forKey: .type)
        try c.encode(args, forKey: .args)
    }
}

public struct SolutionRow: Codable, Sendable {
    /// categoryID -> valueID for every category, including the primary one.
    public let assignments: [String: String]

    public init(from decoder: Decoder) throws {
        assignments = try [String: String](from: decoder)
    }
    public func encode(to encoder: Encoder) throws {
        try assignments.encode(to: encoder)
    }
}

extension SolutionRow: Hashable {
    // `Dictionary` isn't `Hashable` (only `Equatable`), so `assignments`
    // blocks the usual automatic synthesis — hash a deterministically
    // ordered view of it instead.
    public static func == (lhs: SolutionRow, rhs: SolutionRow) -> Bool {
        lhs.assignments == rhs.assignments
    }
    public func hash(into hasher: inout Hasher) {
        for key in assignments.keys.sorted() {
            hasher.combine(key)
            hasher.combine(assignments[key])
        }
    }
}

public struct CaseSolution: Codable, Hashable, Sendable {
    public let rows: [SolutionRow]
}

public struct DeducedFact: Codable, Hashable, Sendable {
    public let relation: String
    public let left: EntityRef
    public let right: EntityRef
    public let textJA: String
}

public struct DeductionStep: Codable, Hashable, Sendable {
    public let step: Int
    public let clueIDs: [String]
    public let candidateCountBefore: Int
    public let candidateCountAfter: Int
    public let deducedFacts: [DeducedFact]
    public let explanationJA: String
}

public struct ProofMetrics: Codable, Hashable, Sendable {
    public let searchSpace: Int
    public let solutionCount: Int
    public let clueCount: Int
    public let deductionStepCount: Int
    public let requiresGuess: Bool
}

public struct CaseRecord: Codable, Hashable, Sendable, Identifiable {
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
    public let editorialStatus: String
    public let checksum: String

    public var id: String { caseID }

    /// The sole ordered category (validated at content-build time to always
    /// be the last one) — the axis the grid renders as "1st, 2nd, 3rd…".
    public var orderedCategory: CaseCategory { categories.last! }

    /// The identity category every other category's values are assigned to.
    public var primaryCategory: CaseCategory { categories[0] }

    /// The categories a player fills in against the primary one — everything
    /// but the primary category itself.
    public var assignedCategories: [CaseCategory] { Array(categories.dropFirst()) }
}
