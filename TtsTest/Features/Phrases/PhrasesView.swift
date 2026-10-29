import SwiftUI

/// 常用语页：对应 Android 端的 PhrasesFragment。
/// 点击整行直接朗读（喇叭图标闪烁），编辑态下长按拖拽排序，左滑删除，底部新增。
struct PhrasesView: View {

    @ObservedObject var tts: TtsManager

    @StateObject private var store = PhrasesStore()

    @State private var playingID: UUID?
    @State private var blinkTask: Task<Void, Never>?
    @State private var toast: ToastMessage?

    @State private var editMode: EditMode = .inactive
    @State private var isAdding = false
    @State private var newPhrase = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if store.phrases.isEmpty {
                Text("暂无常用语，点下方「新增」添加")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            }

            List {
                ForEach(store.phrases) { phrase in
                    row(for: phrase)
                        .listRowInsets(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .onMove { source, destination in
                    store.move(from: source, to: destination)
                }
                .onDelete { offsets in
                    store.remove(at: offsets)
                    toast = ToastMessage(text: "已删除")
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.appBackground)
            .environment(\.editMode, $editMode)
            .padding(.top, 8)

            Button {
                newPhrase = ""
                isAdding = true
            } label: {
                Label("新增", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background(Theme.appBackground)
        .toast($toast)
        .alert("新增常用语", isPresented: $isAdding) {
            TextField("输入常用语内容", text: $newPhrase)
            Button("取消", role: .cancel) {}
            Button("确定") { addPhrase() }
        }
        .onDisappear {
            blinkTask?.cancel()
            blinkTask = nil
            playingID = nil
        }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack {
            Text("常用语")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            if !store.phrases.isEmpty {
                Button(editMode == .active ? "完成" : "编辑") {
                    withAnimation {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }
                .font(.system(size: 16))
                .foregroundStyle(Theme.wechatGreen)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    // MARK: - 行

    private func row(for phrase: Phrase) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.wechatGreen)
                .frame(width: 24, height: 24)
                .symbolEffect(.variableColor.iterative, isActive: playingID == phrase.id)

            Text(phrase.text)
                .font(.system(size: 20))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 拖拽手柄：提示这一行可以上下拖拽排序
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16))
                .foregroundStyle(Theme.unselectedGray)
                .frame(width: 24, height: 24)
        }
        .contentShape(Rectangle())
        .onTapGesture { speak(phrase) }
    }

    // MARK: - 新增 / 朗读

    private func addPhrase() {
        let text = newPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.add(text)
        newPhrase = ""
    }

    private func speak(_ phrase: Phrase) {
        switch tts.state {
        case .ready:
            tts.speak(phrase.text)
            playingID = phrase.id
            blinkTask?.cancel()
            blinkTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                playingID = nil
            }
        case .initializing:
            toast = ToastMessage(text: "语音引擎未就绪")
        case .unavailable:
            toast = ToastMessage(text: tts.errorMessage)
        }
    }
}
