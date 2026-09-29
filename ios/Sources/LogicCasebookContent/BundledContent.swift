import Foundation
import LogicCasebookEngine

/// Loads the canonical, editorially-approved 1,000-case bundle that ships
/// inside the app. This is the only place the app reads case content from —
/// per the locked spec, there is no runtime case generation and no server
/// dependency.
public enum BundledContent {
    public enum LoadError: Error {
        case resourceNotFound
    }

    private static let cached: CaseBundle = {
        // A failure here means the app was shipped without its content
        // bundle, which the release-acceptance criteria (section 11 of the
        // locked spec) forbid — so this is a fatal, not a recoverable, error.
        do {
            return try load()
        } catch {
            fatalError("LogicCasebookContent: failed to load bundled cases: \(error)")
        }
    }()

    /// The full bundle, decoded once and cached for the process lifetime.
    public static func bundle() -> CaseBundle { cached }

    /// Decodes the bundle fresh from disk. Exposed for tests that want to
    /// validate the on-disk JSON itself rather than the cached instance.
    public static func load() throws -> CaseBundle {
        guard let url = Bundle.module.url(forResource: "cases.v1", withExtension: "json") else {
            throw LoadError.resourceNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CaseBundle.self, from: data)
    }
}
