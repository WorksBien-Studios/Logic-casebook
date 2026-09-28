import Foundation
import Observation
import SwiftData
import LogicCasebookEngine

@MainActor
public struct CaseLibraryEntry: Identifiable {
    public let record: CaseRecord
    public let progress: CaseProgressRecord?
    public var id: String { record.caseID }

    public var status: String {
        if progress?.isSolved == true { "完了" }
        else if progress != nil { "進行中" }
        else { "未着手" }
    }
}

/// Loads the bundled 1,000-case content once and joins it with SwiftData
/// progress records — the engine stays storage-agnostic (`CaseBundleLoader`
/// only knows about the app bundle), so this view-model is the one place
/// that reconciles static content with per-player state.
@Observable
@MainActor
public final class LibraryViewModel {
    public private(set) var allCases: [CaseRecord] = []
    public private(set) var loadError: String?
    private var progressByCaseID: [String: CaseProgressRecord] = [:]

    public func load(modelContext: ModelContext) {
        do {
            allCases = try CaseBundleLoader.loadAll().sorted { $0.caseID < $1.caseID }
        } catch {
            loadError = error.localizedDescription
        }
        refreshProgress(modelContext: modelContext)
    }

    public func refreshProgress(modelContext: ModelContext) {
        let records = (try? modelContext.fetch(FetchDescriptor<CaseProgressRecord>())) ?? []
        progressByCaseID = Dictionary(uniqueKeysWithValues: records.map { ($0.caseID, $0) })
    }

    public func entries(for difficulty: Difficulty) -> [CaseLibraryEntry] {
        allCases
            .filter { $0.difficulty == difficulty }
            .map { CaseLibraryEntry(record: $0, progress: progressByCaseID[$0.caseID]) }
    }

    public var continuing: CaseLibraryEntry? {
        progressByCaseID.values
            .filter { !$0.isSolved }
            .max { $0.lastPlayedAt < $1.lastPlayedAt }
            .flatMap { progress in allCases.first { $0.caseID == progress.caseID } }
            .map { CaseLibraryEntry(record: $0, progress: progressByCaseID[$0.caseID]) }
    }

    public func matches(_ record: CaseRecord, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return record.titleJA.localizedCaseInsensitiveContains(query)
            || record.scenarioJA.localizedCaseInsensitiveContains(query)
    }
}
