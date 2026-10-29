import AVFoundation
import Combine

/// 全局共享的语音合成引擎，对应 Android 端的 TtsManager。
///
/// - 单例：所有页面共用同一个 `AVSpeechSynthesizer`。`speak()` 一律「先停当前再读新的」，
///   这样不同页面之间的朗读不会互相打断不了。
/// - 对外暴露 0.1×~2.0× 的倍速，内部换算成 `AVSpeechUtterance.rate`。
final class TtsManager: NSObject, ObservableObject {

    enum State: Equatable {
        case initializing
        case ready
        case unavailable
    }

    static let shared = TtsManager()

    @Published private(set) var state: State = .initializing
    @Published private(set) var errorMessage = "语音引擎初始化失败，请检查系统是否可用语音合成"
    @Published private(set) var isSpeaking = false

    /// 语速倍速（0.1~2.0）。只影响之后开始的朗读，和 Android 的 setSpeechRate 行为一致。
    var speechRate: Float = 1.0

    private let synthesizer = AVSpeechSynthesizer()
    private var voice: AVSpeechSynthesisVoice?

    private override init() {
        super.init()
        synthesizer.delegate = self

        // 优先用系统当前语言，其次中文、英文；系统里一个可用音色都没有才算不可用
        let preferred = Locale.preferredLanguages.first ?? "zh-CN"
        let candidates = [preferred, "zh-CN", "en-US"]
        voice = candidates
            .compactMap { AVSpeechSynthesisVoice(language: $0) }
            .first

        if voice == nil {
            state = .unavailable
            errorMessage = "系统缺少当前语言的离线语音数据，请在「设置 → 辅助功能 → 朗读内容 → 声音」中下载"
        } else {
            state = .ready
        }
    }

    /// 立刻停止当前朗读，朗读新文字
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, state == .ready else { return }

        activateSession()

        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voice
        utterance.rate = Self.utteranceRate(for: speechRate)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        synthesizer.speak(utterance)
        publishSpeaking(true)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        publishSpeaking(false)
    }

    /// 0.1×~2.0× 映射到 AVSpeechUtterance 的 0.05~1.0（1.0× 对应系统的 0.5）
    private static func utteranceRate(for multiplier: Float) -> Float {
        let clamped = min(max(multiplier, 0.1), 2.0)
        let raw = AVSpeechUtteranceDefaultSpeechRate * clamped
        return min(max(raw, 0.05), 1.0)
    }

    /// 用 `.playback` + `.spokenAudio`：静音键打开时也能出声，并且会压低其他 App 的音量。
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // 会话激活失败也让朗读继续，系统会自行处理
        }
    }

    private func publishSpeaking(_ value: Bool) {
        if Thread.isMainThread {
            isSpeaking = value
        } else {
            DispatchQueue.main.async { self.isSpeaking = value }
        }
    }
}

extension TtsManager: AVSpeechSynthesizerDelegate {

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        publishSpeaking(true)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // 新的朗读可能已经排队，直接问引擎当前状态，避免把新朗读误标成「结束」
        publishSpeaking(synthesizer.isSpeaking)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        publishSpeaking(synthesizer.isSpeaking)
    }
}
