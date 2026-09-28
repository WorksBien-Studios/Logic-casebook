import Foundation

/// An `Assignment` is one candidate solution to a case: for every non-primary
/// category `c` (1..<k) and every "owner" (an index into the primary
/// category's values), `values[c-1][owner]` is the index of the value that
/// owner has in category `c`. Each `values[c-1]` is therefore a permutation
/// of `0..<n`.
///
/// This mirrors `numeric_context`/`owner`/`evaluate` in
/// `tools/validate_cases.py` exactly, so a case that passes the content
/// pipeline's validator is solved identically here.
public struct Assignment: Hashable, Sendable {
    public let values: [[Int]]

    /// The owner (primary-category index) holding `value` in `category`
    /// (0 = the primary category itself, where the "owner" of a value is
    /// the value's own index).
    public func owner(category: Int, value: Int) -> Int {
        guard category > 0 else { return value }
        return values[category - 1].firstIndex(of: value)!
    }

    /// The value a given owner holds in the ordered category — the basis
    /// for the `before`/`immediatelyBefore`/`offsetBefore` relations.
    public func orderedValue(ownerOf entity: (category: Int, value: Int), orderedCategory: Int) -> Int {
        values[orderedCategory - 1][owner(category: entity.category, value: entity.value)]
    }
}

/// A clue compiled against a specific case's category/value indices, ready
/// to evaluate against candidate assignments without repeated string
/// lookups.
struct CompiledClue {
    let id: String
    let evaluate: @Sendable (Assignment) -> Bool
}

/// The exhaustive constraint solver behind case loading, solution
/// validation and contradiction detection. Case categories are capped at
/// 3–5 values and 3–4 categories by the content schema, so the full search
/// space (`n!^(k-1)`) never exceeds a few tens of thousands of candidate
/// assignments (1000 published cases top out at 14,400) — small enough to
/// brute-force on every grid edit rather than needing incremental
/// constraint propagation.
public struct CaseSolver {
    public let categoryIndex: [String: Int]
    public let valueIndex: [String: [String: Int]]
    private let n: Int
    private let k: Int
    private let compiledClues: [CompiledClue]
    private let allAssignments: [Assignment]

    public init(case record: CaseRecord) {
        var catIdx: [String: Int] = [:]
        var valIdx: [String: [String: Int]] = [:]
        for (i, category) in record.categories.enumerated() {
            catIdx[category.id] = i
            var values: [String: Int] = [:]
            for (j, value) in category.values.enumerated() { values[value.id] = j }
            valIdx[category.id] = values
        }
        self.categoryIndex = catIdx
        self.valueIndex = valIdx
        self.n = record.categories[0].values.count
        self.k = record.categories.count

        func ref(_ r: EntityRef) -> (category: Int, value: Int) {
            (catIdx[r.categoryID]!, valIdx[r.categoryID]![r.valueID]!)
        }

        self.compiledClues = record.clues.map { clue in
            CompiledClue(id: clue.id, evaluate: Self.compile(clue.logic, ref: ref, categoryIndex: catIdx))
        }
        self.allAssignments = Self.enumerateAssignments(n: n, k: k)
    }

    private static func compile(
        _ logic: ClueLogic,
        ref: (EntityRef) -> (category: Int, value: Int),
        categoryIndex: [String: Int]
    ) -> @Sendable (Assignment) -> Bool {
        switch logic {
        case let .same(l, r):
            let (lc, lv) = ref(l), (rc, rv) = ref(r)
            return { a in a.owner(category: lc, value: lv) == a.owner(category: rc, value: rv) }
        case let .different(l, r):
            let (lc, lv) = ref(l), (rc, rv) = ref(r)
            return { a in a.owner(category: lc, value: lv) != a.owner(category: rc, value: rv) }
        case let .either(s, oa, ob):
            let (sc, sv) = ref(s), (ac, av) = ref(oa), (bc, bv) = ref(ob)
            return { a in
                let p = a.owner(category: sc, value: sv)
                return p == a.owner(category: ac, value: av) || p == a.owner(category: bc, value: bv)
            }
        case let .pairSet(lefts, rights):
            let lrefs = lefts.map(ref), rrefs = rights.map(ref)
            return { a in
                Set(lrefs.map { a.owner(category: $0.category, value: $0.value) })
                    == Set(rrefs.map { a.owner(category: $0.category, value: $0.value) })
            }
        case let .before(l, r, orderedCategoryID):
            let lRef = ref(l), rRef = ref(r), oc = categoryIndex[orderedCategoryID]!
            return { a in
                a.orderedValue(ownerOf: lRef, orderedCategory: oc) < a.orderedValue(ownerOf: rRef, orderedCategory: oc)
            }
        case let .immediatelyBefore(l, r, orderedCategoryID):
            let lRef = ref(l), rRef = ref(r), oc = categoryIndex[orderedCategoryID]!
            return { a in
                a.orderedValue(ownerOf: rRef, orderedCategory: oc) - a.orderedValue(ownerOf: lRef, orderedCategory: oc) == 1
            }
        case let .offsetBefore(l, r, orderedCategoryID, offset):
            let lRef = ref(l), rRef = ref(r), oc = categoryIndex[orderedCategoryID]!
            return { a in
                a.orderedValue(ownerOf: rRef, orderedCategory: oc) - a.orderedValue(ownerOf: lRef, orderedCategory: oc) == offset
            }
        }
    }

    /// All `(n!)^(k-1)` candidate assignments, generated once per case at
    /// load time and then filtered per query — see the type-level doc for
    /// why brute force is appropriate here.
    private static func enumerateAssignments(n: Int, k: Int) -> [Assignment] {
        let perms = permutations(of: Array(0..<n))
        guard k > 1 else { return [Assignment(values: [])] }
        var combos: [[[Int]]] = perms.map { [$0] }
        for _ in 2..<k {
            combos = combos.flatMap { combo in perms.map { combo + [$0] } }
        }
        return combos.map(Assignment.init(values:))
    }

    private static func permutations(of array: [Int]) -> [[Int]] {
        guard array.count > 1 else { return [array] }
        var result: [[Int]] = []
        for (i, element) in array.enumerated() {
            var rest = array
            rest.remove(at: i)
            for perm in permutations(of: rest) { result.append([element] + perm) }
        }
        return result
    }

    /// Every assignment satisfying the case's own clues plus any extra
    /// constraints (a player's confirmed/excluded marks). An empty result
    /// means those marks contradict the case; more than one means the grid
    /// doesn't yet pin down a unique solution.
    public func solutions(extraConstraints: [@Sendable (Assignment) -> Bool] = []) -> [Assignment] {
        allAssignments.filter { a in
            compiledClues.allSatisfy { $0.evaluate(a) } && extraConstraints.allSatisfy { $0(a) }
        }
    }

    public func ref(_ entity: EntityRef) -> (category: Int, value: Int) {
        (categoryIndex[entity.categoryID]!, valueIndex[entity.categoryID]![entity.valueID]!)
    }
}
