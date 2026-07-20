import AVFoundation
import Speech

enum TranscriptionError: Error {
    case recognizerUnavailable
    case onDeviceUnsupported
}

/// SFSpeechRecognizerによるオンデバイス・ストリーミング文字起こし。
///
/// 1つの認識リクエストを数時間持たせ続けるのではなく、チャンク境界ごとに
/// リクエストを終了→再生成する構成にしている。これにより「区間要約」の単位と
/// 文字起こしリクエストの単位が1対1になり、長時間録音でも1リクエストが
/// 際限なく肥大化しない。
final class TranscriptionService: ObservableObject {
    @Published private(set) var liveText: String = ""

    /// チャンクが確定するたびに呼ばれる（index, 確定テキスト, 開始時刻, 終了時刻）。
    var onChunkFinalized: ((Int, String, Date, Date) -> Void)?

    /// PoC簡易版：無音検出（VAD）ではなく固定間隔でチャンクを切る。
    /// 本実装では無音区間ベースの分割に置き換える想定。
    private let chunkInterval: TimeInterval = 240

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var chunkTimer: Timer?
    private var chunkIndex = 0
    private var chunkStartedAt = Date()

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { completion(status == .authorized) }
        }
    }

    func start() throws {
        chunkIndex = 0
        try beginChunk()
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkInterval, repeats: true) { [weak self] _ in
            self?.rotateChunk()
        }
    }

    func append(buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    func stop() {
        chunkTimer?.invalidate()
        chunkTimer = nil
        request?.endAudio()
    }

    private func beginChunk() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.onDeviceUnsupported
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true
        request = req
        liveText = ""
        chunkStartedAt = Date()

        let index = chunkIndex
        let startedAt = chunkStartedAt

        task = recognizer.recognitionTask(with: req) { [weak self] result, _ in
            guard let self, let result else { return }
            self.liveText = result.bestTranscription.formattedString
            if result.isFinal {
                self.onChunkFinalized?(index, result.bestTranscription.formattedString, startedAt, Date())
            }
        }
    }

    private func rotateChunk() {
        request?.endAudio()
        chunkIndex += 1
        try? beginChunk()
    }
}
