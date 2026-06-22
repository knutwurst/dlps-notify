import Foundation

/// Loads and persists `DetectorState` as JSON under
/// `~/Library/Application Support/DLPSNotify/state.json`.
public final class GameStore {
    public let fileURL: URL
    public private(set) var state: DetectorState

    public init(fileURL: URL? = nil) {
        let url = fileURL ?? GameStore.defaultFileURL()
        self.fileURL = url
        self.state = GameStore.load(from: url) ?? DetectorState()
    }

    /// False on a genuine first run (nothing recorded yet).
    public var isSeeded: Bool { !state.lastModified.isEmpty }

    public func update(_ newState: DetectorState) {
        state = newState
        save()
    }

    @discardableResult
    public func save() -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(state).write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public static func load(from url: URL) -> DetectorState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DetectorState.self, from: data)
    }

    public static func defaultFileURL() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("DLPSNotify", isDirectory: true)
            .appendingPathComponent("state.json")
    }
}
