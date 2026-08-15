import Foundation
import Combine
import DLPSNotifyCore

/// One recorded new-game or update event. Persisted as the app's history "database".
struct HistoryEntry: Codable, Identifiable, Equatable {
    let postID: Int
    let name: String
    let link: String
    let isNew: Bool
    let platform: String?
    /// Site timestamp of the change ("yyyy-MM-dd'T'HH:mm:ss").
    let modified: String?
    /// For updates: what was added, e.g. "+ USA (@DUPLEX)".
    let detail: String?
    /// TitleID codes found in the post (for matching the user's library).
    let codes: [String]?
    /// Dotted version strings found in the post (best-effort, for version compare).
    let dlpsVersions: [String]?
    /// When this app recorded the event.
    let recordedAt: Date

    /// Unique per event (a post can appear multiple times over its update history).
    var id: String { "\(postID)-\(modified ?? "")-\(Int(recordedAt.timeIntervalSince1970))" }
    /// Identifies the same change regardless of when we recorded it (for dedup on backfill).
    var dedupKey: String { "\(postID)|\(modified ?? "")" }
    var url: URL? { URL(string: link) }

    enum CodingKeys: String, CodingKey {
        case postID, name, link, isNew, platform, modified, detail, codes, dlpsVersions, recordedAt
    }

    init(event: GameEvent, detail: String?, codes: [String]? = nil,
         dlpsVersions: [String]? = nil, recordedAt: Date = Date()) {
        postID = event.post.id
        name = event.post.name
        link = event.post.link
        isNew = event.isNew
        platform = event.post.platforms.first?.name
        modified = event.post.modified
        self.detail = detail
        self.codes = codes
        self.dlpsVersions = dlpsVersions
        self.recordedAt = recordedAt
    }

    init(postID: Int, name: String, link: String, isNew: Bool,
         platform: String?, modified: String?, detail: String?, recordedAt: Date,
         codes: [String]? = nil, dlpsVersions: [String]? = nil) {
        self.postID = postID
        self.name = name
        self.link = link
        self.isNew = isNew
        self.platform = platform
        self.modified = modified
        self.detail = detail
        self.codes = codes
        self.dlpsVersions = dlpsVersions
        self.recordedAt = recordedAt
    }
}

/// Persists the full history to a JSON file (separate from the small menu list).
enum HistoryStore {
    private static let maxEntries = 2000

    static var fileURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("DLPSNotify", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    static func load() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return []
        }
        return items
    }

    static func save(_ entries: [HistoryEntry]) {
        let capped = Array(entries.prefix(maxEntries))
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(capped).write(to: fileURL, options: .atomic)
        } catch {}
    }
}

/// Observable history shared between the menu and the history window.
final class HistoryModel: ObservableObject {
    @Published private(set) var entries: [HistoryEntry]

    init() {
        let loaded = HistoryStore.load()
        entries = loaded.isEmpty ? HistoryModel.migrateLegacyRecent() : loaded
    }

    /// Prepend newest-first entries and persist.
    func add(_ newEntries: [HistoryEntry]) {
        guard !newEntries.isEmpty else { return }
        entries.insert(contentsOf: newEntries, at: 0)
        HistoryStore.save(entries)
    }

    /// Merge backfilled entries (skip ones already present), sort newest-first, persist.
    /// Returns how many were actually added.
    @discardableResult
    func merge(_ incoming: [HistoryEntry]) -> Int {
        guard !incoming.isEmpty else { return 0 }
        var keys = Set(entries.map(\.dedupKey))
        var added = 0
        var merged = entries
        for entry in incoming where !keys.contains(entry.dedupKey) {
            merged.append(entry)
            keys.insert(entry.dedupKey)
            added += 1
        }
        merged.sort { ($0.modified ?? "") > ($1.modified ?? "") }
        entries = Array(merged.prefix(2000))
        HistoryStore.save(entries)
        return added
    }

    /// One-time migration of the old capped menu list (UserDefaults) into history.
    private static func migrateLegacyRecent() -> [HistoryEntry] {
        struct Legacy: Decodable {
            let id: Int; let name: String; let link: String; let isNew: Bool
            let platform: String?; let modified: String?; let detail: String?
        }
        guard let data = UserDefaults.standard.data(forKey: "recentItems"),
              let legacy = try? JSONDecoder().decode([Legacy].self, from: data) else {
            return []
        }
        let entries = legacy.map {
            HistoryEntry(postID: $0.id, name: $0.name, link: $0.link, isNew: $0.isNew,
                         platform: $0.platform, modified: $0.modified, detail: $0.detail,
                         recordedAt: Date())
        }
        if !entries.isEmpty { HistoryStore.save(entries) }
        return entries
    }
}

/// Full "dd.MM.yyyy HH:mm" rendering for the history table (no today-collapsing).
enum DateDisplay {
    static func full(_ apiTimestamp: String?, recordedAt: Date) -> String {
        if let apiTimestamp, let formatted = fromISO(apiTimestamp) { return formatted }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: recordedAt)
    }

    private static func fromISO(_ timestamp: String) -> String? {
        let halves = timestamp.split(separator: "T")
        guard halves.count == 2 else { return nil }
        let date = halves[0].split(separator: "-")
        let time = halves[1].split(separator: ":")
        guard date.count == 3, time.count >= 2 else { return nil }
        return "\(date[2]).\(date[1]).\(date[0]) \(time[0]):\(time[1])"
    }
}
