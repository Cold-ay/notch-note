import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

enum TaskScope: String, Codable, CaseIterable, Identifiable {
    case day, week, month, anytime
    var id: String { rawValue }
    var title: String {
        switch self { case .day: "日事項"; case .week: "週目標"; case .month: "月目標"; case .anytime: "待完成" }
    }
    var repeats: [TaskRepeat] {
        switch self {
        case .day: [.none, .daily, .weekly, .monthly]
        case .week: [.none, .weekly]
        case .month: [.none, .monthly]
        case .anytime: [.none]
        }
    }
}

enum TaskRepeat: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly, monthly
    var id: String { rawValue }
    var title: String {
        switch self { case .none: "不重複"; case .daily: "每天"; case .weekly: "每週"; case .monthly: "每月" }
    }
}

struct TaskItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var date: Date?
    var completed = false
    var createdAt: Date? = Date()
    var completedAt: Date?
    var records: [TaskRecord] = []
    var scope: TaskScope
    var recurrence: TaskRepeat
    var repeatEnd: Date?
    var deletedAt: Date?
    var pendingOccurrences: [Date] = []

    init(title: String, date: Date? = nil, createdAt: Date = Date(), scope: TaskScope = .anytime, recurrence: TaskRepeat = .none) {
        self.title = title
        self.date = date
        self.createdAt = createdAt
        self.scope = scope
        self.recurrence = recurrence
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        date = try values.decodeIfPresent(Date.self, forKey: .date)
        completed = try values.decode(Bool.self, forKey: .completed)
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt)
        completedAt = try values.decodeIfPresent(Date.self, forKey: .completedAt)
        records = try values.decodeIfPresent([TaskRecord].self, forKey: .records) ?? []
        // Keep undated legacy tasks in the new inbox, rather than assign a fictional date.
        scope = try values.decodeIfPresent(TaskScope.self, forKey: .scope) ?? (date == nil ? .anytime : .day)
        recurrence = try values.decodeIfPresent(TaskRepeat.self, forKey: .recurrence) ?? .none
        repeatEnd = try values.decodeIfPresent(Date.self, forKey: .repeatEnd)
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
        if let pending = try values.decodeIfPresent([Date].self, forKey: .pendingOccurrences) {
            pendingOccurrences = pending
        } else if recurrence != .none {
            // Read old audit logs once, preserving which recurring periods are pending.
            var latest: [Date: TaskRecord.Action] = [:]
            for record in records {
                if let date = record.occurrenceDate { latest[date] = record.action }
            }
            pendingOccurrences = latest.filter { $0.value == .reopened }.map(\.key)
        }
        // Retain completion snapshots, with at most one per task/recurring period.
        var seen = Set<String>()
        records = records.reversed().filter { record in
            guard record.action == .completed else { return false }
            let key = recurrence == .none ? "single" : record.occurrenceDate?.timeIntervalSince1970.description ?? "legacy"
            return seen.insert(key).inserted
        }.reversed()
    }
}

struct TaskRecord: Identifiable, Codable, Equatable {
    enum Action: String, Codable { case completed, reopened } // reopened is decode-only legacy data.
    var id = UUID()
    let title: String
    let timestamp: Date
    let action: Action
    var occurrenceDate: Date?
    var scope: TaskScope?
}

struct TaskOccurrence: Identifiable, Equatable {
    let task: TaskItem
    let date: Date?
    let isCompleted: Bool
    let completedAt: Date?
    var id: String { "\(task.id.uuidString)/\(date?.timeIntervalSince1970.description ?? "anytime")" }
}

extension Calendar {
    static var taskCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // A goal week runs Monday through Sunday.
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}

@MainActor @Observable final class TaskStore {
    private(set) var tasks: [TaskItem] = []
    var errorMessage: String?
    private var previous: [TaskItem]?
    private let file: URL
    private let now: () -> Date
    let calendar: Calendar
    let journal: JournalStore
    let preferences: AppPreferences
    private var loadFailed = false
    var canUndo: Bool { previous != nil }
    var activeTasks: [TaskItem] { tasks.filter { $0.deletedAt == nil } }
    var deletedTasks: [TaskItem] { tasks.filter { $0.deletedAt != nil }.sorted { $0.deletedAt! > $1.deletedAt! } }
    var pending: [TaskItem] {
        activeTasks.filter { task in
            if task.recurrence == .none { return !task.completed }
            return occurrence(for: task, on: now(), carryOver: false).map { !$0.isCompleted } ?? false
        }
    }

    init(file: URL? = nil, now: @escaping () -> Date = Date.init, calendar: Calendar = .taskCalendar) {
        self.file = file ?? Self.storageURL
        self.now = now
        self.calendar = calendar
        preferences = AppPreferences(file: self.file.deletingLastPathComponent().appendingPathComponent("preferences.json"))
        journal = JournalStore(file: self.file.deletingLastPathComponent().appendingPathComponent("journal.json"), now: now, calendar: calendar, preferences: preferences)
        do {
            if FileManager.default.fileExists(atPath: self.file.path) {
                tasks = try JSONDecoder().decode([TaskItem].self, from: Data(contentsOf: self.file))
            }
        } catch {
            loadFailed = true
            errorMessage = "未能讀取待辦，已停止寫入以保留原檔：\(error.localizedDescription)"
        }
    }

    static var storageURL: URL {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing"),
           let token = ProcessInfo.processInfo.environment["NOTCHAGENDA_TEST_STORE"], UUID(uuidString: token) != nil {
            return FileManager.default.temporaryDirectory.appendingPathComponent("NotchAgendaUITests").appendingPathComponent(token).appendingPathComponent("tasks.json")
        }
        // The QA app uses an isolated file and never touches the user's journal.
        if let path = (ProcessInfo.processInfo.environment["NOTCHAGENDA_DATA_FILE"] ?? ProcessInfo.processInfo.environment["FLOWTASKS_DATA_FILE"]) { return URL(fileURLWithPath: path) }
        #endif
        #if os(iOS)
        let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.colday.notchagenda") ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #else
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FlowTasks")
        #endif
        return root.appendingPathComponent("tasks.json")
    }

    func widgetOccurrences(on date: Date) -> [TaskOccurrence] {
        TaskScope.allCases.flatMap { pendingOccurrences(on: date, scope: $0, carryOver: true) }
    }

    func interval(for date: Date, scope: TaskScope) -> DateInterval {
        let component: Calendar.Component = scope == .week ? .weekOfYear : scope == .month ? .month : .day
        return calendar.dateInterval(of: component, for: date)!
    }

    func occurrences(on day: Date, scope: TaskScope, carryOver: Bool = false) -> [TaskOccurrence] {
        activeTasks.filter { $0.scope == scope }.compactMap { occurrence(for: $0, on: day, carryOver: carryOver) }
    }

    func occurrence(for task: TaskItem, on day: Date, carryOver: Bool = false) -> TaskOccurrence? {
        guard task.deletedAt == nil else { return nil }
        if task.scope == .anytime {
            return TaskOccurrence(task: task, date: nil, isCompleted: task.completed, completedAt: task.completedAt)
        }
        let anchor = interval(for: task.date ?? task.createdAt ?? day, scope: task.scope).start
        let period = interval(for: day, scope: task.scope)
        let key: Date
        if task.recurrence == .none {
            let completedInPeriod = task.completedAt.map { $0 >= period.start && $0 < period.end } ?? false
            guard anchor == period.start || (carryOver && anchor < period.start && !task.completed) || (task.completed && completedInPeriod) else { return nil }
            return TaskOccurrence(task: task, date: anchor, isCompleted: task.completed, completedAt: task.completedAt)
        } else {
            key = period.start
            guard key >= anchor, task.repeatEnd.map({ key <= $0 }) ?? true else { return nil }
            if task.scope == .day {
                let original = task.date ?? task.createdAt ?? day
                switch task.recurrence {
                case .none: return nil
                case .daily: break
                case .weekly:
                    guard calendar.component(.weekday, from: original) == calendar.component(.weekday, from: day) else { return nil }
                case .monthly:
                    let lastDay = calendar.range(of: .day, in: .month, for: day)!.count
                    guard calendar.component(.day, from: day) == min(calendar.component(.day, from: original), lastDay) else { return nil }
                }
            }
        }
        let latest = task.records.last { record in
            record.occurrenceDate.map { calendar.isDate($0, inSameDayAs: key) } ?? false
        }
        let returnedToPending = task.pendingOccurrences.contains { calendar.isDate($0, inSameDayAs: key) }
        let completed = latest?.action == .completed && !returnedToPending
        return TaskOccurrence(task: task, date: key, isCompleted: completed, completedAt: completed ? latest?.timestamp : nil)
    }

    func records(on date: Date, scope: TaskScope? = nil) -> [TaskRecord] {
        let period = interval(for: date, scope: scope ?? .day)
        return tasks.flatMap { task in
            task.records.filter { record in
                record.timestamp >= period.start && record.timestamp < period.end && (scope == nil || (record.scope ?? task.scope) == scope)
            }
        }.sorted { $0.timestamp < $1.timestamp }
    }

    func pendingOccurrences(on date: Date, scope: TaskScope, carryOver: Bool = false) -> [TaskOccurrence] {
        occurrences(on: date, scope: scope, carryOver: carryOver).filter { !$0.isCompleted }
    }

    func completedOccurrences(on date: Date, scope: TaskScope, carryOver: Bool = false) -> [TaskOccurrence] {
        occurrences(on: date, scope: scope, carryOver: carryOver).filter(\.isCompleted)
    }

    @discardableResult func returnToPending(_ entry: TaskOccurrence) -> Bool {
        setCompleted(entry.task, occurrenceDate: entry.date, completed: false)
    }

    @discardableResult func add(_ text: String, date: Date?, scope: TaskScope? = nil, recurrence: TaskRepeat = .none) -> Bool {
        let scope = scope ?? (date == nil ? .anytime : .day)
        guard scope.repeats.contains(recurrence) else { errorMessage = "這個目標類型不支援所選重複方式。"; return false }
        let timestamp = now()
        let scheduled = scope == .anytime ? nil : interval(for: date ?? timestamp, scope: scope).start
        let additions = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            .map { TaskItem(title: $0, date: scheduled, createdAt: timestamp, scope: scope, recurrence: recurrence) }
        guard !additions.isEmpty else { return false }
        return change { $0.append(contentsOf: additions) }
    }

    // Compatibility entry point for the iPhone prototype. Mac controls pass explicit state.
    func complete(_ task: TaskItem) {
        guard let current = tasks.first(where: { $0.id == task.id }) else { return }
        let occurrence = occurrence(for: current, on: now(), carryOver: true)
        setCompleted(current, occurrenceDate: occurrence?.date, completed: !(occurrence?.isCompleted ?? current.completed))
    }

    @discardableResult func setCompleted(_ task: TaskItem, occurrenceDate: Date?, completed: Bool) -> Bool {
        guard let current = tasks.first(where: { $0.id == task.id }), current.deletedAt == nil else { return false }
        let occurrence: TaskOccurrence?
        if current.recurrence == .none {
            occurrence = TaskOccurrence(task: current, date: current.date, isCompleted: current.completed, completedAt: current.completedAt)
        } else {
            occurrence = self.occurrence(for: current, on: occurrenceDate ?? now())
        }
        guard let occurrence else { return false }
        if occurrence.isCompleted == completed { return true } // Idempotent, even with stale UI callbacks.
        let timestamp = now()
        return change { items in
            guard let i = items.firstIndex(where: { $0.id == current.id }) else { return }
            if current.recurrence == .none {
                items[i].completed = completed
                items[i].completedAt = completed ? timestamp : nil
            }
            if current.recurrence != .none, let date = occurrence.date {
                items[i].pendingOccurrences.removeAll { calendar.isDate($0, inSameDayAs: date) }
                if !completed { items[i].pendingOccurrences.append(date) }
            }
            if completed {
                let existing = items[i].records.first { record in
                    current.recurrence == .none || record.occurrenceDate == occurrence.date
                }
                items[i].records.removeAll { record in
                    current.recurrence == .none || record.occurrenceDate == occurrence.date
                }
                items[i].records.append(TaskRecord(id: existing?.id ?? UUID(), title: current.title, timestamp: timestamp, action: .completed, occurrenceDate: occurrence.date, scope: current.scope))
            }
        }
    }

    func later(_ task: TaskItem) {
        guard activeTasks.contains(where: { $0.id == task.id }) else { return }
        change { items in
            guard let i = items.firstIndex(where: { $0.id == task.id }) else { return }
            items.append(items.remove(at: i))
        }
    }

    func schedule(_ task: TaskItem, date: Date?) {
        updatePlan(task, scope: date == nil ? .anytime : .day, date: date, recurrence: .none)
    }

    @discardableResult func updatePlan(_ task: TaskItem, scope: TaskScope, date: Date?, recurrence: TaskRepeat) -> Bool {
        guard scope.repeats.contains(recurrence) else { return false }
        // A recurring series has historical occurrence keys. Change its end, not its anchor.
        guard let current = tasks.first(where: { $0.id == task.id }), current.deletedAt == nil, current.recurrence == .none else { return false }
        return change { items in
            guard let i = items.firstIndex(where: { $0.id == task.id }) else { return }
            items[i].scope = scope
            items[i].date = scope == .anytime ? nil : interval(for: date ?? now(), scope: scope).start
            items[i].recurrence = recurrence
            if recurrence != .none { items[i].completed = false; items[i].completedAt = nil }
        }
    }

    func stopRepeating(_ task: TaskItem) {
        guard task.recurrence != .none, activeTasks.contains(where: { $0.id == task.id }) else { return }
        change { items in
            if let i = items.firstIndex(where: { $0.id == task.id }) {
                items[i].repeatEnd = interval(for: now(), scope: task.scope).start
            }
        }
    }

    @discardableResult func delete(_ task: TaskItem) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == task.id && $0.deletedAt == nil }) else { return false }
        return change { $0[index].deletedAt = now() }
    }

    @discardableResult func restore(_ task: TaskItem) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == task.id && $0.deletedAt != nil }) else { return false }
        return change { $0[index].deletedAt = nil }
    }

    func undo() {
        guard let previous else { return }
        if persist(previous) { tasks = previous; self.previous = nil }
    }
    @discardableResult private func change(_ mutation: (inout [TaskItem]) -> Void) -> Bool {
        var next = tasks
        mutation(&next)
        if persist(next) { previous = tasks; tasks = next; return true }
        return false
    }
    private func persist(_ value: [TaskItem]) -> Bool {
        guard !loadFailed else {
            errorMessage = "原有資料未能讀取，已保留原檔。請修復資料後重新開啟 App。"
            return false
        }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: file, options: .atomic)
            errorMessage = nil
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            return true
        } catch { errorMessage = "未能儲存待辦：\(error.localizedDescription)"; return false }
    }
}
