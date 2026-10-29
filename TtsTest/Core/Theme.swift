import SwiftUI

/// 与 Android 端 colors.xml / themes.xml 一一对应的配色。
enum Theme {
    /// 微信绿，按钮 / 强调色
    static let wechatGreen = Color(hex: 0x07C160)
    /// 微信「自己发出的消息」气泡绿
    static let bubbleGreen = Color(hex: 0x95EC69)
    static let appBackground = Color(hex: 0xF5F5F5)
    static let textPrimary = Color(hex: 0x000000)
    static let textSecondary = Color(hex: 0x666666)
    static let unselectedGray = Color(hex: 0x8A8A8A)
    static let stopYellow = Color(hex: 0xFFC107)
    /// 按住说话时按钮的淡蓝背景
    static let holdPressedBlue = Color(hex: 0x81D4FA)
    static let deleteRed = Color(hex: 0xF44336)
    static let previewBackground = Color(hex: 0xEEEEEE)
    static let inputBackground = Color.white
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
