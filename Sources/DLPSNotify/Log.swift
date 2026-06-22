import Foundation

/// Minimal logger that writes to stderr *and* to a file, so log lines are
/// readable whether the app is run directly or launched via Launch Services
/// (`open`), where stderr would otherwise disappear into the unified log.
enum Log {
    static let fileURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DLPSNotify", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("dlps.log")
    }()

    /// Truncate the log at launch so each run is easy to read.
    static func reset() {
        try? Data().write(to: fileURL)
    }

    static func write(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        let data = Data(line.utf8)

        FileHandle.standardError.write(data)

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: fileURL)
        }
    }
}
