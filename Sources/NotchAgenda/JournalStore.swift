import Foundation
import Observation

struct JournalEntry: Identifiable, Codable, Equatable {
    let id: String
    let scope: TaskScope
    let periodStart: Date
    var text: String
    let createdAt: Date
    var updatedAt: Date
}

@MainActor @Observable final class JournalStore {
    private(set) var entries: [JournalEntry] = []
    private(set) var drafts: [String: String] = [:]
    private(set) var errorMessage: String?
    private var draftPeriods: [String: (Date, TaskScope)] = [:]
    private var previous: (key: String, entry: JournalEntry?)?
    private let file: URL
    private let now: () -> Date
    private let calendar: Calendar
    private var loadFailed = false

    init(file: URL, now: @escaping () -> Date = Date.init, calendar: Calendar = .taskCalendar) {
        self.file = file
        self.now = now
        self.calendar = calendar
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                entries = try JSONDecoder().decode([JournalEntry].self, from: Data(contentsOf: file))
            }
        } catch {
            loadFailed = true
            errorMessage = "未能讀取手記，已保留原檔並停止寫入：\(error.localizedDescription)"
        }
    }

    func key(on date: Date, scope: TaskScope) -> String {
        let start = periodStart(on: date, scope: scope)
        let parts = calendar.dateComponents([.era, .year, .month, .day], from: start)
        // Civil-date keys remain stable when the user travels across time zones.
        return "\(scope.rawValue)/\(parts.era ?? 1)/\(parts.year!)-\(parts.month!)-\(parts.day!)"
    }

    func entry(on date: Date, scope: TaskScope) -> JournalEntry? {
        entries.first { $0.id == key(on: date, scope: scope) }
    }
    func text(on date: Date, scope: TaskScope) -> String {
        drafts[key(on: date, scope: scope)] ?? entry(on: date, scope: scope)?.text ?? ""
    }
    func hasDraft(on date: Date, scope: TaskScope) -> Bool { drafts[key(on: date, scope: scope)] != nil }
    func canUndo(on date: Date, scope: TaskScope) -> Bool { previous?.key == key(on: date, scope: scope) }

    func setDraft(_ text: String, on date: Date, scope: TaskScope) {
        guard scope != .anytime else { return }
        let key = key(on: date, scope: scope)
        if text == (entry(on: date, scope: scope)?.text ?? "") {
            drafts.removeValue(forKey: key)
            draftPeriods.removeValue(forKey: key)
        } else {
            drafts[key] = text
            draftPeriods[key] = (date, scope)
        }
    }

    @discardableResult func saveDraft(on date: Date, scope: TaskScope) -> Bool {
        guard scope != .anytime else { return false }
        let key = key(on: date, scope: scope)
        guard let text = drafts[key] else { return true }
        let old = entry(on: date, scope: scope)
        var next = entries.filter { $0.id != key }
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            next.append(JournalEntry(id: key, scope: scope, periodStart: periodStart(on: date, scope: scope), text: text, createdAt: old?.createdAt ?? now(), updatedAt: now()))
        }
        guard persist(next) else { return false }
        previous = (key, old)
        entries = next
        drafts.removeValue(forKey: key)
        draftPeriods.removeValue(forKey: key)
        return true
    }

    @discardableResult func flushAllDrafts() -> Bool {
        let periods = Array(draftPeriods.values)
        var success = true
        for (date, scope) in periods {
            if !saveDraft(on: date, scope: scope) { success = false }
        }
        return success
    }

    @discardableResult func undo(on date: Date, scope: TaskScope) -> Bool {
        guard let previous, previous.key == key(on: date, scope: scope) else { return false }
        var next = entries.filter { $0.id != previous.key }
        if let entry = previous.entry { next.append(entry) }
        guard persist(next) else { return false }
        entries = next
        drafts.removeValue(forKey: previous.key)
        draftPeriods.removeValue(forKey: previous.key)
        self.previous = nil
        return true
    }

    private func periodStart(on date: Date, scope: TaskScope) -> Date {
        let component: Calendar.Component = scope == .week ? .weekOfYear : scope == .month ? .month : .day
        return calendar.dateInterval(of: component, for: date)!.start
    }
    private func persist(_ value: [JournalEntry]) -> Bool {
        guard !loadFailed else {
            errorMessage = "原有手記未能讀取，已保留原檔；未儲存文字仍在編輯區。"
            return false
        }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: file, options: .atomic)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "未能儲存手記，文字已保留：\(error.localizedDescription)"
            return false
        }
    }
}
