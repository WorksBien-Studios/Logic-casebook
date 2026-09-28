import CryptoKit
import Foundation

/// Thin wrapper over CryptoKit's `SHA256` (Apple's own hashing framework,
/// needing no external dependency) producing the lowercase hex string the
/// content pipeline's `hashlib.sha256(...).hexdigest()` produces, so shard
/// checksums can be compared directly against `index.v1.json`.
enum SHA256 {
    static func hexDigest(of data: Data) -> String {
        let digest = CryptoKit.SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
