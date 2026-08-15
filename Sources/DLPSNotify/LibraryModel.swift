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

/// Loads and re-reads the user's library file, exposing a fast lookup index.
final class LibraryModel: ObservableObject {
    @Published private(set) var index = LibraryIndex(games: [])
    @Published private(set) var games: [LibraryGame] = []
    @Published private(set) var path: String?
    private var lastModified: Date?

    private let pathKey = "libraryPath"

    init() {
        path = UserDefaults.standard.string(forKey: pathKey)
        reload()
    }

    var isConfigured: Bool { path != nil }
    var count: Int { index.count }

    func setPath(_ newPath: String?) {
        path = newPath
        UserDefaults.standard.set(newPath, forKey: pathKey)
        lastModified = nil
        reload()
    }

    /// Re-parse the file now. Returns the number of games loaded.
    @discardableResult
    func reload() -> Int {
        guard let path, let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            games = []
            index = LibraryIndex(games: [])
            return 0
        }
        let parsed = LibraryParser.parse(text)
        games = parsed
        index = LibraryIndex(games: parsed)
        lastModified = modificationDate()
        return index.count
    }

    /// Basename of the configured file, for display.
    var fileName: String? { path.map { ($0 as NSString).lastPathComponent } }

    /// Re-read only if the file changed since last read (called on each poll).
    func reloadIfChanged() {
        guard path != nil else { return }
        if modificationDate() != lastModified { reload() }
    }

    private func modificationDate() -> Date? {
        guard let path else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate]) as? Date
    }

    /// Ownership + version status for a DLPS entry.
    func status(codes: [String]?, name: String, dlpsVersions: [String]?) -> OwnershipStatus {
        guard !index.isEmpty else { return .unknown }
        var game: LibraryGame?
        if let codes {
            for code in codes {
                if let match = index.game(forCode: code) { game = match; break }
            }
        }
        if game == nil { game = index.game(forName: name) }
        guard let game else { return .notOwned }

        if let mine = game.version, let dlpsVersions {
            for version in dlpsVersions where VersionCompare.isNewer(version, than: mine) == true {
                return .updateAvailable(myVersion: mine)
            }
        }
        return .owned(myVersion: game.version)
    }
}
