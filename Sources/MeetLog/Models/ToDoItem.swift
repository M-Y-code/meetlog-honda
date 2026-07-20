import Foundation

enum ToDoPriority: String, CaseIterable, Identifiable, Codable {
    case high = "高"
    case normal = "中"
    case low = "低"
    var id: String { rawValue }
}

struct ToDoItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var category: String
    var dueDate: Date
    var priority: ToDoPriority
    var relatedRecordingID: UUID?
    var isCompleted: Bool = false

    /// 期限切れになった時刻。nilなら未到来。
    var overdueAt: Date? {
        dueDate < Date() ? dueDate : nil
    }

    /// 期限超過後、24時間の猶予を経て完全削除される。
    var deletionDeadline: Date? {
        overdueAt?.addingTimeInterval(24 * 3600)
    }

    init(
        id: UUID = UUID(),
        title: String,
        category: String = "その他",
        dueDate: Date,
        priority: ToDoPriority = .normal,
        relatedRecordingID: UUID? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.dueDate = dueDate
        self.priority = priority
        self.relatedRecordingID = relatedRecordingID
        self.isCompleted = isCompleted
    }
}
