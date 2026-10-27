import SwiftUI
import WidgetKit

struct WidgetItem: Identifiable, Sendable {
    let id: String
    let title: String
}
struct TaskEntry: TimelineEntry, Sendable {
    let date: Date
    let tasks: [WidgetItem]
    let language: AppLanguage
}
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: .now, tasks: [WidgetItem(id: "preview", title: "準備今天最重要的事")], language: .traditionalChinese)
    }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (TaskEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { @MainActor in completion(read()) }
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TaskEntry>) -> Void) {
        Task { @MainActor in
            let entry = read()
            let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: entry.date)) ?? entry.date.addingTimeInterval(900)
            let next = min(entry.date.addingTimeInterval(900), midnight)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
    @MainActor private func read() -> TaskEntry {
        let store = TaskStore()
        let date = Date()
        let tasks = store.widgetOccurrences(on: date).map { WidgetItem(id: $0.id, title: $0.task.title) }
        return TaskEntry(date: date, tasks: tasks, language: store.preferences.language)
    }
}
struct WidgetView: View {
    let entry: TaskEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NotchAgenda").font(.caption.bold())
                Spacer()
                Text("\(entry.tasks.count)").font(.caption.bold())
            }.foregroundStyle(Color(red: 0.58, green: 0.30, blue: 0.22))
            if entry.tasks.isEmpty { Text(entry.language.text("這一頁的待辦已清空。")).font(.headline) }
            ForEach(Array(entry.tasks.prefix(family == .systemSmall ? 2 : 3))) { task in
                HStack(alignment: .top) {
                    Image(systemName: "square")
                    Text(task.title).font(.subheadline).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Text(entry.language.text("點開清單，逐件完成 →")).font(.caption2).foregroundStyle(.secondary)
        }.containerBackground(Color(red: 0.98, green: 0.96, blue: 0.91), for: .widget)
    }
}
@main struct NotchAgendaWidget: Widget {
    let kind = "NotchAgendaWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in WidgetView(entry: entry) }
            .configurationDisplayName("NotchAgenda")
            .description("Today's tasks and goals. Tap to open your notebook.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
