import SwiftUI

/// 与 Android 端 Widget.App.Button 对应的主按钮：微信绿、18sp、圆角。
/// 停止这类特殊按钮通过 tint 参数换色。
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.wechatGreen
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                tint.opacity(configuration.isPressed ? 0.8 : 1),
                in: RoundedRectangle(cornerRadius: 10)
            )
    }
}

/// iOS 没有 Android 的 Toast，这里用一个底部浮层代替：1.8 秒后自动消失。
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

private struct ToastModifier: ViewModifier {
    @Binding var message: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message.text)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.78), in: Capsule())
                        .padding(.horizontal, 32)
                        .padding(.bottom, 72)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: message)
            .task(id: message?.id) {
                guard message != nil else { return }
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                if !Task.isCancelled {
                    message = nil
                }
            }
    }
}

extension View {
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
