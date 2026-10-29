import SwiftUI

/// 语音识别页：对应 Android 端的 SpeechFragment。
/// 底部按住说话、松开识别，结果以微信风格气泡依次追加，气泡旁的喇叭可朗读该条。
struct SpeechView: View {

    @ObservedObject var tts: TtsManager

    @StateObject private var service = SpeechRecognizerService()
    @StateObject private var store = SpeechHistoryStore()

    @State private var isPressing = false
    @State private var playingID: UUID?
    @State private var blinkTask: Task<Void, Never>?
    @State private var toast: ToastMessage?

    private var statusText: String {
        switch service.phase {
        case .idle:
            return "就绪，按住下方按钮说话"
        case .listening:
            return "正在聆听…"
        case .decoding:
            return "正在识别…"
        case .unavailable(let message):
            return message
        }
    }

    private var holdTitle: String {
        isPressing ? "松开结束" : "按住说话"
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Text(statusText)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .padding(.top, 2)

            historyList

            holdButton
        }
        .background(Theme.appBackground)
        .toast($toast)
        .onChange(of: service.lastFinal) { _, result in
            guard let result else { return }
            if result.text.isEmpty {
                toast = ToastMessage(text: "未识别到内容")
            } else {
                store.add(result.text)
            }
        }
        .onDisappear {
            service.cancel()
            blinkTask?.cancel()
            blinkTask = nil
            playingID = nil
        }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack {
            Text("语音识别")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Button("清空") {
                store.clear()
                playingID = nil
            }
            .font(.system(size: 16))
            .foregroundStyle(Theme.wechatGreen)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - 历史气泡

    private var historyList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if store.entries.isEmpty {
                    Text("暂无识别记录")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(store.entries) { entry in
                            MessageBubbleView(
                                entry: entry,
                                isPlaying: playingID == entry.id,
                                onPlay: { speak(entry) }
                            )
                            .id(entry.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .onChange(of: store.entries.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onAppear {
                scrollToBottom(proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = store.entries.last else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - 按住说话

    private var holdButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
            Text(holdTitle)
        }
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            isPressing ? Theme.holdPressedBlue : Theme.wechatGreen,
            in: Capsule()
        )
        .contentShape(Capsule())
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        // minimumDistance 0 才能拿到「按下」时刻，而不是必须拖动才响应
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginPress() }
                .onEnded { _ in endPress() }
        )
        .animation(.easeOut(duration: 0.12), value: isPressing)
    }

    private func beginPress() {
        guard !isPressing else { return }
        guard service.phase != .decoding else {
            toast = ToastMessage(text: "正在识别，请稍候")
            return
        }
        isPressing = true
        // 正在朗读气泡时开始录音，先停掉，避免把自己的朗读声录进去
        tts.stop()
        service.start()
    }

    private func endPress() {
        guard isPressing else { return }
        isPressing = false
        service.stop()
    }

    // MARK: - 气泡朗读

    private func speak(_ entry: SpeechEntry) {
        switch tts.state {
        case .ready:
            tts.speak(entry.text)
            playingID = entry.id
            blinkTask?.cancel()
            blinkTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                playingID = nil
            }
        case .initializing:
            toast = ToastMessage(text: "正在初始化语音引擎…")
        case .unavailable:
            toast = ToastMessage(text: tts.errorMessage)
        }
    }
}
