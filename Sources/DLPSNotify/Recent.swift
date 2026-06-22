import Foundation
import DLPSNotifyCore

/// A game shown in the menu's "recent" list. Persisted so the list survives
/// relaunches.
struct RecentItem: Codable, Equatable {
    let id: Int
    let name: String
    let link: String
    let isNew: Bool
    let platform: String?

    init(event: GameEvent) {
        id = event.post.id
        name = event.post.name
        link = event.post.link
        isNew = event.isNew
        platform = event.post.platforms.first?.name
    }
}

enum RecentStore {
    private static let key = "recentItems"
    private static let maxItems = 30

    static func load() -> [RecentItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([RecentItem].self, from: data) else {
            return []
        }
        return items
    }

    static func save(_ items: [RecentItem]) {
        let capped = Array(items.prefix(maxItems))
        if let data = try? JSONEncoder().encode(capped) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
