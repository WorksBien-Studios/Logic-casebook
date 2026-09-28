import Testing
@testable import LogicCasebookEngine

@Suite("CaseBundleLoader")
struct CaseBundleLoaderTests {
    @Test("loads exactly 1,000 cases with unique IDs and structural signatures")
    func loadsFullBundle() throws {
        let cases = try CaseBundleLoader.loadAll()
        #expect(cases.count == 1000)
        #expect(Set(cases.map(\.caseID)).count == 1000)
        #expect(Set(cases.map(\.structuralSignature)).count == 1000)
    }

    @Test("matches the locked difficulty and free-case allocation", arguments: [
        (Difficulty.beginner, 120, 10),
        (Difficulty.standard, 260, 8),
        (Difficulty.advanced, 360, 8),
        (Difficulty.expert, 260, 4)
    ])
    func matchesAllocation(difficulty: Difficulty, total: Int, free: Int) throws {
        let cases = try CaseBundleLoader.loadAll().filter { $0.difficulty == difficulty }
        #expect(cases.count == total)
        #expect(cases.filter(\.isFree).count == free)
    }

    @Test("every case is editorially approved")
    func allApproved() throws {
        let cases = try CaseBundleLoader.loadAll()
        #expect(cases.allSatisfy { $0.editorialStatus == "approved" })
    }
}
