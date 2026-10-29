import SwiftUI

/// 一条识别记录：时间 + 右侧浅绿气泡 + 气泡右侧的喇叭按钮。
/// 对应 Android 端的 bg_bubble_speech.xml + ic_bubble_tail.xml + 时间戳。
struct MessageBubbleView: View {

    let entry: SpeechEntry
    let isPlaying: Bool
    let onPlay: () -> Void

    private var maxBubbleWidth: CGFloat {
        min(UIScreen.main.bounds.width * 0.72, 520)
    }

    private var timeText: String {
        guard entry.time > 0 else { return "" }
        let date = Date(timeIntervalSince1970: entry.time)
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if !timeText.isEmpty {
                Text(timeText)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                    // 右内边距 = 喇叭按钮宽度，让时间与气泡右边缘对齐
                    .padding(.trailing, 34)
            }

            HStack(alignment: .center, spacing: 2) {
                Spacer(minLength: 24)

                Text(entry.text)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.bubbleGreen, in: RoundedRectangle(cornerRadius: 18))
                    // 限制气泡最大宽度后再右对齐，短文本也贴右边
                    .frame(maxWidth: maxBubbleWidth, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onPlay) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.wechatGreen)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
