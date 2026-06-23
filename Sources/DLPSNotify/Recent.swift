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
    let modified: String?
    /// For updates: a short "what changed" summary, e.g. "+ USA (@DUPLEX)". Optional.
    let detail: String?

    init(event: GameEvent, detail: String? = nil) {
        id = event.post.id
        name = event.post.name
        link = event.post.link
        isNew = event.isNew
        platform = event.post.platforms.first?.name
        modified = event.post.modified
        self.detail = detail
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

/// Compact display of the API timestamp (no timezone conversion — shows the same
/// wall-clock the site uses). Today → just "HH:mm"; same year → "dd.MM. HH:mm";
/// otherwise "dd.MM.yyyy HH:mm".
enum RecentDate {
    static func display(_ apiTimestamp: String?, now: Date = Date()) -> String? {
        guard let value = apiTimestamp else { return nil }
        let halves = value.split(separator: "T")
        guard halves.count == 2 else { return nil }
        let date = halves[0].split(separator: "-")   // yyyy, MM, dd
        let time = halves[1].split(separator: ":")    // HH, mm, ss
        guard date.count == 3, time.count >= 2 else { return nil }
        let (yyyy, mm, dd) = (String(date[0]), String(date[1]), String(date[2]))
        let hhmm = "\(time[0]):\(time[1])"

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: now)

        if "\(yyyy)-\(mm)-\(dd)" == today { return hhmm }
        if yyyy == today.prefix(4) { return "\(dd).\(mm). \(hhmm)" }
        return "\(dd).\(mm).\(yyyy) \(hhmm)"
    }
}
