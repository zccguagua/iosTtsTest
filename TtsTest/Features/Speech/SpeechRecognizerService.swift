import AVFoundation
import Combine
import Speech

/// 一次识别完成的最终结果。用独立的 id 让 SwiftUI 能通过 `onChange` 可靠地收到通知。
struct SpeechFinalResult: Equatable {
    let id = UUID()
    let text: String
}

/// 系统 Speech 框架的识别封装，对应 Android 端的 sherpa-onnx + SenseVoice。
///
/// 系统识别器没有「按住说话、松开出整段文字」的批量接口，所以这里用
/// `AVAudioEngine` 实时喂音频给 `SFSpeechAudioBufferRecognitionRequest`：
/// 按下开始录音，过程中拿中间结果，松开后等最终结果落定。
///
/// 所有 `@Published` 的赋值都保证在主线程（识别回调统一 dispatch 回 main）。
final class SpeechRecognizerService: ObservableObject {

    enum Phase: Equatable {
        case idle
        case listening
        case decoding
        case unavailable(String)
    }

    @Published private(set) var phase: Phase = .idle
    /// 识别过程中的中间结果，目前界面不展示，保留给后续做实时字幕
    @Published private(set) var liveText = ""
    @Published private(set) var lastFinal: SpeechFinalResult?

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()

    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var lastTranscript = ""
    private var isRecording = false
    private var wantsRecording = false
    private var hasTap = false
    private var sessionActive = false
    private var fallbackWorkItem: DispatchWorkItem?

    init() {
        recognizer = SFSpeechRecognizer(locale: Self.preferredLocale())
    }

    // MARK: - 按住 / 松开

    /// 按下：申请权限后开始录音（权限只弹一次，之后直接开录）
    func start() {
        guard !isRecording, !wantsRecording else { return }
        wantsRecording = true

        Task { [weak self] in
            let granted = await Self.requestPermissions()
            DispatchQueue.main.async {
                self?.beginRecording(granted: granted)
            }
        }
    }

    /// 松开：结束录音，等最终结果
    func stop() {
        wantsRecording = false
        guard isRecording else { return }
        finishRecording()
    }

    /// 页面离开时调用：放弃本次识别，释放麦克风
    func cancel() {
        wantsRecording = false
        guard isRecording || phase == .decoding else { return }
        cancelFallback()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        stopAudio()
        phase = .idle
        liveText = ""
        lastTranscript = ""
    }

    // MARK: - 录音

    private func beginRecording(granted: Bool) {
        // 授权是异步的，用户可能已经松手了
        guard wantsRecording else { return }

        guard granted else {
            wantsRecording = false
            phase = .unavailable("需要麦克风权限才能录音，请到「设置」里开启")
            return
        }

        guard let recognizer, recognizer.isAvailable else {
            wantsRecording = false
            phase = .unavailable("识别服务暂不可用，请稍后再试")
            return
        }

        do {
            try configureAudioSession()
        } catch {
            wantsRecording = false
            phase = .unavailable("启动麦克风失败，请稍后再试")
            return
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            wantsRecording = false
            stopAudio()
            phase = .unavailable("当前设备没有可用的麦克风")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        // 能用离线识别就走离线；系统没下载对应语言的听写资源时退回在线识别
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        lastTranscript = ""
        liveText = ""

        removeTapIfNeeded()
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasTap = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handle(result: result, error: error)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            wantsRecording = false
            stopAudio()
            phase = .unavailable("启动麦克风失败，请稍后再试")
            return
        }

        isRecording = true
        phase = .listening
    }

    private func finishRecording() {
        isRecording = false
        phase = .decoding

        audioEngine.stop()
        removeTapIfNeeded()
        request?.endAudio()

        // 系统偶尔不会回 isFinal，2.5 秒后用已收到的中间结果兜底
        cancelFallback()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.finalize(with: self.lastTranscript)
        }
        fallbackWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: item)
    }

    // MARK: - 结果

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            let text = result.bestTranscription.formattedString
            lastTranscript = text
            liveText = text

            if result.isFinal {
                finalize(with: text)
            } else if error != nil {
                finalize(with: text)
            }
            return
        }

        if error != nil {
            // 录音中出错也要把已经识别出的部分交出去，而不是直接丢掉
            finalize(with: lastTranscript)
        }
    }

    private func finalize(with text: String) {
        guard phase == .listening || phase == .decoding else { return }

        cancelFallback()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        stopAudio()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        phase = .idle
        liveText = ""
        lastTranscript = ""
        lastFinal = SpeechFinalResult(text: trimmed)
    }

    private func cancelFallback() {
        fallbackWorkItem?.cancel()
        fallbackWorkItem = nil
    }

    // MARK: - 音频会话 / 麦克风

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)
        sessionActive = true
    }

    private func stopAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        removeTapIfNeeded()

        guard sessionActive else { return }
        sessionActive = false
        // 交还音频会话，下一次「朗读」才能正常切到 .playback
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func removeTapIfNeeded() {
        guard hasTap else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        hasTap = false
    }

    // MARK: - 权限

    private static func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - 语言

    /// 优先用系统语言；系统没支持就按语言前缀找（zh-Hans-CN → zh-CN），最后兜底中文
    private static func preferredLocale() -> Locale {
        let supported = SFSpeechRecognizer.supportedLocales()
        let preferred = Locale.preferredLanguages

        if let exact = preferred.first(where: { supported.contains(Locale(identifier: $0)) }) {
            return Locale(identifier: exact)
        }

        if let prefix = preferred.first.map({ String($0.prefix(2)).lowercased() }),
           let matched = supported.first(where: { $0.identifier.lowercased().hasPrefix(prefix) }) {
            return matched
        }

        return Locale(identifier: "zh-CN")
    }
}
