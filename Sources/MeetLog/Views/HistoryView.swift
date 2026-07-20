import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var searchText = ""
    @State private var purgeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var filteredSessions: [RecordingSession] {
        guard !searchText.isEmpty else { return historyStore.sessions }
        return historyStore.sessions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSessions) { session in
                    HistoryRow(session: session)
                }
                .onDelete { offsets in
                    for index in offsets {
                        historyStore.delete(filteredSessions[index])
                    }
                }
            }
            .overlay {
                if historyStore.sessions.isEmpty {
                    ContentUnavailableView(
                        "履歴はありません",
                        systemImage: "clock",
                        description: Text("録音を完了すると、ここに一覧表示されます（48時間で自動削除）")
                    )
                }
            }
            .searchable(text: $searchText, prompt: "カテゴリ・タイトルで検索")
            .navigationTitle("履歴")
            .onReceive(purgeTimer) { _ in historyStore.purgeExpired() }
            .onAppear { historyStore.purgeExpired() }
        }
    }
}

private struct HistoryRow: View {
    let session: RecordingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.title).font(.headline)
                Spacer()
                Text(session.category.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
            }
            if let final = session.finalSummary {
                Text(final.overview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text("削除まで残り\(hoursRemaining)時間")
                .font(.caption2)
                .foregroundStyle(.red)
        }
        .padding(.vertical, 4)
    }

    private var hoursRemaining: Int {
        max(0, Int(session.timeUntilDeletion / 3600))
    }
}
