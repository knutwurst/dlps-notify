import Foundation

/// Lightweight in-app localization. English is the default and the fallback for
/// any missing key. Add a language by adding a case to `Language`, its native
/// name, and a table below.
enum L10n {
    enum Language: String, CaseIterable {
        case english = "en"
        case german = "de"
        case french = "fr"
        case spanish = "es"
        case italian = "it"
        case portuguese = "pt"
        case dutch = "nl"
        case polish = "pl"
        case russian = "ru"
        case turkish = "tr"
        case japanese = "ja"
        case chinese = "zh-Hans"
        case korean = "ko"

        var nativeName: String {
            switch self {
            case .english: return "English"
            case .german: return "Deutsch"
            case .french: return "Français"
            case .spanish: return "Español"
            case .italian: return "Italiano"
            case .portuguese: return "Português"
            case .dutch: return "Nederlands"
            case .polish: return "Polski"
            case .russian: return "Русский"
            case .turkish: return "Türkçe"
            case .japanese: return "日本語"
            case .chinese: return "简体中文"
            case .korean: return "한국어"
            }
        }

        /// Base code used to match the system language (e.g. "zh-Hans" → "zh").
        var matchPrefix: String {
            rawValue.hasPrefix("zh") ? "zh" : rawValue
        }
    }

    /// UserDefaults value: "system" or a language code. Default is English.
    static let preferenceKey = "language"
    static let defaultPreference = "en"

    static var preference: String {
        UserDefaults.standard.string(forKey: preferenceKey) ?? defaultPreference
    }

    static var current: Language {
        if preference == "system" {
            let base = (Locale.preferredLanguages.first ?? "en").lowercased()
            return Language.allCases.first { base.hasPrefix($0.matchPrefix) } ?? .english
        }
        return Language(rawValue: preference) ?? .english
    }

    /// Options for the language submenu: System + every language by native name.
    static var menuOptions: [(code: String, title: String)] {
        [("system", t(.languageSystem))] + Language.allCases.map { ($0.rawValue, $0.nativeName) }
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

    /// Used by `--dump-langs` to verify every table renders.
    static func debugDump() -> String {
        var out = "languages: \(Language.allCases.count)\n"
        for lang in Language.allCases {
            let table = tables[lang] ?? englishTable
            func value(_ key: Key) -> String { table[key] ?? "‹missing›" }
            out += "[\(lang.rawValue)] \(lang.nativeName): "
                + "\(value(.checkNow)) | \(value(.notifNewGame)) | \(value(.notifUpdate)) | "
                + "\(value(.platforms)) | \(value(.quit)) | \(value(.notifSelftestBody))\n"
        }
        return out
    }

    private static let englishTable: [Key: String] = [
        .statusNotChecked: "Not checked yet", .statusLastCheck: "Last check %@",
        .statusError: "⚠️ Error", .checking: "Checking …",
        .checkNow: "Check now", .interval: "Interval", .minutes: "%d minutes",
        .platforms: "Platforms", .language: "Language", .languageSystem: "System",
        .launchAtLogin: "Launch at login", .openSite: "Open site", .quit: "Quit",
        .sectionNewGames: "New games", .sectionUpdates: "Updates",
        .noEntriesYet: "Nothing recorded yet",
        .notifNewGame: "🎮 New game", .notifUpdate: "🔄 Update",
        .notifActive: "Active", .notifActiveBody: "I'll let you know about new and updated games.",
        .notifSelftest: "Self-test", .notifSelftestBody: "Notifications are working ✅",
    ]

    private static let germanTable: [Key: String] = [
        .statusNotChecked: "Noch nicht geprüft", .statusLastCheck: "Letzter Check %@",
        .statusError: "⚠️ Fehler", .checking: "Prüfe …",
        .checkNow: "Jetzt prüfen", .interval: "Intervall", .minutes: "%d Minuten",
        .platforms: "Plattformen", .language: "Sprache", .languageSystem: "System",
        .launchAtLogin: "Bei Anmeldung starten", .openSite: "Seite öffnen", .quit: "Beenden",
        .sectionNewGames: "Neue Games", .sectionUpdates: "Updates",
        .noEntriesYet: "Noch keine neuen Games erfasst",
        .notifNewGame: "🎮 Neues Game", .notifUpdate: "🔄 Update",
        .notifActive: "Aktiv", .notifActiveBody: "Ich melde mich bei neuen Games und Updates.",
        .notifSelftest: "Selbsttest", .notifSelftestBody: "Benachrichtigungen funktionieren ✅",
    ]

    private static let frenchTable: [Key: String] = [
        .statusNotChecked: "Pas encore vérifié", .statusLastCheck: "Dernière vérification %@",
        .statusError: "⚠️ Erreur", .checking: "Vérification …",
        .checkNow: "Vérifier maintenant", .interval: "Intervalle", .minutes: "%d minutes",
        .platforms: "Plateformes", .language: "Langue", .languageSystem: "Système",
        .launchAtLogin: "Lancer à la connexion", .openSite: "Ouvrir le site", .quit: "Quitter",
        .sectionNewGames: "Nouveaux jeux", .sectionUpdates: "Mises à jour",
        .noEntriesYet: "Rien pour l'instant",
        .notifNewGame: "🎮 Nouveau jeu", .notifUpdate: "🔄 Mise à jour",
        .notifActive: "Actif", .notifActiveBody: "Je vous préviens des jeux nouveaux et mis à jour.",
        .notifSelftest: "Auto-test", .notifSelftestBody: "Les notifications fonctionnent ✅",
    ]

    private static let spanishTable: [Key: String] = [
        .statusNotChecked: "Sin comprobar aún", .statusLastCheck: "Última comprobación %@",
        .statusError: "⚠️ Error", .checking: "Comprobando …",
        .checkNow: "Comprobar ahora", .interval: "Intervalo", .minutes: "%d minutos",
        .platforms: "Plataformas", .language: "Idioma", .languageSystem: "Sistema",
        .launchAtLogin: "Abrir al iniciar sesión", .openSite: "Abrir el sitio", .quit: "Salir",
        .sectionNewGames: "Nuevos juegos", .sectionUpdates: "Actualizaciones",
        .noEntriesYet: "Nada registrado todavía",
        .notifNewGame: "🎮 Nuevo juego", .notifUpdate: "🔄 Actualización",
        .notifActive: "Activo", .notifActiveBody: "Te avisaré de juegos nuevos y actualizados.",
        .notifSelftest: "Autoprueba", .notifSelftestBody: "Las notificaciones funcionan ✅",
    ]

    private static let italianTable: [Key: String] = [
        .statusNotChecked: "Non ancora controllato", .statusLastCheck: "Ultimo controllo %@",
        .statusError: "⚠️ Errore", .checking: "Controllo …",
        .checkNow: "Controlla ora", .interval: "Intervallo", .minutes: "%d minuti",
        .platforms: "Piattaforme", .language: "Lingua", .languageSystem: "Sistema",
        .launchAtLogin: "Avvia all'accesso", .openSite: "Apri il sito", .quit: "Esci",
        .sectionNewGames: "Nuovi giochi", .sectionUpdates: "Aggiornamenti",
        .noEntriesYet: "Ancora niente",
        .notifNewGame: "🎮 Nuovo gioco", .notifUpdate: "🔄 Aggiornamento",
        .notifActive: "Attivo", .notifActiveBody: "Ti avviso quando ci sono giochi nuovi o aggiornati.",
        .notifSelftest: "Autotest", .notifSelftestBody: "Le notifiche funzionano ✅",
    ]

    private static let portugueseTable: [Key: String] = [
        .statusNotChecked: "Ainda não verificado", .statusLastCheck: "Última verificação %@",
        .statusError: "⚠️ Erro", .checking: "Verificando …",
        .checkNow: "Verificar agora", .interval: "Intervalo", .minutes: "%d minutos",
        .platforms: "Plataformas", .language: "Idioma", .languageSystem: "Sistema",
        .launchAtLogin: "Abrir ao iniciar sessão", .openSite: "Abrir o site", .quit: "Sair",
        .sectionNewGames: "Novos jogos", .sectionUpdates: "Atualizações",
        .noEntriesYet: "Nada registrado ainda",
        .notifNewGame: "🎮 Novo jogo", .notifUpdate: "🔄 Atualização",
        .notifActive: "Ativo", .notifActiveBody: "Eu aviso sobre jogos novos e atualizados.",
        .notifSelftest: "Autoteste", .notifSelftestBody: "As notificações estão funcionando ✅",
    ]

    private static let dutchTable: [Key: String] = [
        .statusNotChecked: "Nog niet gecontroleerd", .statusLastCheck: "Laatste controle %@",
        .statusError: "⚠️ Fout", .checking: "Controleren …",
        .checkNow: "Nu controleren", .interval: "Interval", .minutes: "%d minuten",
        .platforms: "Platforms", .language: "Taal", .languageSystem: "Systeem",
        .launchAtLogin: "Starten bij inloggen", .openSite: "Site openen", .quit: "Afsluiten",
        .sectionNewGames: "Nieuwe games", .sectionUpdates: "Updates",
        .noEntriesYet: "Nog niets vastgelegd",
        .notifNewGame: "🎮 Nieuwe game", .notifUpdate: "🔄 Update",
        .notifActive: "Actief", .notifActiveBody: "Ik laat je weten over nieuwe en bijgewerkte games.",
        .notifSelftest: "Zelftest", .notifSelftestBody: "Meldingen werken ✅",
    ]

    private static let polishTable: [Key: String] = [
        .statusNotChecked: "Jeszcze nie sprawdzono", .statusLastCheck: "Ostatnie sprawdzenie %@",
        .statusError: "⚠️ Błąd", .checking: "Sprawdzanie …",
        .checkNow: "Sprawdź teraz", .interval: "Interwał", .minutes: "%d minut",
        .platforms: "Platformy", .language: "Język", .languageSystem: "Systemowy",
        .launchAtLogin: "Uruchom przy logowaniu", .openSite: "Otwórz stronę", .quit: "Zakończ",
        .sectionNewGames: "Nowe gry", .sectionUpdates: "Aktualizacje",
        .noEntriesYet: "Jeszcze nic nie zarejestrowano",
        .notifNewGame: "🎮 Nowa gra", .notifUpdate: "🔄 Aktualizacja",
        .notifActive: "Aktywne", .notifActiveBody: "Powiadomię Cię o nowych i zaktualizowanych grach.",
        .notifSelftest: "Autotest", .notifSelftestBody: "Powiadomienia działają ✅",
    ]

    private static let russianTable: [Key: String] = [
        .statusNotChecked: "Ещё не проверялось", .statusLastCheck: "Последняя проверка %@",
        .statusError: "⚠️ Ошибка", .checking: "Проверка …",
        .checkNow: "Проверить сейчас", .interval: "Интервал", .minutes: "%d минут",
        .platforms: "Платформы", .language: "Язык", .languageSystem: "Системный",
        .launchAtLogin: "Запускать при входе", .openSite: "Открыть сайт", .quit: "Выйти",
        .sectionNewGames: "Новые игры", .sectionUpdates: "Обновления",
        .noEntriesYet: "Пока ничего нет",
        .notifNewGame: "🎮 Новая игра", .notifUpdate: "🔄 Обновление",
        .notifActive: "Активно", .notifActiveBody: "Сообщу о новых и обновлённых играх.",
        .notifSelftest: "Самопроверка", .notifSelftestBody: "Уведомления работают ✅",
    ]

    private static let turkishTable: [Key: String] = [
        .statusNotChecked: "Henüz kontrol edilmedi", .statusLastCheck: "Son kontrol %@",
        .statusError: "⚠️ Hata", .checking: "Kontrol ediliyor …",
        .checkNow: "Şimdi kontrol et", .interval: "Aralık", .minutes: "%d dakika",
        .platforms: "Platformlar", .language: "Dil", .languageSystem: "Sistem",
        .launchAtLogin: "Girişte başlat", .openSite: "Siteyi aç", .quit: "Çık",
        .sectionNewGames: "Yeni oyunlar", .sectionUpdates: "Güncellemeler",
        .noEntriesYet: "Henüz kayıt yok",
        .notifNewGame: "🎮 Yeni oyun", .notifUpdate: "🔄 Güncelleme",
        .notifActive: "Etkin", .notifActiveBody: "Yeni ve güncellenen oyunları bildiririm.",
        .notifSelftest: "Otomatik test", .notifSelftestBody: "Bildirimler çalışıyor ✅",
    ]

    private static let japaneseTable: [Key: String] = [
        .statusNotChecked: "未確認", .statusLastCheck: "最終確認 %@",
        .statusError: "⚠️ エラー", .checking: "確認中 …",
        .checkNow: "今すぐ確認", .interval: "確認間隔", .minutes: "%d分",
        .platforms: "プラットフォーム", .language: "言語", .languageSystem: "システム",
        .launchAtLogin: "ログイン時に起動", .openSite: "サイトを開く", .quit: "終了",
        .sectionNewGames: "新しいゲーム", .sectionUpdates: "アップデート",
        .noEntriesYet: "まだ何もありません",
        .notifNewGame: "🎮 新しいゲーム", .notifUpdate: "🔄 アップデート",
        .notifActive: "起動中", .notifActiveBody: "新しいゲームや更新をお知らせします。",
        .notifSelftest: "セルフテスト", .notifSelftestBody: "通知は正常に動作しています ✅",
    ]

    private static let chineseTable: [Key: String] = [
        .statusNotChecked: "尚未检查", .statusLastCheck: "上次检查 %@",
        .statusError: "⚠️ 错误", .checking: "正在检查 …",
        .checkNow: "立即检查", .interval: "检查间隔", .minutes: "%d 分钟",
        .platforms: "平台", .language: "语言", .languageSystem: "系统",
        .launchAtLogin: "登录时启动", .openSite: "打开网站", .quit: "退出",
        .sectionNewGames: "新游戏", .sectionUpdates: "更新",
        .noEntriesYet: "暂无记录",
        .notifNewGame: "🎮 新游戏", .notifUpdate: "🔄 更新",
        .notifActive: "已启用", .notifActiveBody: "有新游戏或更新时我会通知你。",
        .notifSelftest: "自检", .notifSelftestBody: "通知正常工作 ✅",
    ]

    private static let koreanTable: [Key: String] = [
        .statusNotChecked: "아직 확인 안 함", .statusLastCheck: "마지막 확인 %@",
        .statusError: "⚠️ 오류", .checking: "확인 중 …",
        .checkNow: "지금 확인", .interval: "간격", .minutes: "%d분",
        .platforms: "플랫폼", .language: "언어", .languageSystem: "시스템",
        .launchAtLogin: "로그인 시 실행", .openSite: "사이트 열기", .quit: "종료",
        .sectionNewGames: "새 게임", .sectionUpdates: "업데이트",
        .noEntriesYet: "아직 기록 없음",
        .notifNewGame: "🎮 새 게임", .notifUpdate: "🔄 업데이트",
        .notifActive: "실행 중", .notifActiveBody: "새 게임과 업데이트를 알려드릴게요.",
        .notifSelftest: "자체 테스트", .notifSelftestBody: "알림이 작동합니다 ✅",
    ]

    private static let tables: [Language: [Key: String]] = [
        .english: englishTable, .german: germanTable, .french: frenchTable,
        .spanish: spanishTable, .italian: italianTable, .portuguese: portugueseTable,
        .dutch: dutchTable, .polish: polishTable, .russian: russianTable,
        .turkish: turkishTable, .japanese: japaneseTable, .chinese: chineseTable,
        .korean: koreanTable,
    ]
}
