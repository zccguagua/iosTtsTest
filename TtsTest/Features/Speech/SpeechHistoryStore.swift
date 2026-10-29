import Combine
import Foundation

struct SpeechEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    /// 秒级时间戳，0 表示旧数据没有时间
    let time: TimeInterval

    init(id: UUID = UUID(), text: String, time: TimeInterval = Date().timeIntervalSince1970) {
        self.id = id
        self.text = text
        self.time = time
    }
}

/// 识别历史：对应 Android 端的 SharedPreferences + JSON，最多保留 20 条。
final class SpeechHistoryStore: ObservableObject {

    @Published private(set) var entries: [SpeechEntry] = []

    private let defaults = UserDefaults.standard
    private let key = "speech_history"
    private let maxCount = 20

    init() {
        load()
    }

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        entries.append(SpeechEntry(text: trimmed))
        if entries.count > maxCount {
            entries.removeFirst(entries.count - maxCount)
        }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SpeechEntry].self, from: data) else {
            return
        }
        entries = Array(decoded.suffix(maxCount))
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}
