import Foundation
import SwiftData
import LogicCasebookEngine

public enum ProgressStatus: String, Codable, Sendable {
    case notStarted
    case inProgress
    case completed
}

/// Per-case player progress. Persisted locally with SwiftData — per the
/// locked spec there is no account, login or server dependency, so progress
/// never leaves the device.
@Model
public final class CaseProgress {
    @Attribute(.unique) public var caseID: String
    public var statusRaw: String
    public var hintsUsed: Int
    public var validationAttempts: Int
    public var isPerfect: Bool
    public var timeSpentSeconds: Int
    public var lastPlayedAt: Date
    public var marksData: Data?

    public init(caseID: String) {
        self.caseID = caseID
        self.statusRaw = ProgressStatus.notStarted.rawValue
        self.hintsUsed = 0
        self.validationAttempts = 0
        self.isPerfect = true
        self.timeSpentSeconds = 0
        self.lastPlayedAt = .now
        self.marksData = nil
    }

    public var status: ProgressStatus {
        get { ProgressStatus(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }

    public var marks: [GridKey: MarkState] {
        get {
            guard let marksData, let decoded = try? JSONDecoder().decode([GridKey: MarkState].self, from: marksData) else {
                return [:]
            }
            return decoded
        }
        set { marksData = try? JSONEncoder().encode(newValue) }
    }
}

/// Convenience lookups over a `ModelContext` — every call site otherwise
/// needs the same fetch-or-create boilerplate.
public enum ProgressStore {
    public static func progress(for caseID: String, in context: ModelContext) -> CaseProgress {
        let descriptor = FetchDescriptor<CaseProgress>(predicate: #Predicate { $0.caseID == caseID })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = CaseProgress(caseID: caseID)
        context.insert(created)
        return created
    }
}
