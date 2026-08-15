import AppKit
import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers
import DLPSNotifyCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let store = GameStore()
    private let api = APIClient()

    private var timer: Timer?
    private var lastCheck: Date?
    private var lastError: String?
    private var isChecking = false
    private let history = HistoryModel()
    private let library = LibraryModel()
    private var historyWindow: NSWindow?
    private var currentMenu: NSMenu?

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

    private var onlyOwnedNotifications: Bool { defaults.bool(forKey: "onlyOwnedNotifications") }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--dump-langs") {
            FileHandle.standardOutput.write(Data(L10n.debugDump().utf8))
            exit(0)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--entries"),
           index + 1 < CommandLine.arguments.count,
           let id = Int(CommandLine.arguments[index + 1]) {
            Task {
                var out = ""
                do {
                    let html = try await api.fetchContent(postID: id)
                    let entries = UpdateDetails.entries(fromHTML: html)
                    out += "entries for \(id): \(entries)\n"
                    if !entries.isEmpty {
                        let summary = UpdateDetails.summarize(old: Array(entries.dropLast()), new: entries)
                        out += "demo summary (last entry as new): \(summary ?? "‹none›")\n"
                    }
                } catch {
                    out += "fetchContent error: \(error.localizedDescription)\n"
                }
                FileHandle.standardOutput.write(Data(out.utf8))
                exit(0)
            }
            return
        }
        if CommandLine.arguments.contains("--test-history-render") {
            // Render the history view offscreen (no visible window) as a crash smoke test.
            let view = NSHostingView(rootView: MainWindowView(history: history, library: library))
            view.frame = NSRect(x: 0, y: 0, width: 720, height: 460)
            view.layoutSubtreeIfNeeded()
            _ = view.fittingSize
            FileHandle.standardOutput.write(Data("history render ok: \(history.entries.count) entries\n".utf8))
            exit(0)
        }
        if CommandLine.arguments.contains("--backfill") {
            setupStatusItem()
            Task {
                let added = await backfillHistory()
                FileHandle.standardOutput.write(Data("backfill added \(added); history now \(history.entries.count)\n".utf8))
                exit(0)
            }
            return
        }
        if CommandLine.arguments.contains("--library-check") {
            var owned = 0, notOwned = 0, unknown = 0, updates = 0
            for entry in history.entries {
                switch library.status(codes: entry.codes, name: entry.name, dlpsVersions: entry.dlpsVersions) {
                case .unknown: unknown += 1
                case .notOwned: notOwned += 1
                case .owned: owned += 1
                case .updateAvailable: owned += 1; updates += 1
                }
            }
            let msg = "library: \(library.count) games | history \(history.entries.count): "
                + "owned \(owned) (version-updates \(updates)), not-owned \(notOwned), unknown \(unknown)\n"
            FileHandle.standardOutput.write(Data(msg.utf8))
            exit(0)
        }
        if CommandLine.arguments.contains("--show-history") {
            showHistoryAction()
            return
        }
        Log.reset()
        PlatformStyle.ensureIconsFolder()
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
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if isSecondary {
            showHistoryAction()   // right-click / control-click → straight to the history
        } else {
            showStatusMenu()
        }
    }

    private func showStatusMenu() {
        rebuildMenu()   // rebuild each time so recent entries and platform icons are fresh
        guard let menu = currentMenu else { return }
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        // Detach so the next click reaches our handler (needed to catch right-clicks).
        statusItem.menu = nil
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

        let entries = history.entries
        if entries.isEmpty {
            addDisabled(L10n.t(.noEntriesYet), to: menu)
        } else {
            let newGames = entries.filter { $0.isNew }
            let updates = entries.filter { !$0.isNew }
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

        let historyItem = NSMenuItem(title: L10n.t(.history) + " …",
                                     action: #selector(showHistoryAction), keyEquivalent: "l")
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(intervalMenuItem())
        menu.addItem(platformsMenuItem())
        menu.addItem(languageMenuItem())
        menu.addItem(libraryMenuItem())

        let login = NSMenuItem(title: L10n.t(.launchAtLogin),
                               action: #selector(toggleLoginAction), keyEquivalent: "")
        login.target = self
        login.state = loginEnabled() ? .on : .off
        menu.addItem(login)

        let openSite = NSMenuItem(title: L10n.t(.openSite),
                                  action: #selector(openSiteAction), keyEquivalent: "")
        openSite.target = self
        menu.addItem(openSite)

        let iconsItem = NSMenuItem(title: L10n.t(.platformIcons),
                                   action: #selector(openPlatformIconsFolder), keyEquivalent: "")
        iconsItem.target = self
        menu.addItem(iconsItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: L10n.t(.quit), action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        currentMenu = menu
    }

    private func addDisabled(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addRecentGroup(_ title: String, items: [HistoryEntry], icon: String, to menu: NSMenu) {
        guard !items.isEmpty else { return }
        addDisabled(title, to: menu)
        for item in items.prefix(10) {
            let when = RecentDate.display(item.modified).map { " (\($0))" } ?? ""
            let extra = item.detail.map { " — \($0)" } ?? ""
            let menuItem = NSMenuItem(title: "\(icon) \(item.name)\(when)\(extra)",
                                      action: #selector(openRecent(_:)), keyEquivalent: "")
            if let platform = item.platform, let badge = PlatformStyle.menuImage(forName: platform) {
                menuItem.image = badge
            }
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
        for option in L10n.menuOptions {
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

    private func libraryMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t(.library), action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let statusTitle = library.isConfigured
            ? (library.fileName ?? "?") + " — " + L10n.t(.libraryCount, library.count)
            : L10n.t(.libraryNone)
        let status = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        status.isEnabled = false
        submenu.addItem(status)

        let choose = NSMenuItem(title: L10n.t(.libraryChoose),
                                action: #selector(pickLibraryFile), keyEquivalent: "")
        choose.target = self
        submenu.addItem(choose)

        if library.isConfigured {
            let reload = NSMenuItem(title: L10n.t(.libraryReload),
                                    action: #selector(reloadLibrary), keyEquivalent: "")
            reload.target = self
            submenu.addItem(reload)
        }

        submenu.addItem(.separator())

        let onlyOwned = NSMenuItem(title: L10n.t(.onlyMyGames),
                                   action: #selector(toggleOnlyOwned), keyEquivalent: "")
        onlyOwned.target = self
        onlyOwned.state = onlyOwnedNotifications ? .on : .off
        submenu.addItem(onlyOwned)

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
        library.reloadIfChanged()
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
                let metas: [Int: EventMeta]
                if firstRun {
                    metas = [:]
                } else {
                    let selected = self.selectedPlatformKeys
                    let visible = result.events.filter {
                        Platforms.matches(categories: $0.post.categories, selectedKeys: selected)
                    }
                    metas = await self.computeDetails(for: visible)
                }
                await MainActor.run {
                    self.applyResult(events: result.events, newState: result.state,
                                     firstRun: firstRun, fetchedCount: fetched.count, metas: metas)
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
                             firstRun: Bool, fetchedCount: Int, metas: [Int: EventMeta]) {
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
            var visible = events.filter {
                Platforms.matches(categories: $0.post.categories, selectedKeys: selected)
            }
            // Record everything (platform-filtered) to the history, with codes/versions.
            let entries = visible.reversed().map { event -> HistoryEntry in
                let meta = metas[event.post.id]
                return HistoryEntry(event: event, detail: meta?.detail,
                                    codes: meta?.codes, dlpsVersions: meta?.versions)
            }
            history.add(entries)

            // Notifications: optionally only for games in the user's library.
            if onlyOwnedNotifications && !library.index.isEmpty {
                visible = visible.filter { event in
                    let meta = metas[event.post.id]
                    if case .notOwned = library.status(codes: meta?.codes, name: event.post.name,
                                                       dlpsVersions: meta?.versions) { return false }
                    return true
                }
            }
            log("\(events.count) change(s), \(visible.count) notified")
            for event in visible {
                Notifier.post(event: event, detail: metas[event.post.id]?.detail)
            }
        }
        rebuildMenu()
    }

    /// Per-event metadata gathered from the post content.
    private struct EventMeta {
        var detail: String?
        var codes: [String]
        var versions: [String]
    }

    /// For the given (already platform-filtered) events, fetch each post's content:
    /// the "what changed" summary (updates), plus TitleID codes and version strings
    /// for library matching. Bounded by `maxFetches`.
    private func computeDetails(for events: [GameEvent]) async -> [Int: EventMeta] {
        guard !events.isEmpty else { return [:] }
        var signatures = SignatureStore.load()
        var metas: [Int: EventMeta] = [:]
        let maxFetches = 12
        var fetches = 0
        for event in events {
            guard fetches < maxFetches else { break }
            fetches += 1
            guard let html = try? await api.fetchContent(postID: event.post.id) else { continue }
            let entries = UpdateDetails.entries(fromHTML: html)
            let key = String(event.post.id)
            let previous = signatures[key]
            signatures[key] = entries
            var detail: String?
            if !event.isNew, let previous,
               let summary = UpdateDetails.summarize(old: previous, new: entries) {
                detail = summary
            }
            metas[event.post.id] = EventMeta(detail: detail,
                                             codes: UpdateDetails.codes(fromHTML: html),
                                             versions: UpdateDetails.versionStrings(fromHTML: html))
        }
        SignatureStore.save(signatures)
        return metas
    }

    /// Backfill: fetch everything modified in the last `days` days and merge it into
    /// history (platform-filtered; no per-entry "what changed" — there is no earlier
    /// snapshot to diff a backfilled entry against). Returns how many were added.
    @discardableResult
    private func backfillHistory(days: Int = 7) async -> Int {
        let watermark = DLPSDate.string(from: Date().addingTimeInterval(-Double(days) * 86_400))
        guard let fetched = try? await api.fetchChanges(modifiedAfter: watermark) else { return 0 }
        let selected = selectedPlatformKeys
        let entries = fetched
            .filter { Platforms.matches(categories: $0.categories, selectedKeys: selected) }
            .map { HistoryEntry(event: ChangeDetector.classifyFirstSeen($0), detail: nil) }
        return await MainActor.run {
            let added = self.history.merge(entries)
            self.rebuildMenu()
            return added
        }
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

    @objc private func openPlatformIconsFolder() {
        PlatformStyle.ensureIconsFolder()
        PlatformStyle.clearIconCache()   // pick up any files added since launch
        NSWorkspace.shared.open(PlatformStyle.iconsFolderURL)
    }

    @objc private func pickLibraryFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text, .utf8PlainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        if historyWindow?.isVisible != true { NSApp.setActivationPolicy(.accessory) }
        if response == .OK, let url = panel.url {
            library.setPath(url.path)
            rebuildMenu()
        }
    }

    @objc private func reloadLibrary() {
        log("library reloaded: \(library.reload()) games")
        rebuildMenu()
    }

    @objc private func toggleOnlyOwned() {
        defaults.set(!onlyOwnedNotifications, forKey: "onlyOwnedNotifications")
        rebuildMenu()
    }

    @objc private func showHistoryAction() {
        if historyWindow == nil {
            let hosting = NSHostingController(rootView: MainWindowView(
                history: history, library: library,
                onLoadMore: { [weak self] in _ = await self?.backfillHistory() },
                onChooseLibrary: { [weak self] in self?.pickLibraryFile() }))
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 720, height: 460))
            window.isReleasedWhenClosed = false
            window.delegate = self
            historyWindow = window
        }
        historyWindow?.title = "DLPS Notify — " + L10n.t(.history)
        // Become a regular app while the window is open so it can take focus.
        NSApp.setActivationPolicy(.regular)
        historyWindow?.center()
        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Back to a menu-bar-only agent when the history window closes.
        NSApp.setActivationPolicy(.accessory)
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
