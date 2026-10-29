import SwiftUI

/// 朗读页：对应 Android 端的 TtsFragment。
/// 文字朗读 + 语速调节 + 剪贴板朗读（Android 上是悬浮窗，iOS 不允许系统级悬浮球）。
struct TtsView: View {

    @ObservedObject var tts: TtsManager

    @State private var input = TtsView.defaultInput
    @State private var speedProgress: Double = 50
    @State private var toast: ToastMessage?
    @FocusState private var inputFocused: Bool

    private var rate: Float { Self.rateOf(progress: speedProgress) }

    private var canSpeak: Bool { tts.state == .ready }

    private var statusText: String {
        switch tts.state {
        case .initializing:
            return "正在初始化语音引擎…"
        case .ready:
            return tts.isSpeaking ? "正在朗读…" : "就绪"
        case .unavailable:
            return tts.errorMessage
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("TTS 测试")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text(statusText)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                TextEditor(text: $input)
                    .focused($inputFocused)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 132)
                    .background(Theme.inputBackground, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .topLeading) {
                        if input.isEmpty {
                            Text("输入要朗读的文字…")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.unselectedGray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.top, 24)

                HStack {
                    Text("语速")
                        .font(.system(size: 16))
                    Spacer()
                    Text(String(format: "%.2f×", rate))
                        .font(.system(size: 16))
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 20)

                Slider(value: $speedProgress, in: 0...100)
                    .tint(Theme.wechatGreen)
                    .onChange(of: speedProgress) { _, newValue in
                        tts.speechRate = Self.rateOf(progress: newValue)
                    }

                HStack(spacing: 12) {
                    Button {
                        speak()
                    } label: {
                        Label("朗读", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSpeak)
                    .opacity(canSpeak ? 1 : 0.5)

                    Button {
                        tts.stop()
                    } label: {
                        Label("停止", systemImage: "stop.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.stopYellow))
                    .disabled(!canSpeak)
                    .opacity(canSpeak ? 1 : 0.5)
                }
                .padding(.top, 24)

                Text("剪贴板朗读")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 32)

                Text("在其他 App 里复制文字后回到这里，点下面按钮就能朗读剪贴板内容。第一次读取时系统会询问是否允许粘贴。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                Button {
                    speakClipboard()
                } label: {
                    Label("朗读剪贴板", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSpeak)
                .opacity(canSpeak ? 1 : 0.5)
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { inputFocused = false }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.appBackground)
        .toast($toast)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { inputFocused = false }
            }
        }
        .onAppear {
            tts.speechRate = rate
        }
    }

    private func speak() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            toast = ToastMessage(text: "请先输入要朗读的文字")
            return
        }
        inputFocused = false
        tts.speak(text)
    }

    private func speakClipboard() {
        guard let text = Clipboard.readText() else {
            toast = ToastMessage(text: "剪贴板里没有文字")
            return
        }
        input = text
        tts.speak(text)
    }

    /// 进度 0~100 映射为语速 0.1~2.0（50 对应正常语速 1.0）
    private static func rateOf(progress: Double) -> Float {
        Float(max(progress / 50, 0.1))
    }

    private static let defaultInput = "彩虹，又稱天弓、天虹、絳等，簡稱虹，是氣象中的一種光學現象。 當太陽光照射到半空中的水滴時，光線被折射及反射，在天空上形成拱形的七彩光譜。 由外圈至內圈呈紅、橙、黃、綠、藍、靛、紫七種顏色（霓虹則相反）。"
}
