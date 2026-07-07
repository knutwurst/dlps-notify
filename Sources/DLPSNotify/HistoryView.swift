import SwiftUI

/// The history window content: a searchable, filterable table of all recorded
/// new games and updates, with clickable links.
struct HistoryView: View {
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
                        Text(entry.platform ?? "—")
                    }
                    .width(min: 48, ideal: 56, max: 80)

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
