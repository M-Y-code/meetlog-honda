import Foundation
import Combine

/// 録音・文字起こし・要約(①区間要約→②累積要約→③最終要約)を束ねるコーディネーター。
/// 仕様書 §09（リアルタイム要約ロジック）のトリガー条件をそのまま実装している。
@MainActor
final class RecordingCoordinator: ObservableObject {
    @Published private(set) var session: RecordingSession
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?
    @Published private(set) var isFinalizing = false

    private let audioRecorder = AudioRecorderService()
    private let transcriber = TranscriptionService()
    private let summarizer = SummarizerService()

    private var pendingChunksSinceRefine: [ChunkSummary] = []
    private var lastRefineAt = Date()
    private let refineChunkThreshold = 3
    private let refineTimeThreshold: TimeInterval = 10 * 60

    // sessionはそれ自体がObservableObject（class）のため、@Publishedは参照の差し替えにしか
    // 反応しない。内部のchunkSummaries等の変更をcoordinator側の変更通知にも伝播させる。
    private var sessionChangeForwarder: AnyCancellable?

    var elapsed: TimeInterval { audioRecorder.elapsed }

    init(session: RecordingSession) {
        self.session = session
        sessionChangeForwarder = session.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func start() {
        guard case .available = summarizer.checkAvailability() else {
            errorMessage = "この端末ではFoundation Modelsが利用できません（Apple Intelligence対応機種・設定ONが必要です）。"
            return
        }

        TranscriptionService.requestAuthorization { [weak self] granted in
            guard let self else { return }
            guard granted else {
                Task { @MainActor in
                    self.errorMessage = "音声認識の権限が許可されていません。設定アプリから許可してください。"
                }
                return
            }
            Task { @MainActor in
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(session.id).m4a")
        session.audioFileURL = fileURL

        transcriber.onChunkFinalized = { [weak self] index, text, startedAt, endedAt in
            Task { @MainActor in
                self?.handleChunkFinalized(index: index, text: text, startedAt: startedAt, endedAt: endedAt)
            }
        }
        audioRecorder.onBuffer = { [weak self] buffer in
            self?.transcriber.append(buffer: buffer)
        }

        do {
            try audioRecorder.start(to: fileURL)
            try transcriber.start()
            isRecording = true
        } catch {
            errorMessage = "録音を開始できませんでした: \(error.localizedDescription)"
        }
    }

    func stop() async {
        audioRecorder.stop()
        transcriber.stop()
        isRecording = false
        isFinalizing = true
        await refreshRollingSummary(force: true)
        await finalize()
        isFinalizing = false
    }

    /// 「要約を見る」パネルを開いた時、2分以上古ければ即リフレッシュする。
    func refreshIfStale() async {
        if session.rollingSummary.isStale {
            await refreshRollingSummary(force: true)
        }
    }

    private func handleChunkFinalized(index: Int, text: String, startedAt: Date, endedAt: Date) {
        guard !text.isEmpty else { return }
        Task {
            let previousConclusion = session.chunkSummaries.last?.bullets.last
            do {
                let generated = try await summarizer.summarizeChunk(transcript: text, previousConclusion: previousConclusion)
                let chunk = ChunkSummary(
                    chunkIndex: index,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    transcript: text,
                    bullets: generated.bullets,
                    todoCandidates: generated.todoCandidates
                )
                await MainActor.run {
                    session.chunkSummaries.append(chunk)
                    pendingChunksSinceRefine.append(chunk)
                }
                await maybeRefineRollingSummary()
            } catch {
                let chunk = ChunkSummary(
                    chunkIndex: index,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    transcript: text,
                    isLowConfidence: true
                )
                await MainActor.run {
                    session.chunkSummaries.append(chunk)
                }
            }
        }
    }

    private func maybeRefineRollingSummary() async {
        let elapsedSinceRefine = Date().timeIntervalSince(lastRefineAt)
        guard pendingChunksSinceRefine.count >= refineChunkThreshold || elapsedSinceRefine >= refineTimeThreshold else {
            return
        }
        await refreshRollingSummary(force: false)
    }

    private func refreshRollingSummary(force: Bool) async {
        guard force || !pendingChunksSinceRefine.isEmpty else { return }
        do {
            let updated = try await summarizer.refineRollingSummary(previous: session.rollingSummary, newChunks: pendingChunksSinceRefine)
            session.rollingSummary = updated
            pendingChunksSinceRefine.removeAll()
            lastRefineAt = Date()
        } catch {
            errorMessage = "要約の更新に失敗しました: \(error.localizedDescription)"
        }
    }

    private func finalize() async {
        do {
            let allTodos = session.chunkSummaries.flatMap { $0.todoCandidates }
            let final = try await summarizer.finalizeSummary(
                rolling: session.rollingSummary,
                trailingChunks: pendingChunksSinceRefine,
                allTodoCandidates: allTodos
            )
            session.finalSummary = final
        } catch {
            errorMessage = "最終要約の生成に失敗しました: \(error.localizedDescription)"
        }
    }
}
