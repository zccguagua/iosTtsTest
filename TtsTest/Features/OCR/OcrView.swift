import PhotosUI
import SwiftUI
import UIKit

/// 拍照识别页：对应 Android 端的 OcrFragment。
/// 拍照或从相册选图 → Vision 离线识别中文 → 结果可编辑、可复制、可朗读。
struct OcrView: View {

    @ObservedObject var tts: TtsManager

    @State private var preview: UIImage?
    @State private var resultText = ""
    @State private var isRecognizing = false
    @State private var hasResult = false

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?

    @State private var toast: ToastMessage?
    @FocusState private var resultFocused: Bool

    private var canCopy: Bool { hasResult }

    private var canSpeak: Bool { hasResult && tts.state == .ready }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("拍照识别")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 12) {
                    Button {
                        openCamera()
                    } label: {
                        Label("拍照", systemImage: "camera.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("从相册选择", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.top, 16)

                Group {
                    if let preview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Text("拍摄或选择一张有文字的图片")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Theme.previewBackground, in: RoundedRectangle(cornerRadius: 10))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.top, 16)

                Text("识别结果")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 16)

                TextEditor(text: $resultText)
                    .focused($resultFocused)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 132)
                    .background(Theme.inputBackground, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .topLeading) {
                        if resultText.isEmpty {
                            Text("识别出的文字会显示在这里")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.unselectedGray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay {
                        if isRecognizing {
                            ProgressView()
                                .controlSize(.large)
                                .padding(16)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.top, 8)

                HStack(spacing: 12) {
                    Button {
                        copyResult()
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canCopy)
                    .opacity(canCopy ? 1 : 0.5)

                    Button {
                        speakResult()
                    } label: {
                        Label("朗读", systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSpeak)
                    .opacity(canSpeak ? 1 : 0.5)
                }
                .padding(.top, 16)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.appBackground)
        .toast($toast)
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem?.itemIdentifier) { _, _ in
            loadSelectedPhoto()
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                apply(image: image)
            }
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { resultFocused = false }
            }
        }
    }

    // MARK: - 选图

    private func openCamera() {
        guard CameraPicker.isAvailable else {
            toast = ToastMessage(text: "当前设备没有相机，请从相册选择")
            return
        }
        showCamera = true
    }

    private func loadSelectedPhoto() {
        guard let item = photoItem else { return }
        Task { @MainActor in
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                toast = ToastMessage(text: "读取图片失败")
                return
            }
            apply(image: image)
        }
    }

    private func apply(image: UIImage) {
        preview = image
        Task { @MainActor in
            await recognize(image)
        }
    }

    // MARK: - 识别

    @MainActor
    private func recognize(_ image: UIImage) async {
        isRecognizing = true
        hasResult = false
        resultText = ""

        do {
            let text = try await TextRecognizer.recognizeText(in: image)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            hasResult = !trimmed.isEmpty
            resultText = trimmed.isEmpty ? "未识别到文字" : trimmed
        } catch {
            hasResult = false
            resultText = "识别失败，请重试"
        }

        isRecognizing = false
    }

    // MARK: - 复制 / 朗读

    private func copyResult() {
        let text = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasResult, !text.isEmpty else {
            toast = ToastMessage(text: "暂无可复制的文字")
            return
        }
        UIPasteboard.general.string = text
        toast = ToastMessage(text: "已复制到剪贴板")
    }

    private func speakResult() {
        let text = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasResult, !text.isEmpty else {
            toast = ToastMessage(text: "未识别到文字")
            return
        }
        resultFocused = false
        tts.speak(text)
    }
}
