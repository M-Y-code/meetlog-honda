import Foundation

final class RecordingSession: Identifiable, ObservableObject {
    let id: UUID
    let category: RecordingCategory
    var title: String
    let createdAt: Date
    var consentObtainedAt: Date?

    @Published var chunkSummaries: [ChunkSummary] = []
    @Published var rollingSummary = RollingSummary()
    @Published var finalSummary: FinalSummary?
    @Published var audioFileURL: URL?

    init(
        id: UUID = UUID(),
        category: RecordingCategory,
        title: String,
        createdAt: Date = Date(),
        consentObtainedAt: Date? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.createdAt = createdAt
        self.consentObtainedAt = consentObtainedAt
    }

    /// 作成から48時間で完全削除（延長不可）。
    var deletionDeadline: Date {
        createdAt.addingTimeInterval(48 * 3600)
    }

    var timeUntilDeletion: TimeInterval {
        max(0, deletionDeadline.timeIntervalSinceNow)
    }
}
