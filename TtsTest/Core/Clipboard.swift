import UIKit

enum Clipboard {
    /// 读取剪贴板里的纯文本。
    ///
    /// iOS 16 起首次读取会弹出系统的「允许粘贴」提示，这是系统隐私机制，App 无法跳过；
    /// 所以这里设计成由用户点按钮触发，而不是一进页面就自动读。
    static func readText() -> String? {
        guard UIPasteboard.general.hasStrings else { return nil }
        let text = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}
