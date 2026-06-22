import Foundation
import DLPSNotifyCore

/// App-facing notification API. Branding lives here; delivery is done by
/// `ExternalNotifier`. Every notification is titled "DLPS Notify" and carries our
/// own icon, so it reads as our app even though delivery goes through a helper.
enum Notifier {
    private static let siteURL = "https://dlpsgame.com/daily-update-on-changes-to-game/"

    static func post(event: GameEvent) {
        let kind = event.isNew ? "🎮 Neues Game" : "🔄 Update"
        let subtitle = event.post.platforms.first.map { "\(kind) · \($0.name)" } ?? kind
        ExternalNotifier.post(title: "DLPS Notify",
                              subtitle: subtitle,
                              body: event.post.name,
                              openURL: event.post.url?.absoluteString)
    }

    static func postActivation() {
        ExternalNotifier.post(title: "DLPS Notify",
                              subtitle: "Aktiv",
                              body: "Ich melde mich bei neuen Games und Updates.",
                              openURL: siteURL)
    }

    static func postTest() {
        ExternalNotifier.post(title: "DLPS Notify",
                              subtitle: "Selbsttest",
                              body: "Benachrichtigungen funktionieren ✅",
                              openURL: siteURL)
    }
}
