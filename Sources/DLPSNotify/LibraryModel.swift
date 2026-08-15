import Foundation
import Combine
import DLPSNotifyCore

/// Whether the user owns a game (matched against their library file) and whether
/// their version looks current.
enum OwnershipStatus {
    case unknown            // no library configured
    case notOwned
    case owned(myVersion: String?)
    case updateAvailable(myVersion: String?)
}

/// Loads and re-reads the user's library file. Uses a security-scoped bookmark so
/// access persists across launches, even for TCC-protected folders (Dropbox/iCloud,
/// Desktop, Documents…). A failed read never wipes the already-loaded list.
final class LibraryModel: ObservableObject {
    @Published private(set) var index = LibraryIndex(games: [])
    @Published private(set) var games: [LibraryGame] = []
    @Published private(set) var path: String?
    private var lastModified: Date?

    private let pathKey = "libraryPath"
    private let bookmarkKey = "libraryBookmark"

    init() {
        path = UserDefaults.standard.string(forKey: pathKey)
        reload()
    }

    var isConfigured: Bool { path != nil }
    var count: Int { index.count }
    var fileName: String? { path.map { ($0 as NSString).lastPathComponent } }

    /// Configure from a user-picked URL: store the path (for display) and a
    /// security-scoped bookmark (for persistent read access), then load.
    func setURL(_ url: URL) {
        path = url.path
        UserDefaults.standard.set(url.path, forKey: pathKey)
        if let data = (try? url.bookmarkData(options: [.withSecurityScope])) ?? (try? url.bookmarkData()) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        } else {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
        }
        lastModified = nil
        reload()
    }

    @discardableResult
    func reload() -> Int {
        guard let (url, scoped) = resolveURL() else {
            games = []
            index = LibraryIndex(games: [])
            return 0
        }
        if scoped { _ = url.startAccessingSecurityScopedResource() }
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return index.count   // keep the last good data on a transient read failure
        }
        let parsed = LibraryParser.parse(text)
        games = parsed
        index = LibraryIndex(games: parsed)
        lastModified = modificationDate(url)
        return index.count
    }

    /// Re-read only if the file changed since last read (called on each poll).
    func reloadIfChanged() {
        guard let (url, scoped) = resolveURL() else { return }
        if scoped { _ = url.startAccessingSecurityScopedResource() }
        let current = modificationDate(url)
        if scoped { url.stopAccessingSecurityScopedResource() }
        if current != lastModified { reload() }
    }

    private func resolveURL() -> (url: URL, scoped: Bool)? {
        if let data = UserDefaults.standard.data(forKey: bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                  relativeTo: nil, bookmarkDataIsStale: &stale) {
                return (url, true)
            }
            if let url = try? URL(resolvingBookmarkData: data, relativeTo: nil, bookmarkDataIsStale: &stale) {
                return (url, false)
            }
        }
        if let path { return (URL(fileURLWithPath: path), false) }
        return nil
    }

    private func modificationDate(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    /// Ownership + version status for a DLPS entry (platform-aware name fallback).
    func status(codes: [String]?, name: String, platform: String?, dlpsVersions: [String]?) -> OwnershipStatus {
        guard !index.isEmpty else { return .unknown }
        var game: LibraryGame?
        if let codes {
            for code in codes {
                if let match = index.game(forCode: code) { game = match; break }
            }
        }
        if game == nil { game = index.game(forName: name, platform: platform) }
        guard let game else { return .notOwned }

        if let mine = game.version, let dlpsVersions {
            for version in dlpsVersions where VersionCompare.isNewer(version, than: mine) == true {
                return .updateAvailable(myVersion: mine)
            }
        }
        return .owned(myVersion: game.version)
    }
}
