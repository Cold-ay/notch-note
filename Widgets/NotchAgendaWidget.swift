import SwiftUI
import WidgetKit

struct WidgetTask: Decodable, Identifiable {
    let id: UUID
    let title: String
    let date: Date?
    let completed: Bool
    var deletedAt: Date? = nil
}
struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
}
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry { TaskEntry(date: .now, tasks: [WidgetTask(id: UUID(), title: "準備今天最重要的事", date: nil, completed: false)]) }
    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) { completion(context.isPreview ? placeholder(in: context) : read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        completion(Timeline(entries: [read()], policy: .after(Date().addingTimeInterval(900))))
    }
    private func read() -> TaskEntry {
        let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.flowtasks")
        let data = root.flatMap { try? Data(contentsOf: $0.appendingPathComponent("tasks.json")) }
        let tasks = data.flatMap { try? JSONDecoder().decode([WidgetTask].self, from: $0) } ?? []
        return TaskEntry(date: .now, tasks: tasks.filter { !$0.completed && $0.deletedAt == nil })
    }
}
struct WidgetView: View {
    let entry: TaskEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NotchAgenda").font(.caption.bold()).foregroundStyle(.indigo)
                Spacer()
                Text("\(entry.tasks.count)").font(.caption.bold())
            }
            if entry.tasks.isEmpty { Text("留點空間給自己。\n點一下，加入待辦。").font(.headline) }
            ForEach(Array(entry.tasks.prefix(family == .systemSmall ? 2 : 3))) { task in
                HStack(alignment: .top) {
                    Image(systemName: "circle").foregroundStyle(.indigo)
                    Text(task.title).font(.subheadline).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Text("點開清單，逐件完成 →").font(.caption2).foregroundStyle(.secondary)
        }.containerBackground(.fill.tertiary, for: .widget)
    }
}
@main struct NotchAgendaWidget: Widget {
    let kind = "NotchAgendaWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in WidgetView(entry: entry) }
            .configurationDisplayName("下一件待辦")
            .description("把重要的事放在主畫面，點開 App 逐件完成。")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
