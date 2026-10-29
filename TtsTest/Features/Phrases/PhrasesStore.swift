import Foundation
import SwiftUI

struct Phrase: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

/// 常用语：对应 Android 端的 SharedPreferences + JSON，首次启动写入默认用语。
///
/// 相比 Android 存纯字符串，这里每一条带一个 UUID：列表要做拖拽排序，
/// 文本可能重复，用 id 才能保证 SwiftUI 的行身份稳定。
final class PhrasesStore: ObservableObject {

    @Published private(set) var phrases: [Phrase] = []

    private let defaults = UserDefaults.standard
    private let key = "phrases"

    static let defaultTexts = [
        "你好",
        "谢谢",
        "麻烦再说一遍",
        "好的，没问题",
        "别客气",
        "注意安全",
        "天气怎么样",
        "我爱你",
        "早上好！",
        "中午好！",
        "晚上好！",
        "你弄啥捏",
    ]

    init() {
        load()
    }

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        phrases.append(Phrase(text: trimmed))
        save()
    }

    func remove(at offsets: IndexSet) {
        phrases.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        phrases.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func load() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Phrase].self, from: data) {
            phrases = decoded
        } else {
            phrases = Self.defaultTexts.map { Phrase(text: $0) }
            save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(phrases) else { return }
        defaults.set(data, forKey: key)
    }
}
