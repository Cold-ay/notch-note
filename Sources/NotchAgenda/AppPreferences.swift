import Foundation
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case traditionalChinese = "zh-Hant", simplifiedChinese = "zh-Hans", english = "en"
    var id: String { rawValue }
    var name: String {
        switch self { case .traditionalChinese: "繁體中文"; case .simplifiedChinese: "简体中文"; case .english: "English" }
    }
    var locale: Locale { Locale(identifier: rawValue) }
    static func resolve(_ locale: Locale) -> Self {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        if identifier.hasPrefix("en") { return .english }
        return identifier.contains("Hans") ? .simplifiedChinese : .traditionalChinese
    }
    func text(_ key: String) -> String {
        switch self {
        case .traditionalChinese: return key
        case .simplifiedChinese:
            let overrides = ["私隱政策": "隐私政策", "設定": "设置", "設定…": "设置…", "儲存日記": "保存日记", "儲存安排": "保存安排", "復原上次儲存": "撤销上次保存"]
            if let value = overrides[key] { return value }
            if let prefix = EnglishStrings.errorPrefixes.first(where: { key.hasPrefix($0) }) {
                return (prefix.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? prefix) + key.dropFirst(prefix.count)
            }
            return key.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? key
        case .english:
            if let value = EnglishStrings.values[key] { return value }
            // Keep system diagnostic details intact while translating the app's prefix.
            if let prefix = EnglishStrings.errorPrefixes.first(where: { key.hasPrefix($0) }), let value = EnglishStrings.values[prefix] {
                return value + key.dropFirst(prefix.count)
            }
            return key
        }
    }
}

enum NotebookPage: String, Codable, CaseIterable, Identifiable {
    case day, week, month, anytime, calendar
    var id: String { rawValue }
    var title: String {
        switch self { case .day: "每日"; case .week: "週目標"; case .month: "月目標"; case .anytime: "待完成"; case .calendar: "日曆" }
    }
    var subtitle: String {
        switch self { case .day: "一天一頁，慢慢記下。"; case .week: "把一週，寫成一個篇章。"; case .month: "留給長一點的期待。"; case .anytime: "尚未定日子的念頭。"; case .calendar: "替未來，留一個位置。" }
    }
    var scope: TaskScope {
        switch self { case .day, .calendar: .day; case .week: .week; case .month: .month; case .anytime: .anytime }
    }
    static func page(for scope: TaskScope) -> Self {
        switch scope { case .day: .day; case .week: .week; case .month: .month; case .anytime: .anytime }
    }
}

enum NotebookAppearance: String, Codable, CaseIterable, Identifiable {
    case cream, rose, leather, minimal
    var id: String { rawValue }
    var title: String {
        switch self { case .cream: "原版米白"; case .rose: "溫柔粉色"; case .leather: "沉穩大叔"; case .minimal: "極簡線條" }
    }
}

enum NotebookPaper: String, Codable, CaseIterable, Identifiable {
    case ruled, grid, dotted, plain
    var id: String { rawValue }
    var title: String {
        switch self { case .ruled: "橫線"; case .grid: "方格"; case .dotted: "點陣"; case .plain: "空白" }
    }
}

enum HoverSpeed: String, Codable, CaseIterable, Identifiable {
    case fast, medium, slow
    var id: String { rawValue }
    var title: String {
        switch self { case .fast: "快"; case .medium: "中"; case .slow: "慢" }
    }
    var openingDuration: TimeInterval {
        switch self { case .fast: 0.26; case .medium: 0.52; case .slow: 0.90 }
    }
    var closingDuration: TimeInterval {
        switch self { case .fast: 0.23; case .medium: 0.46; case .slow: 0.80 }
    }
}

private struct PreferenceDocument: Codable, Equatable {
    var language = AppLanguage.traditionalChinese
    var appearance = NotebookAppearance.cream
    var paper = NotebookPaper.ruled
    var hoverSpeed = HoverSpeed.medium
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        language = try values.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .traditionalChinese
        appearance = try values.decodeIfPresent(NotebookAppearance.self, forKey: .appearance) ?? .cream
        paper = try values.decodeIfPresent(NotebookPaper.self, forKey: .paper) ?? .ruled
        hoverSpeed = try values.decodeIfPresent(HoverSpeed.self, forKey: .hoverSpeed) ?? .medium
    }
}

@MainActor @Observable final class AppPreferences {
    private var document = PreferenceDocument()
    private(set) var errorMessage: String?
    private let file: URL
    private var loadFailed = false
    static let didChange = Notification.Name("NotchAgendaPreferencesDidChange")
    var language: AppLanguage { document.language }
    var locale: Locale { document.language.locale }
    var appearance: NotebookAppearance { document.appearance }
    var paper: NotebookPaper { document.paper }
    var hoverSpeed: HoverSpeed { document.hoverSpeed }
    var weekdaySymbols: [String] { language == .english ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] : ["一", "二", "三", "四", "五", "六", "日"] }

    init(file: URL) {
        self.file = file
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                document = try JSONDecoder().decode(PreferenceDocument.self, from: Data(contentsOf: file))

            }
        } catch {
            loadFailed = true
            errorMessage = "未能讀取設定，已保留原檔。"
        }
    }
    func text(_ key: String) -> String { language.text(key) }
    func format(_ key: String, _ arguments: CVarArg...) -> String { String(format: text(key), locale: locale, arguments: arguments) }
    @discardableResult func setLanguage(_ language: AppLanguage) -> Bool {
        var next = document; next.language = language; return save(next)
    }
    @discardableResult func setAppearance(_ appearance: NotebookAppearance) -> Bool {
        var next = document; next.appearance = appearance; return save(next)
    }
    @discardableResult func setPaper(_ paper: NotebookPaper) -> Bool {
        var next = document; next.paper = paper; return save(next)
    }
    @discardableResult func setHoverSpeed(_ speed: HoverSpeed) -> Bool {
        var next = document; next.hoverSpeed = speed; return save(next)
    }
    private func save(_ next: PreferenceDocument) -> Bool {
        guard !loadFailed else { errorMessage = "未能讀取設定，已保留原檔。"; return false }
        guard next != document else { return true }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: file, options: .atomic)
            document = next
            errorMessage = nil
            NotificationCenter.default.post(name: Self.didChange, object: self)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            return true
        } catch { errorMessage = "未能儲存設定：" + error.localizedDescription; return false }
    }
}
