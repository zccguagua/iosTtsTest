import SwiftUI

/// 容器视图：底部 4 个 Tab，对应 Android 端 MainActivity + BottomNavigationView。
///
/// 和 Android 一样采用「首次进入才创建」的懒加载方式：TabView 里的页面
/// 只有被选中时才会真正构建，语音识别这类需要申请权限的页面就不会在启动时打扰用户。
struct RootView: View {

    enum Tab: Hashable {
        case tts
        case ocr
        case speech
        case phrases
    }

    @State private var selectedTab: Tab = .tts

    var body: some View {
        TabView(selection: $selectedTab) {
            TtsView(tts: TtsManager.shared)
                .tabItem { Label("朗读", systemImage: "speaker.wave.2.fill") }
                .tag(Tab.tts)

            OcrView(tts: TtsManager.shared)
                .tabItem { Label("拍照识别", systemImage: "camera.fill") }
                .tag(Tab.ocr)

            SpeechView(tts: TtsManager.shared)
                .tabItem { Label("语音识别", systemImage: "mic.fill") }
                .tag(Tab.speech)

            PhrasesView(tts: TtsManager.shared)
                .tabItem { Label("常用语", systemImage: "star.fill") }
                .tag(Tab.phrases)
        }
        .tint(Theme.wechatGreen)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.white, for: .tabBar)
    }
}
