import AVFoundation
import Combine

enum AudioRecorderError: Error {
    case fileCreationFailed
}

/// 長時間録音を前提に、圧縮フォーマット（AAC）でファイルへ書き込みながら
/// 同じバッファをリアルタイム文字起こし用に横流しする。
final class AudioRecorderService: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0

    /// マイク入力バッファを受け取るたびに呼ばれる（文字起こしサービスへの橋渡し用）。
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var timer: Timer?
    private var startedAt: Date?

    func start(to fileURL: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.allowBluetooth, .mixWithOthers])
        try session.setActive(true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        // 数時間の連続録音でもストレージを圧迫しないよう、AACへ圧縮しながら書き込む。
        let compressedSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
        ]
        guard let file = try? AVAudioFile(
            forWriting: fileURL,
            settings: compressedSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        ) else {
            throw AudioRecorderError.fileCreationFailed
        }
        audioFile = file

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            try? self.audioFile?.write(from: buffer)
            self.onBuffer?(buffer)
        }

        try engine.start()
        startedAt = Date()
        isRecording = true

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let startedAt = self.startedAt else { return }
            self.elapsed = Date().timeIntervalSince(startedAt)
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
