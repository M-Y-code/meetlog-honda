import Foundation
import Combine

/// ToDoのライフサイクル管理（仕様書 §04-2 / §10）。
/// 録音・要約データ（48時間固定削除）とは独立したライフサイクルで、
/// 完了は即削除、期限超過は24時間の猶予を経て自動削除される。
final class ToDoStore: ObservableObject {
    @Published private(set) var items: [ToDoItem] = []

    func add(_ item: ToDoItem) {
        items.append(item)
    }

    /// 完了チェックを入れたら即座に削除する。
    func complete(_ item: ToDoItem) {
        items.removeAll { $0.id == item.id }
    }

    func delete(_ item: ToDoItem) {
        items.removeAll { $0.id == item.id }
    }

    /// 猶予期間中に期限を再設定し、猶予表示を解除する。
    func extend(_ item: ToDoItem, to newDueDate: Date) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].dueDate = newDueDate
    }

    /// 猶予期間（期限超過から24時間）が終了したものを完全削除する。
    func purgeExpired() {
        let now = Date()
        items.removeAll { item in
            guard let deletionDeadline = item.deletionDeadline else { return false }
            return deletionDeadline <= now
        }
    }

    var sortedByDueDate: [ToDoItem] {
        items.sorted { $0.dueDate < $1.dueDate }
    }
}
