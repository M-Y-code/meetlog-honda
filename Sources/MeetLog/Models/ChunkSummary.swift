import Foundation

/// ①区間要約：チャンク単位の軽量な要約ログ
struct ChunkSummary: Identifiable, Codable {
    let id: UUID
    let chunkIndex: Int
    let startedAt: Date
    let endedAt: Date
    let transcript: String
    var bullets: [String]
    var todoCandidates: [String]
    var isLowConfidence: Bool

    init(
        id: UUID = UUID(),
        chunkIndex: Int,
        startedAt: Date,
        endedAt: Date,
        transcript: String,
        bullets: [String] = [],
        todoCandidates: [String] = [],
        isLowConfidence: Bool = false
    ) {
        self.id = id
        self.chunkIndex = chunkIndex
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.transcript = transcript
        self.bullets = bullets
        self.todoCandidates = todoCandidates
        self.isLowConfidence = isLowConfidence
    }
}

/// ②累積要約：商談中に確認するメイン表示
struct RollingSummary: Codable {
    var overview: String = ""
    var requestsAndConcerns: String = ""
    var decisionsAndPending: String = ""
    var lastRefinedAt: Date?
    var mergedChunkCount: Int = 0

    var isStale: Bool {
        guard let lastRefinedAt else { return true }
        return Date().timeIntervalSince(lastRefinedAt) > 120 // 2分
    }
}

/// ③最終要約：録音停止時に仕上げる構造化サマリー
struct FinalSummary: Codable {
    var overview: String
    var requestsAndConcerns: String
    var decisionsAndPending: String
    var todoCandidates: [String]
    var generatedAt: Date
}
