import FoundationModels

enum SummarizerAvailability: Equatable {
    case available
    case unavailable(reason: String)
}

@Generable
struct GeneratedChunkSummary {
    @Guide(description: "この区間の発言内容を2〜4件の簡潔な箇条書きにする")
    let bullets: [String]

    @Guide(description: "依頼・宿題・期限に関する発言があればToDo候補として抜き出す。無ければ空配列")
    let todoCandidates: [String]
}

@Generable
struct GeneratedRollingSummary {
    @Guide(description: "商談全体の概要。3〜5行程度")
    let overview: String

    @Guide(description: "相手の要望・懸念点")
    let requestsAndConcerns: String

    @Guide(description: "決定事項・保留事項")
    let decisionsAndPending: String
}

/// Foundation Models framework（Apple Intelligence 内蔵オンデバイスLLM）を用いた
/// 3階層要約（区間要約 → 累積要約 → 最終要約）の実装。
///
/// NOTE: Foundation Models framework は比較的新しいAPIのため、正確なシグネチャは
/// 導入時のXcode/iOS SDKのバージョンに合わせて確認・調整すること
/// （CLAUDE.md「実装時に検証すべき点」参照）。
final class SummarizerService {

    func checkAvailability() -> SummarizerAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(reason: String(describing: reason))
        @unknown default:
            return .unavailable(reason: "不明な理由")
        }
    }

    /// ①区間要約：直近チャンクの文字起こしのみを要約する（低コスト・低遅延）
    func summarizeChunk(transcript: String, previousConclusion: String?) async throws -> GeneratedChunkSummary {
        let session = LanguageModelSession(
            instructions: "あなたは日本語ビジネス商談の書記です。与えられた発言内容から要点とToDo候補を抽出してください。"
        )
        let prompt = """
        直前までの要点: \(previousConclusion ?? "なし")

        今回の区間の発言内容:
        \(transcript)
        """
        let response = try await session.respond(to: prompt, generating: GeneratedChunkSummary.self)
        return response.content
    }

    /// ②累積要約：直前の累積要約 + 未反映の区間要約群をリファインして更新する（重複排除・矛盾は新しい発言を優先）
    func refineRollingSummary(previous: RollingSummary, newChunks: [ChunkSummary]) async throws -> RollingSummary {
        let session = LanguageModelSession(
            instructions: "あなたは商談要約を随時更新する書記です。冗長にならないよう常に現時点の全体像を簡潔にまとめ直してください。"
        )
        let newBullets = newChunks
            .flatMap { $0.bullets }
            .map { "・\($0)" }
            .joined(separator: "\n")

        let prompt = """
        これまでの累積要約:
        概要: \(previous.overview)
        要望・懸念点: \(previous.requestsAndConcerns)
        決定事項・保留事項: \(previous.decisionsAndPending)

        新しく追加された区間要約:
        \(newBullets)

        重複を排除し、矛盾があれば新しい発言を優先して、累積要約を300〜400字程度に更新してください。
        """
        let response = try await session.respond(to: prompt, generating: GeneratedRollingSummary.self)
        let generated = response.content

        var updated = RollingSummary()
        updated.overview = generated.overview
        updated.requestsAndConcerns = generated.requestsAndConcerns
        updated.decisionsAndPending = generated.decisionsAndPending
        updated.lastRefinedAt = Date()
        updated.mergedChunkCount = previous.mergedChunkCount + newChunks.count
        return updated
    }

    /// ③最終要約：録音停止時に、累積要約 + 未反映の直近チャンクを1回リファインして仕上げる
    func finalizeSummary(rolling: RollingSummary, trailingChunks: [ChunkSummary], allTodoCandidates: [String]) async throws -> FinalSummary {
        let refined = try await refineRollingSummary(previous: rolling, newChunks: trailingChunks)
        let dedupedTodos = Array(Set(allTodoCandidates))
        return FinalSummary(
            overview: refined.overview,
            requestsAndConcerns: refined.requestsAndConcerns,
            decisionsAndPending: refined.decisionsAndPending,
            todoCandidates: dedupedTodos,
            generatedAt: Date()
        )
    }
}
