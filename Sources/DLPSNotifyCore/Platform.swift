import Foundation

/// A PlayStation platform as exposed by the DLPS WordPress category taxonomy.
public struct Platform: Hashable, Sendable {
    public let key: String        // stable id used in settings, e.g. "ps5"
    public let name: String       // display name, e.g. "PS5"
    public let categoryID: Int    // WordPress category id

    public init(key: String, name: String, categoryID: Int) {
        self.key = key
        self.name = name
        self.categoryID = categoryID
    }
}

public enum Platforms {
    /// The platform categories that actually exist on dlpsgame.com (verified via
    /// the categories API). The site is PlayStation-only — no Xbox/Switch.
    public static let all: [Platform] = [
        Platform(key: "ps5", name: "PS5", categoryID: 63019),
        Platform(key: "ps4", name: "PS4", categoryID: 4370),
        Platform(key: "ps3", name: "PS3", categoryID: 64),
        Platform(key: "ps2", name: "PS2", categoryID: 5917),
        Platform(key: "psn", name: "PSN", categoryID: 110),
    ]

    public static let allKeys: Set<String> = Set(all.map(\.key))

    private static let byCategoryID: [Int: Platform] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.categoryID, $0) })

    public static func platforms(for categories: [Int]) -> [Platform] {
        categories.compactMap { byCategoryID[$0] }
    }

    /// Whether a post passes the platform filter. Posts with no recognized
    /// platform always pass, so nothing is silently dropped.
    public static func matches(categories: [Int], selectedKeys: Set<String>) -> Bool {
        let postPlatforms = platforms(for: categories)
        if postPlatforms.isEmpty { return true }
        return postPlatforms.contains { selectedKeys.contains($0.key) }
    }
}
