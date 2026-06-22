import Foundation

/// Delivers notifications via `terminal-notifier`, which (unlike an ad-hoc-signed
/// app's own UNUserNotificationCenter / NSUserNotification) reliably displays on
/// macOS. We brand it: title "DLPS Notify", our own app icon via `-appIcon`, and
/// `-open` to launch the game page on click. No `-sender` (that hangs on macOS 26
/// and refuses ad-hoc bundles); the small sender label therefore reads
/// "terminal-notifier", but the icon, title and content are all DLPS Notify.
enum ExternalNotifier {
    /// terminal-notifier location: the copy bundled into the app first (so the
    /// release is self-contained), then Homebrew, then PATH.
    static let terminalNotifierPath: String? = {
        let fm = FileManager.default
        if let resources = Bundle.main.resourcePath {
            let bundled = resources + "/terminal-notifier.app/Contents/MacOS/terminal-notifier"
            if fm.isExecutableFile(atPath: bundled) { return bundled }
        }
        for path in ["/opt/homebrew/bin/terminal-notifier", "/usr/local/bin/terminal-notifier"] {
            if fm.isExecutableFile(atPath: path) { return path }
        }
        return which("terminal-notifier")
    }()

    static var channelName: String {
        terminalNotifierPath != nil ? "terminal-notifier" : "osascript"
    }

    /// Path to the bundled icon used for `-appIcon`, if present.
    static var appIconPath: String? {
        guard let resources = Bundle.main.resourcePath else { return nil }
        let path = resources + "/appicon.png"
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    static func post(title: String, subtitle: String?, body: String, openURL: String?) {
        if let tool = terminalNotifierPath {
            var args = ["-title", title, "-message", body, "-sound", "default"]
            if let subtitle, !subtitle.isEmpty { args += ["-subtitle", subtitle] }
            if let openURL, !openURL.isEmpty { args += ["-open", openURL] }
            if let icon = appIconPath { args += ["-appIcon", icon] }
            launch(tool, args)
        } else {
            let script = "display notification \"\(escape(body))\" with title \"\(escape(title))\""
                + (subtitle.map { " subtitle \"\(escape($0))\"" } ?? "")
            launch("/usr/bin/osascript", ["-e", script])
        }
    }

    // MARK: - Process helpers

    /// Fire-and-forget: never block the caller (the main thread). terminal-notifier
    /// without `-sender` exits on its own, so no process is leaked.
    private static func launch(_ launchPath: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            Log.write("external notifier failed (\(launchPath)): \(error)")
        }
    }

    private static func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func which(_ tool: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", tool]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        } catch {}
        return nil
    }
}
