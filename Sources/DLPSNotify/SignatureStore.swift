import Foundation

/// Per-post snapshot of download entries (region + group/format), used to diff
/// what an update changed. Keyed by post id (as string, for JSON).
enum SignatureStore {
    private static let key = "downloadSignatures"
    private static let maxPosts = 800

    static func load() -> [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return dict
    }

    static func save(_ signatures: [String: [String]]) {
        var dict = signatures
        if dict.count > maxPosts {
            dict = Dictionary(uniqueKeysWithValues: Array(dict).suffix(maxPosts))
        }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
