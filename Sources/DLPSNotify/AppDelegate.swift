import AppKit
import ServiceManagement
import DLPSNotifyCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let store = GameStore()
    private let api = APIClient()

    private var timer: Timer?
    private var lastCheck: Date?
    private var lastError: String?
    private var isChecking = false
    private var recent: [RecentItem] = []

    private let defaults = UserDefaults.standard
    private let intervalKey = "checkIntervalMinutes"
    private let platformsKey = "selectedPlatforms"
    private let defaultIntervalMinutes = 30
    private let siteURL = "https://dlpsgame.com/daily-update-on-changes-to-game/"

    private var intervalMinutes: Int {
        let stored = defaults.integer(forKey: intervalKey)
        return stored > 0 ? stored : defaultIntervalMinutes
    }

    private var selectedPlatformKeys: Set<String> {
        if let stored = defaults.array(forKey: platformsKey) as? [String] {
            return Set(stored)
        }
        return Platforms.allKeys   // default: everything
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.reset()
        recent = RecentStore.load()
        setupStatusItem()
        rebuildMenu()

        if CommandLine.arguments.contains("--selftest")
            || ProcessInfo.processInfo.environment["DLPS_SELFTEST"] == "1" {
            runSelfTest()
            return
        }

        scheduleTimer()
        runCheck(reason: "launch")
    }

    // MARK: Status item & menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gamecontroller",
                                   accessibilityDescription: "DLPS Notify")
            button.image?.isTemplate = true
        }
    }

    private func statusText() -> String {
        var parts: [String] = []
        if let lastCheck {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            parts.append(L10n.t(.statusLastCheck, formatter.string(from: lastCheck)))
        } else {
            parts.append(L10n.t(.statusNotChecked))
        }
        if lastError != nil { parts.append(L10n.t(.statusError)) }
        return parts.joined(separator: " · ")
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        addDisabled("DLPS Notify", to: menu)
        addDisabled(statusText(), to: menu)
        menu.addItem(.separator())

        if recent.isEmpty {
            addDisabled(L10n.t(.noEntriesYet), to: menu)
        } else {
            let newGames = recent.filter { $0.isNew }
            let updates = recent.filter { !$0.isNew }
            addRecentGroup(L10n.t(.sectionNewGames), items: newGames, icon: "🎮", to: menu)
            if !newGames.isEmpty && !updates.isEmpty { menu.addItem(.separator()) }
            addRecentGroup(L10n.t(.sectionUpdates), items: updates, icon: "🔄", to: menu)
        }

        menu.addItem(.separator())

        let checkNow = NSMenuItem(title: isChecking ? L10n.t(.checking) : L10n.t(.checkNow),
                                  action: isChecking ? nil : #selector(checkNowAction),
                                  keyEquivalent: "r")
        checkNow.target = self
        menu.addItem(checkNow)

        menu.addItem(intervalMenuItem())
        menu.addItem(platformsMenuItem())
        menu.addItem(languageMenuItem())

        let login = NSMenuItem(title: L10n.t(.launchAtLogin),
                               action: #selector(toggleLoginAction), keyEquivalent: "")
        login.target = self
        login.state = loginEnabled() ? .on : .off
        menu.addItem(login)

        let openSite = NSMenuItem(title: L10n.t(.openSite),
                                  action: #selector(openSiteAction), keyEquivalent: "")
        openSite.target = self
        menu.addItem(openSite)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: L10n.t(.quit), action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func addDisabled(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addRecentGroup(_ title: String, items: [RecentItem], icon: String, to menu: NSMenu) {
        guard !items.isEmpty else { return }
        addDisabled(title, to: menu)
        for item in items.prefix(10) {
            var meta: [String] = []
            if let platform = item.platform { meta.append(platform) }
            if let when = RecentDate.display(item.modified) { meta.append(when) }
            let suffix = meta.isEmpty ? "" : " (\(meta.joined(separator: " · ")))"
            let menuItem = NSMenuItem(title: "\(icon) \(item.name)\(suffix)",
                                      action: #selector(openRecent(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item.link
            menu.addItem(menuItem)
        }
    }

    private func intervalMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t(.interval), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for minutes in [15, 30, 60] {
            let entry = NSMenuItem(title: L10n.t(.minutes, minutes),
                                   action: #selector(setIntervalAction(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = minutes
            entry.state = (minutes == intervalMinutes) ? .on : .off
            submenu.addItem(entry)
        }
        item.submenu = submenu
        return item
    }

    private func platformsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t(.platforms), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let selected = selectedPlatformKeys
        for platform in Platforms.all {
            let entry = NSMenuItem(title: platform.name,
                                   action: #selector(togglePlatformAction(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = platform.key
            entry.state = selected.contains(platform.key) ? .on : .off
            submenu.addItem(entry)
        }
        item.submenu = submenu
        return item
    }

    private func languageMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t(.language), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let current = L10n.preference
        let options: [(code: String, title: String)] = [
            ("system", L10n.t(.languageSystem)),
            ("en", "English"),
            ("de", "Deutsch"),
        ]
        for option in options {
            let entry = NSMenuItem(title: option.title,
                                   action: #selector(setLanguageAction(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = option.code
            entry.state = (option.code == current) ? .on : .off
            submenu.addItem(entry)
        }
        item.submenu = submenu
        return item
    }

    // MARK: Polling

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalMinutes * 60),
                                     repeats: true) { [weak self] _ in
            self?.runCheck(reason: "timer")
        }
    }

    private func runCheck(reason: String) {
        if isChecking { return }
        isChecking = true
        rebuildMenu()
        log("checking (\(reason)) …")

        Task { [weak self] in
            guard let self else { return }
            do {
                let firstRun = !self.store.isSeeded
                let fetched = firstRun
                    ? try await self.api.fetchLatest(perPage: 50)
                    : try await self.api.fetchChanges(modifiedAfter: self.store.state.lastModified)
                let result = ChangeDetector.detect(state: self.store.state,
                                                   fetched: fetched, seeding: firstRun)
                await MainActor.run {
                    self.applyResult(events: result.events, newState: result.state,
                                     firstRun: firstRun, fetchedCount: fetched.count)
                }
            } catch {
                await MainActor.run {
                    self.lastError = "\(error)"
                    self.lastCheck = Date()
                    self.isChecking = false
                    self.log("check failed: \(error)")
                    self.rebuildMenu()
                }
            }
        }
    }

    private func applyResult(events: [GameEvent], newState: DetectorState,
                             firstRun: Bool, fetchedCount: Int) {
        // Advance state for ALL changes (dedup), regardless of platform filter.
        store.update(newState)
        lastError = nil
        lastCheck = Date()
        isChecking = false

        if firstRun {
            log("seeded with \(fetchedCount) posts (no notifications)")
            Notifier.postActivation()
        } else {
            let selected = selectedPlatformKeys
            let visible = events.filter {
                Platforms.matches(categories: $0.post.categories, selectedKeys: selected)
            }
            log("\(events.count) change(s), \(visible.count) after platform filter")
            for event in visible {
                Notifier.post(event: event)
                recent.insert(RecentItem(event: event), at: 0)
            }
            if recent.count > 30 { recent.removeLast(recent.count - 30) }
            RecentStore.save(recent)
        }
        rebuildMenu()
    }

    // MARK: Actions

    @objc private func checkNowAction() { runCheck(reason: "manual") }

    @objc private func openRecent(_ sender: NSMenuItem) {
        if let link = sender.representedObject as? String, let url = URL(string: link) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func setIntervalAction(_ sender: NSMenuItem) {
        if let minutes = sender.representedObject as? Int {
            defaults.set(minutes, forKey: intervalKey)
            scheduleTimer()
            rebuildMenu()
        }
    }

    @objc private func togglePlatformAction(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        var selected = selectedPlatformKeys
        if selected.contains(key) { selected.remove(key) } else { selected.insert(key) }
        // Never allow an empty selection (would notify nothing) — fall back to all.
        if selected.isEmpty { selected = Platforms.allKeys }
        defaults.set(Array(selected), forKey: platformsKey)
        rebuildMenu()
    }

    @objc private func setLanguageAction(_ sender: NSMenuItem) {
        if let code = sender.representedObject as? String {
            defaults.set(code, forKey: L10n.preferenceKey)
            rebuildMenu()
        }
    }

    @objc private func openSiteAction() {
        if let url = URL(string: siteURL) { NSWorkspace.shared.open(url) }
    }

    @objc private func quitAction() { NSApplication.shared.terminate(nil) }

    // MARK: Launch-at-login

    private func loginEnabled() -> Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    @objc private func toggleLoginAction() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            log("login toggle failed: \(error)")
        }
        rebuildMenu()
    }

    // MARK: Self-test (automated verification path)

    private func runSelfTest() {
        log("SELFTEST start; notifier channel=\(ExternalNotifier.channelName)")
        Notifier.postTest()
        Task { [weak self] in
            guard let self else { return }
            do {
                let watermark = DLPSDate.string(from: Date().addingTimeInterval(-6 * 3600))
                let fetched = try await self.api.fetchChanges(modifiedAfter: watermark)
                let result = ChangeDetector.detect(state: DetectorState(), fetched: fetched)
                self.log("live fetch: \(fetched.count) posts -> \(result.events.count) events")
                for event in result.events.prefix(3) {
                    let platform = event.post.platforms.first?.name ?? "—"
                    self.log("notify \(event.isNew ? "NEW" : "UPD") [\(platform)]: \(event.post.name)")
                    Notifier.post(event: event)
                }
            } catch {
                self.log("SELFTEST fetch error: \(error)")
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.log("SELFTEST done")
            await MainActor.run { NSApplication.shared.terminate(nil) }
        }
    }

    private func log(_ message: String) { Log.write(message) }
}
