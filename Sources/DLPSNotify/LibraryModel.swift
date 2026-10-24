import Foundation
import Combine
import DLPSNotifyCore

enum OwnershipStatus {
    case unknown   // no library file set
    case notOwned
    case owned(myVersion: String?)
    case updateAvailable(myVersion: String?)
}

// security-scoped bookmark, because Dropbox + TCC really don't want me to read this file
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
            return index.count   // read failed (hi TCC), keep what we had
        }
        let parsed = LibraryParser.parse(text)
        games = parsed
        index = LibraryIndex(games: parsed)
        lastModified = modificationDate(url)
        return index.count
    }

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
