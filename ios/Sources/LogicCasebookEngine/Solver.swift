import Foundation

/// Exhaustive clue solver, mirroring `evaluate()` in `tools/build_cases.py`
/// and `tools/validate_cases.py`. Used to prove a case still has exactly one
/// solution and that solution matches the bundled content — never used to
/// invent new cases at runtime (the locked spec forbids runtime generation).
public enum Solver {
    /// All permutations of `0..<n`, via Heap's algorithm.
    public static func permutations(_ n: Int) -> [[Int]] {
        guard n > 0 else { return [[]] }
        var result: [[Int]] = []
        var array = Array(0..<n)
        func permute(_ k: Int) {
            if k == array.count {
                result.append(array)
                return
            }
            for i in k..<array.count {
                array.swapAt(k, i)
                permute(k + 1)
                array.swapAt(k, i)
            }
        }
        permute(0)
        return result
    }

    /// The full candidate space: one permutation of `0..<n` per non-primary
    /// category, i.e. `permutations(n)^(k-1)` assignments.
    public static func allAssignments(n: Int, k: Int) -> [[[Int]]] {
        let perms = permutations(n)
        var result: [[[Int]]] = [[]]
        for _ in 0..<max(0, k - 1) {
            var next: [[[Int]]] = []
            next.reserveCapacity(result.count * perms.count)
            for partial in result {
                for permutation in perms {
                    next.append(partial + [permutation])
                }
            }
            result = next
        }
        return result
    }

    public static func evaluate(_ clue: Clue, assignment: [[Int]], context: CaseContext) -> Bool {
        switch clue.args {
        case let .sameOrDifferent(leftRef, rightRef):
            let left = context.numeric(leftRef)
            let right = context.numeric(rightRef)
            let same = context.owner(assignment, category: left.category, value: left.value)
                == context.owner(assignment, category: right.category, value: right.value)
            return clue.type == .same ? same : !same

        case let .either(subjectRef, optionARef, optionBRef):
            let subject = context.numeric(subjectRef)
            let optionA = context.numeric(optionARef)
            let optionB = context.numeric(optionBRef)
            let subjectOwner = context.owner(assignment, category: subject.category, value: subject.value)
            return subjectOwner == context.owner(assignment, category: optionA.category, value: optionA.value)
                || subjectOwner == context.owner(assignment, category: optionB.category, value: optionB.value)

        case let .pairSet(leftRefs, rightRefs):
            let leftOwners = Set(leftRefs.map { ref -> Int in
                let numeric = context.numeric(ref)
                return context.owner(assignment, category: numeric.category, value: numeric.value)
            })
            let rightOwners = Set(rightRefs.map { ref -> Int in
                let numeric = context.numeric(ref)
                return context.owner(assignment, category: numeric.category, value: numeric.value)
            })
            return leftOwners == rightOwners

        case let .ordering(leftRef, rightRef, orderedCategoryID, offset):
            guard let orderedCategory = context.categories.firstIndex(where: { $0.id == orderedCategoryID }) else {
                return false
            }
            let left = context.numeric(leftRef)
            let right = context.numeric(rightRef)
            let leftValue = context.orderedValue(assignment, entity: left, orderedCategory: orderedCategory)
            let rightValue = context.orderedValue(assignment, entity: right, orderedCategory: orderedCategory)
            switch clue.type {
            case .before:
                return leftValue < rightValue
            case .immediatelyBefore:
                return rightValue - leftValue == 1
            case .offsetBefore:
                return rightValue - leftValue == (offset ?? 0)
            case .same, .different, .either, .pairSet:
                return false
            }
        }
    }

    /// Every assignment consistent with every one of the case's clues.
    public static func solve(_ clues: [Clue], context: CaseContext) -> [[[Int]]] {
        context.assignments.filter { assignment in
            clues.allSatisfy { evaluate($0, assignment: assignment, context: context) }
        }
    }
}
