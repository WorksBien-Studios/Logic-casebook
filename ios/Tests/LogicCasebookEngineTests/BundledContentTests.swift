import Testing
@testable import LogicCasebookEngine
import LogicCasebookContent

@Suite("Bundled content")
struct BundledContentTests {
    @Test("decodes all 1,000 cases")
    func decodesFullBundle() throws {
        let bundle = try BundledContent.load()
        #expect(bundle.caseCount == 1000)
        #expect(bundle.cases.count == 1000)
        #expect(Set(bundle.cases.map(\.caseID)).count == 1000, "case IDs must be unique")
    }

    @Test("every case has completed editorial review")
    func allCasesApproved() throws {
        let bundle = try BundledContent.load()
        let notApproved = bundle.cases.filter { $0.editorialStatus != .approved }
        #expect(notApproved.isEmpty, "\(notApproved.count) case(s) are not marked approved")
    }

    @Test("free-case allocation matches the locked launch scope")
    func freeAllocation() throws {
        let bundle = try BundledContent.load()
        let freeByDifficulty = Dictionary(grouping: bundle.cases.filter(\.isFree), by: \.difficulty)
            .mapValues(\.count)
        #expect(freeByDifficulty[.beginner] == 10)
        #expect(freeByDifficulty[.standard] == 8)
        #expect(freeByDifficulty[.advanced] == 8)
        #expect(freeByDifficulty[.expert] == 4)
        #expect(bundle.cases.filter(\.isFree).count == 30)
    }

    @Test("case jp.logic.0001 decodes with its known content")
    func firstCase() throws {
        let bundle = try BundledContent.load()
        let first = try #require(bundle.cases.first { $0.caseID == "jp.logic.0001" })
        #expect(first.titleJA == "消えた展示札（その1）")
        #expect(first.difficulty == .beginner)
        #expect(first.isFree)
        #expect(first.clues.count == 3)
        #expect(first.categories.map(\.id) == ["people", "objects", "times"])
    }
}
