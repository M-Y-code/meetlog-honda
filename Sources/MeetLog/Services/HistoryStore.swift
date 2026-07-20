import Foundation
import Combine

/// 録音・要約データの一覧管理。
/// 永続化（ディスク保存）は未実装（PoC段階のためアプリ起動中のみ保持）。
/// 作成から48時間で完全削除する仕様（§04-1）はここで管理する。
final class HistoryStore: ObservableObject {
    @Published private(set) var sessions: [RecordingSession] = []

    func add(_ session: RecordingSession) {
        sessions.insert(session, at: 0)
    }

    func delete(_ session: RecordingSession) {
        sessions.removeAll { $0.id == session.id }
    }

    /// 作成から48時間経過したものを完全削除する（延長不可）。
    func purgeExpired() {
        let now = Date()
        sessions.removeAll { $0.deletionDeadline <= now }
    }
}
