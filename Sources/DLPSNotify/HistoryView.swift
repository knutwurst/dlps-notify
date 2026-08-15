import SwiftUI
import DLPSNotifyCore

/// Platform indicator: user-supplied icon if present, else a colour-coded badge.
struct PlatformCell: View {
    let platform: String?
    var body: some View {
        if let platform {
            if let icon = PlatformStyle.iconImage(forName: platform) {
                Image(nsImage: icon).resizable().scaledToFit().frame(height: 16)
            } else if PlatformStyle.isKnown(platform) {
                Text(platform)
                    .font(.system(size: 10, weight: .heavy)).kerning(0.4)
                    .foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(PlatformStyle.color(forName: platform), in: Capsule())
            } else {
                Text(platform).foregroundColor(.secondary)
            }
        } else {
            Text("—").foregroundColor(.secondary)
        }
    }
}

/// The window: two tabs — the DLPS event log, and the user's own game library.
struct MainWindowView: View {
    @ObservedObject var history: HistoryModel
    @ObservedObject var library: LibraryModel
    var onLoadMore: () async -> Void = {}
    var onChooseLibrary: () -> Void = {}

    var body: some View {
        TabView {
            HistoryTab(model: history, onLoadMore: onLoadMore)
                .tabItem { Text(L10n.t(.history)) }
            LibraryTab(library: library, history: history, onChooseLibrary: onChooseLibrary)
                .tabItem { Text(L10n.t(.tabMyGames)) }
        }
        .padding(.top, 6)
        .frame(minWidth: 720, minHeight: 440)
    }
}

// MARK: - History tab (the raw DLPS event log)

struct HistoryTab: View {
    @ObservedObject var model: HistoryModel
    var onLoadMore: () async -> Void = {}
    @State private var search = ""
    @State private var filter = 0   // 0 = all, 1 = new games, 2 = updates
    @State private var isLoading = false

    private var filtered: [HistoryEntry] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return model.entries.filter { entry in
            let typeOK = filter == 0 || (filter == 1 && entry.isNew) || (filter == 2 && !entry.isNew)
            guard typeOK else { return false }
            if query.isEmpty { return true }
            return entry.name.localizedCaseInsensitiveContains(query)
                || (entry.platform ?? "").localizedCaseInsensitiveContains(query)
                || (entry.detail ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("", selection: $filter) {
                    Text(L10n.t(.filterAll)).tag(0)
                    Text(L10n.t(.sectionNewGames)).tag(1)
                    Text(L10n.t(.sectionUpdates)).tag(2)
                }
                .pickerStyle(.segmented)
                .fixedSize()

                TextField(L10n.t(.search), text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                Spacer()
                Text(L10n.t(.entryCount, filtered.count)).foregroundColor(.secondary)
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { isLoading = true; await onLoadMore(); isLoading = false }
                    } label: {
                        Label(L10n.t(.loadMore), systemImage: "arrow.down.circle")
                    }
                }
            }
            .padding(10)

            Divider()

            if filtered.isEmpty {
                centeredMessage(L10n.t(.historyEmpty))
            } else {
                Table(filtered) {
                    TableColumn("") { (e: HistoryEntry) in Text(e.isNew ? "🎮" : "🔄") }
                        .width(26)
                    TableColumn(L10n.t(.colPlatform)) { (e: HistoryEntry) in PlatformCell(platform: e.platform) }
                        .width(min: 52, ideal: 60, max: 84)
                    TableColumn(L10n.t(.colTitle)) { (e: HistoryEntry) in
                        if let url = e.url { Link(e.name, destination: url) } else { Text(e.name) }
                    }
                    TableColumn(L10n.t(.colWhen)) { (e: HistoryEntry) in
                        Text(DateDisplay.full(e.modified, recordedAt: e.recordedAt)).foregroundColor(.secondary)
                    }
                    .width(min: 108, ideal: 128, max: 150)
                    TableColumn(L10n.t(.colDetails)) { (e: HistoryEntry) in
                        Text(e.detail ?? "").foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Library tab (your games, deduped, with DLPS status)

struct LibraryRow: Identifiable {
    let id: String            // TitleID code
    let name: String
    let platform: String?
    let myVersion: String?
    let dlpsVersion: String?
    let lastSeen: String?     // display date of latest DLPS activity
    let link: String?
    let updateAvailable: Bool
}

struct LibraryTab: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var history: HistoryModel
    var onChooseLibrary: () -> Void = {}
    @State private var search = ""
    @State private var onlyUpdates = false

    private var rows: [LibraryRow] {
        // Latest DLPS entry per code and per normalized name (history is newest-first).
        var byCode: [String: HistoryEntry] = [:]
        var byName: [String: HistoryEntry] = [:]
        for entry in history.entries {
            if let codes = entry.codes {
                for code in codes where byCode[code] == nil { byCode[code] = entry }
            }
            let key = LibraryIndex.normalize(entry.name)
            if byName[key] == nil { byName[key] = entry }
        }

        let query = search.trimmingCharacters(in: .whitespaces)
        let built: [LibraryRow] = library.games.map { game in
            let match = byCode[game.code] ?? byName[LibraryIndex.normalize(game.name)]
            let dlpsVersion = match.flatMap(Self.bestDLPSVersion)
            let update: Bool
            if let mine = game.version, let dv = dlpsVersion {
                update = VersionCompare.isNewer(dv, than: mine) == true
            } else {
                update = false
            }
            return LibraryRow(
                id: game.code, name: game.name, platform: game.platform,
                myVersion: game.version, dlpsVersion: dlpsVersion,
                lastSeen: match.map { DateDisplay.full($0.modified, recordedAt: $0.recordedAt) },
                link: match?.link, updateAvailable: update)
        }

        return built
            .filter { row in
                if onlyUpdates && !row.updateAvailable { return false }
                if query.isEmpty { return true }
                return row.name.localizedCaseInsensitiveContains(query)
                    || (row.platform ?? "").localizedCaseInsensitiveContains(query)
            }
            .sorted { a, b in
                if a.updateAvailable != b.updateAvailable { return a.updateAvailable }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }

    static func bestDLPSVersion(_ entry: HistoryEntry) -> String? {
        var versions = entry.dlpsVersions ?? []
        if let detail = entry.detail { versions += UpdateDetails.versionStrings(fromHTML: detail) }
        return versions.max { VersionCompare.isNewer($1, than: $0) == true }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TextField(L10n.t(.search), text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Toggle(L10n.t(.onlyUpdates), isOn: $onlyUpdates).toggleStyle(.checkbox)
                Spacer()
                Text(L10n.t(.entryCount, rows.count)).foregroundColor(.secondary)
            }
            .padding(10)

            HStack(spacing: 6) {
                Text("\(L10n.t(.libraryFileLabel)):").foregroundColor(.secondary)
                Text(library.path ?? L10n.t(.libraryNone))
                    .foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                Button(L10n.t(.libraryChoose)) { onChooseLibrary() }.controlSize(.small)
                Spacer()
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            Divider()

            if library.games.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Text(L10n.t(.libraryNone)).foregroundColor(.secondary)
                    Button(L10n.t(.libraryChoose)) { onChooseLibrary() }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(rows) {
                    TableColumn(L10n.t(.colPlatform)) { (r: LibraryRow) in PlatformCell(platform: r.platform) }
                        .width(min: 52, ideal: 60, max: 84)
                    TableColumn(L10n.t(.colTitle)) { (r: LibraryRow) in
                        if let link = r.link, let url = URL(string: link) { Link(r.name, destination: url) }
                        else { Text(r.name) }
                    }
                    TableColumn(L10n.t(.colMyVersion)) { (r: LibraryRow) in
                        Text(r.myVersion.map { "v\($0)" } ?? "—").foregroundColor(.secondary)
                    }
                    .width(min: 90, ideal: 110, max: 140)
                    TableColumn(L10n.t(.colDlpsVersion)) { (r: LibraryRow) in
                        if let dv = r.dlpsVersion {
                            HStack(spacing: 3) {
                                if r.updateAvailable {
                                    Image(systemName: "arrow.up.circle.fill").foregroundColor(.orange)
                                }
                                Text("v\(dv)").foregroundColor(r.updateAvailable ? .primary : .secondary)
                            }
                        } else {
                            Text("—").foregroundColor(.secondary)
                        }
                    }
                    .width(min: 100, ideal: 120, max: 150)
                    TableColumn(L10n.t(.colLastSeen)) { (r: LibraryRow) in
                        Text(r.lastSeen ?? "—").foregroundColor(.secondary)
                    }
                    .width(min: 108, ideal: 128, max: 150)
                }
            }
        }
    }
}

private func centeredMessage(_ text: String) -> some View {
    VStack {
        Spacer()
        Text(text).foregroundColor(.secondary)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
