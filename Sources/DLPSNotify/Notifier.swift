import Foundation
import DLPSNotifyCore

/// App-facing notification API. Branding + localized wording live here; delivery
/// is done by `ExternalNotifier`. Every notification is titled "DLPS Notify" and
/// carries our own icon, so it reads as our app even though delivery goes through
/// a helper.
enum Notifier {
    private static let siteURL = "https://dlpsgame.com/daily-update-on-changes-to-game/"

    /// `detail` is an optional "what changed" summary for updates, e.g. "+ USA (@DUPLEX)".
    static func post(event: GameEvent, detail: String? = nil) {
        var parts = [event.isNew ? L10n.t(.notifNewGame) : L10n.t(.notifUpdate)]
        if let platform = event.post.platforms.first { parts.append(platform.name) }
        if let detail, !detail.isEmpty { parts.append(detail) }
        ExternalNotifier.post(title: "DLPS Notify",
                              subtitle: parts.joined(separator: " · "),
                              body: event.post.name,
                              openURL: event.post.url?.absoluteString)
    }

    static func postActivation() {
        ExternalNotifier.post(title: "DLPS Notify",
                              subtitle: L10n.t(.notifActive),
                              body: L10n.t(.notifActiveBody),
                              openURL: siteURL)
    }

    static func postTest() {
        ExternalNotifier.post(title: "DLPS Notify",
                              subtitle: L10n.t(.notifSelftest),
                              body: L10n.t(.notifSelftestBody),
                              openURL: siteURL)
    }
}
