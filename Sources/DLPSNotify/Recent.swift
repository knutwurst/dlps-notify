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
    /// API timestamp of the change/addition ("yyyy-MM-dd'T'HH:mm:ss").
    /// Optional so older persisted entries (without it) still decode.
    let modified: String?

    init(event: GameEvent) {
        id = event.post.id
        name = event.post.name
        link = event.post.link
        isNew = event.isNew
        platform = event.post.platforms.first?.name
        modified = event.post.modified
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

/// Formats the API timestamp for display, without timezone conversion (shows the
/// same wall-clock the site uses). "2026-06-22T01:10:22" -> "22.06.2026 01:10".
enum RecentDate {
    static func display(_ apiTimestamp: String?) -> String? {
        guard let value = apiTimestamp else { return nil }
        let halves = value.split(separator: "T")
        guard halves.count == 2 else { return nil }
        let date = halves[0].split(separator: "-")   // yyyy, MM, dd
        let time = halves[1].split(separator: ":")    // HH, mm, ss
        guard date.count == 3, time.count >= 2 else { return nil }
        return "\(date[2]).\(date[1]).\(date[0]) \(time[0]):\(time[1])"
    }
}
