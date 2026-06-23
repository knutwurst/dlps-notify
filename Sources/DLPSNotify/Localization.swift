import Foundation

/// Lightweight in-app localization. English is the default and the fallback for
/// any missing key. Add a language by adding one entry to `tables`.
enum L10n {
    enum Language: String, CaseIterable {
        case english = "en"
        case german = "de"
    }

    /// UserDefaults value: "system" | "en" | "de". Default is English.
    static let preferenceKey = "language"
    static let defaultPreference = "en"

    static var preference: String {
        UserDefaults.standard.string(forKey: preferenceKey) ?? defaultPreference
    }

    static var current: Language {
        switch preference {
        case "de": return .german
        case "en": return .english
        default:                                   // "system": follow the OS
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("de") ? .german : .english
        }
    }

    static func t(_ key: Key, _ args: CVarArg...) -> String {
        let table = tables[current] ?? englishTable
        let template = table[key] ?? englishTable[key] ?? key.rawValue
        return args.isEmpty ? template : String(format: template, arguments: args)
    }

    enum Key: String {
        case statusNotChecked, statusLastCheck, statusError, checking
        case checkNow, interval, minutes, platforms, language, languageSystem
        case launchAtLogin, openSite, quit
        case sectionNewGames, sectionUpdates, noEntriesYet
        case notifNewGame, notifUpdate, notifActive, notifActiveBody
        case notifSelftest, notifSelftestBody
    }

    private static let englishTable: [Key: String] = [
        .statusNotChecked: "Not checked yet",
        .statusLastCheck: "Last check %@",
        .statusError: "⚠️ Error",
        .checking: "Checking …",
        .checkNow: "Check now",
        .interval: "Interval",
        .minutes: "%d minutes",
        .platforms: "Platforms",
        .language: "Language",
        .languageSystem: "System",
        .launchAtLogin: "Launch at login",
        .openSite: "Open site",
        .quit: "Quit",
        .sectionNewGames: "New games",
        .sectionUpdates: "Updates",
        .noEntriesYet: "Nothing recorded yet",
        .notifNewGame: "🎮 New game",
        .notifUpdate: "🔄 Update",
        .notifActive: "Active",
        .notifActiveBody: "I'll let you know about new and updated games.",
        .notifSelftest: "Self-test",
        .notifSelftestBody: "Notifications are working ✅",
    ]

    private static let germanTable: [Key: String] = [
        .statusNotChecked: "Noch nicht geprüft",
        .statusLastCheck: "Letzter Check %@",
        .statusError: "⚠️ Fehler",
        .checking: "Prüfe …",
        .checkNow: "Jetzt prüfen",
        .interval: "Intervall",
        .minutes: "%d Minuten",
        .platforms: "Plattformen",
        .language: "Sprache",
        .languageSystem: "System",
        .launchAtLogin: "Bei Anmeldung starten",
        .openSite: "Seite öffnen",
        .quit: "Beenden",
        .sectionNewGames: "Neue Games",
        .sectionUpdates: "Updates",
        .noEntriesYet: "Noch keine neuen Games erfasst",
        .notifNewGame: "🎮 Neues Game",
        .notifUpdate: "🔄 Update",
        .notifActive: "Aktiv",
        .notifActiveBody: "Ich melde mich bei neuen Games und Updates.",
        .notifSelftest: "Selbsttest",
        .notifSelftestBody: "Benachrichtigungen funktionieren ✅",
    ]

    private static let tables: [Language: [Key: String]] = [
        .english: englishTable,
        .german: germanTable,
    ]
}
