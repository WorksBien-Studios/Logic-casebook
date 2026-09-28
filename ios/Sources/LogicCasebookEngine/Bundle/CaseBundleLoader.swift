import Foundation

/// The 20-shard index bundled at `Resources/CaseBundle/index.v1.json`,
/// mirroring `data/cases/index.v1.json` in the content repository.
struct ShardIndex: Codable {
    struct Shard: Codable {
        let path: String
        let sha256: String
        let caseCount: Int
    }
    let bundleSchemaVersion: Int
    let bundleID: String
    let contentVersion: Int
    let caseCount: Int
    let shards: [Shard]
}

private struct Shard: Codable {
    let caseCount: Int
    let cases: [CaseRecord]
}

public enum CaseBundleError: Error, LocalizedError {
    case resourceMissing(String)
    case shardChecksumMismatch(String)
    case shardCountMismatch(String)
    case bundleCountMismatch(expected: Int, found: Int)
    case duplicateCaseIDs
    case duplicateStructuralSignatures

    public var errorDescription: String? {
        switch self {
        case .resourceMissing(let name): "content resource missing: \(name)"
        case .shardChecksumMismatch(let path): "shard checksum mismatch: \(path)"
        case .shardCountMismatch(let path): "shard case count mismatch: \(path)"
        case .bundleCountMismatch(let expected, let found): "bundle case count \(found), expected \(expected)"
        case .duplicateCaseIDs: "duplicate case IDs in bundle"
        case .duplicateStructuralSignatures: "duplicate structural signatures in bundle"
        }
    }
}

/// Loads and assembles the 1,000-case content bundle from the 20 shard
/// files bundled with the app (the same shards `tools/assemble_bundle.py`
/// concatenates at content-build time), and checks the integrity
/// invariants the content pipeline already enforces (`tools/validate_cases.py`)
/// so a corrupted or tampered bundle fails loudly instead of silently.
///
/// This is the offline equivalent of re-fetching from a server: there is no
/// server, so the one thing the app can still do is re-check its own copy.
public enum CaseBundleLoader {
    /// Loads every case from the bundled shards, verifying each shard's
    /// SHA-256 against the index and the resulting bundle's structural
    /// invariants (unique case IDs, unique structural signatures, expected
    /// total count).
    public static func loadAll(bundle: Foundation.Bundle = .module) throws -> [CaseRecord] {
        guard let indexURL = bundle.url(forResource: "index.v1", withExtension: "json", subdirectory: "CaseBundle") else {
            throw CaseBundleError.resourceMissing("index.v1.json")
        }
        let index = try JSONDecoder().decode(ShardIndex.self, from: Data(contentsOf: indexURL))

        var cases: [CaseRecord] = []
        cases.reserveCapacity(index.caseCount)

        for shardEntry in index.shards {
            let fileName = (shardEntry.path as NSString).lastPathComponent
            let baseName = (fileName as NSString).deletingPathExtension
            guard let shardURL = bundle.url(forResource: baseName, withExtension: "json", subdirectory: "CaseBundle") else {
                throw CaseBundleError.resourceMissing(fileName)
            }
            let raw = try Data(contentsOf: shardURL)
            guard SHA256.hexDigest(of: raw) == shardEntry.sha256 else {
                throw CaseBundleError.shardChecksumMismatch(fileName)
            }
            let shard = try JSONDecoder().decode(Shard.self, from: raw)
            guard shard.caseCount == shardEntry.caseCount, shard.cases.count == shardEntry.caseCount else {
                throw CaseBundleError.shardCountMismatch(fileName)
            }
            cases.append(contentsOf: shard.cases)
        }

        guard cases.count == index.caseCount else {
            throw CaseBundleError.bundleCountMismatch(expected: index.caseCount, found: cases.count)
        }
        guard Set(cases.map(\.caseID)).count == cases.count else {
            throw CaseBundleError.duplicateCaseIDs
        }
        guard Set(cases.map(\.structuralSignature)).count == cases.count else {
            throw CaseBundleError.duplicateStructuralSignatures
        }
        return cases
    }
}
