import SwiftUI

/// The history window content: a searchable, filterable table of all recorded
/// new games and updates, with clickable links.
struct HistoryView: View {
    @ObservedObject var model: HistoryModel
    @ObservedObject var library: LibraryModel
    var onLoadMore: () async -> Void = {}
    @State private var search = ""
    @State private var filter = 0   // 0 = all, 1 = new games, 2 = updates
    @State private var isLoading = false
    @State private var onlyMine = false

    private func ownership(_ entry: HistoryEntry) -> OwnershipStatus {
        library.status(codes: entry.codes, name: entry.name, dlpsVersions: entry.dlpsVersions)
    }

    private var filtered: [HistoryEntry] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return model.entries.filter { entry in
            let typeOK = filter == 0 || (filter == 1 && entry.isNew) || (filter == 2 && !entry.isNew)
            guard typeOK else { return false }
            if onlyMine {
                switch ownership(entry) {
                case .owned, .updateAvailable: break
                default: return false
                }
            }
            if query.isEmpty { return true }
            return entry.name.localizedCaseInsensitiveContains(query)
                || (entry.platform ?? "").localizedCaseInsensitiveContains(query)
                || (entry.detail ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    @ViewBuilder
    private func ownershipCell(_ entry: HistoryEntry) -> some View {
        switch ownership(entry) {
        case .unknown:
            Text("")
        case .notOwned:
            Text("–").foregroundColor(.secondary)
        case .owned(let version):
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                if let version { Text("v\(version)").font(.caption).foregroundColor(.secondary) }
            }
        case .updateAvailable(let version):
            HStack(spacing: 3) {
                Image(systemName: "arrow.up.circle.fill").foregroundColor(.orange)
                if let version { Text("v\(version)").font(.caption).foregroundColor(.secondary) }
            }
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

                if !library.index.isEmpty {
                    Toggle(L10n.t(.filterOwned), isOn: $onlyMine).toggleStyle(.checkbox)
                }

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
                VStack {
                    Spacer()
                    Text(L10n.t(.historyEmpty)).foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filtered) {
                    TableColumn("") { (entry: HistoryEntry) in
                        Text(entry.isNew ? "🎮" : "🔄")
                    }
                    .width(26)

                    TableColumn(L10n.t(.colPlatform)) { (entry: HistoryEntry) in
                        if let platform = entry.platform {
                            if let icon = PlatformStyle.iconImage(forName: platform) {
                                Image(nsImage: icon).resizable().scaledToFit().frame(height: 16)
                            } else if PlatformStyle.isKnown(platform) {
                                Text(platform)
                                    .font(.system(size: 10, weight: .heavy))
                                    .kerning(0.4)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(PlatformStyle.color(forName: platform), in: Capsule())
                            } else {
                                Text(platform).foregroundColor(.secondary)
                            }
                        } else {
                            Text("—").foregroundColor(.secondary)
                        }
                    }
                    .width(min: 52, ideal: 60, max: 84)

                    TableColumn(L10n.t(.colOwned)) { (entry: HistoryEntry) in
                        ownershipCell(entry)
                    }
                    .width(min: 44, ideal: 70, max: 110)

                    TableColumn(L10n.t(.colTitle)) { (entry: HistoryEntry) in
                        if let url = entry.url {
                            Link(entry.name, destination: url)
                        } else {
                            Text(entry.name)
                        }
                    }

                    TableColumn(L10n.t(.colWhen)) { (entry: HistoryEntry) in
                        Text(DateDisplay.full(entry.modified, recordedAt: entry.recordedAt))
                            .foregroundColor(.secondary)
                    }
                    .width(min: 108, ideal: 128, max: 150)

                    TableColumn(L10n.t(.colDetails)) { (entry: HistoryEntry) in
                        Text(entry.detail ?? "").foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(minWidth: 660, minHeight: 400)
    }
}
