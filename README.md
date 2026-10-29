# iOS TTS 测试

Android 版 `TtsTest` 的 iOS 复刻：同样的 4 个 Tab、同样的微信绿配色和气泡界面，
功能上用系统原生能力实现。

> 说明：这套代码是在 Windows 上写的，**没有经过 Xcode 编译验证**。
> 到 Mac 上第一次打开如果报编译错误，把报错贴出来即可，通常是个别 API 签名差异。

## 环境要求

- macOS + Xcode 15 或更高（Swift 5.9 / iOS 17 SDK）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`
- 真机运行效果最好（模拟器没有相机、也不一定能录音）

## 生成并运行

```bash
cd iosTtsTest
xcodegen generate
open TtsTestiOS.xcodeproj
```

然后在 Xcode 里：

1. 选中 `TtsTestiOS` target → `Signing & Capabilities`，勾选 `Automatically manage signing`
   并选择你自己的 Team（`project.yml` 里故意没写死 Team）。
2. 选一个 iOS 17+ 的真机或模拟器，⌘R 运行。
3. 真机运行需要在「设置 → 通用 → VPN与设备管理」里信任开发者证书。

`TtsTestiOS.xcodeproj` 是由 `project.yml` 生成的，已在 `.gitignore` 里忽略；
改了文件结构后重新跑一次 `xcodegen generate` 即可。

## 和 Android 版的功能对照

| 功能 | Android | iOS |
|---|---|---|
| 文字朗读 / 语速 / 停止 | `TextToSpeech` | `AVSpeechSynthesizer`（系统自带，离线） |
| 拍中文 OCR | ML Kit 中文模型（打包进 APK） | Vision `VNRecognizeTextRequest`（系统内置，零体积） |
| 离线语音识别 | sherpa-onnx + SenseVoice 239MB 模型 | 系统 `Speech` 框架（`requiresOnDeviceRecognition`） |
| 悬浮窗朗读 | 前台服务 + `SYSTEM_ALERT_WINDOW` | **做不到**，改为 App 内「朗读剪贴板」 |
| 常用语 | RecyclerView + ItemTouchHelper | `List` + `onMove` + `onDelete` |
| 识别历史 | SharedPreferences + JSON | `UserDefaults` + `Codable`，上限同样 20 条 |

### 为什么没有悬浮窗

iOS 不允许第三方 App 在其他 App 上常驻绘制悬浮窗，这个能力只有系统（辅助触控、
灵动岛直播活动）才有。所以改成了：

- 「朗读」页里的 **朗读剪贴板**：在其他 App 复制文字 → 切回本 App → 点按钮朗读。
- 首次读取剪贴板时系统会弹「允许粘贴」，这是 iOS 16 起的隐私机制，无法绕过。

后续如果想更接近原体验，可以加 **Share Extension**（在任意 App 里选中文字 →
分享 → 朗读），或者 **App Intents**（快捷指令 / 轻点背面触发）。这两者都是独立
target，需要另外加代码，本次没有做。

## 目录结构

```
TtsTest/
├── App/
│   ├── TtsTestiOSApp.swift      # 入口
│   └── RootView.swift           # 4 个 Tab 的容器
├── Core/
│   ├── Theme.swift              # 配色（对应 colors.xml / themes.xml）
│   ├── Components.swift         # 主按钮样式 + Toast 浮层
│   ├── TtsManager.swift         # 全局语音合成单例
│   └── Clipboard.swift          # 剪贴板读取
├── Features/
│   ├── TTS/TtsView.swift        # 朗读页
│   ├── OCR/                     # 拍照识别（Vision）
│   ├── Speech/                  # 语音识别（Speech 框架）+ 气泡
│   └── Phrases/                 # 常用语
└── Resources/Info.plist         # 权限说明文案
```

## 权限

`Info.plist` 里已经写好三条用途说明，首次用到时会弹系统授权：

| Key | 触发时机 |
|---|---|
| `NSMicrophoneUsageDescription` | 第一次按住说话 |
| `NSSpeechRecognitionUsageDescription` | 第一次按住说话 |
| `NSCameraUsageDescription` | 第一次点「拍照」 |

相册用 `PhotosPicker`，走系统的受限选择器，**不需要** `NSPhotoLibraryUsageDescription`。

## 已知差异 / 注意事项

- **离线识别**：系统 Speech 框架能否完全离线，取决于设备是否已下载对应语言的听写资源
  （「设置 → 通用 → 键盘 → 听写语言」）。`requiresOnDeviceRecognition` 只在系统报告
  支持时才置 true，否则退回在线识别。想完全脱离网络、和 Android 端行为一致，
  只能改回 sherpa-onnx（需要 macOS 上编译 framework、打包 239MB 模型）。
- **按住说话**：走的是流式识别 + 松开后等最终结果，最长等 2.5 秒，超时就用已经识别出的
  中间文本（对应 Android 端「等录音线程收尾」的逻辑）。
- **语速**：0.1×~2.0× 映射到 `AVSpeechUtterance.rate` 的 0.05~1.0（1.0× = 系统默认 0.5）。
  和 Android 一样，改语速只影响之后的朗读。
- **系统语音音色**：用系统当前语言对应的默认音色；换音色在
  「设置 → 辅助功能 → 朗读内容 → 声音」里选，App 内不做音色列表（Android 版同样没有）。
- **模拟器**：没有相机，点「拍照」会提示改用相册；录音在部分模拟器上也可能不可用。
- **编辑 / 排序**：常用语的拖拽排序需要先点右上角「编辑」（iOS 原生交互），
  左滑删除在非编辑态可用。

## 后续可以加

- Share Extension：在任意 App 里分享文字给本 App 朗读
- App Intents + 快捷指令：一键朗读剪贴板
- 识别结果实时字幕（`SpeechRecognizerService.liveText` 已经预留）
- 朗读音色选择、朗读进度高亮
