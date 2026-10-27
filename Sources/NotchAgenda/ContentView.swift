#if os(iOS)
import SwiftUI
import UIKit

private enum MobileContent: String, CaseIterable { case tasks, completed, diary }

struct ContentView: View {
    @Bindable var store: TaskStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var page = NotebookPage.day
    @State private var content = MobileContent.tasks
    @State private var date = Date()
    @State private var input = ""
    @State private var repetition = TaskRepeat.none
    @State private var settings = false
    @State private var trash = false
    @State private var editing: TaskItem?
    private var prefs: AppPreferences { store.preferences }
    private var palette: PaperPalette { prefs.appearance.palette }
    private var scope: TaskScope { page.scope }
    private var entries: [TaskOccurrence] {
        let carry = store.calendar.isDateInToday(date) && page != .calendar
        return content == .completed
            ? store.completedOccurrences(on: date, scope: scope, carryOver: carry)
            : store.pendingOccurrences(on: date, scope: scope, carryOver: carry)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heading
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 19) {
                            ForEach(NotebookPage.allCases) { item in
                                Button { page = item } label: {
                                    VStack(spacing: 7) {
                                        Text(prefs.text(item.title)).font(.subheadline.weight(page == item ? .semibold : .regular))
                                        Rectangle().fill(page == item ? palette.accent : .clear).frame(height: 2)
                                    }
                                }.buttonStyle(.plain).accessibilityIdentifier("journal.tab.\(item.id)")
                                    .accessibilityAddTraits(page == item ? [.isSelected] : [])
                            }
                        }
                    }
                    Picker(prefs.text("頁面內容"), selection: $content) {
                        Text(prefs.text("待辦事項")).tag(MobileContent.tasks)
                        Text(prefs.text("已完成")).tag(MobileContent.completed)
                        if scope != .anytime { Text(prefs.text("寫日記")).tag(MobileContent.diary) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("journal.content")
                    if page == .calendar {
                        DatePicker(prefs.text("選擇日期"), selection: $date, displayedComponents: .date).datePickerStyle(.graphical)
                    }
                    if content == .diary && scope != .anytime {
                        JournalEditor(journal: store.journal, date: date, scope: scope)
                            .id(store.journal.key(on: date, scope: scope))
                    } else {
                        if content == .tasks { composer }
                        if entries.isEmpty {
                            Text(prefs.text(content == .completed ? "還沒有已完成事項。" : "這一頁的待辦已清空。"))
                                .font(.system(.body, design: .serif)).foregroundStyle(palette.faint).padding(.vertical, 12)
                        }
                        ForEach(entries) { entry in
                            MobileTaskRow(entry: entry, store: store, edit: { editing = entry.task })
                        }
                    }
                }.padding(20).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background { RuledPaper().ignoresSafeArea().allowsHitTesting(false) }
            .navigationTitle("NotchAgenda").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(prefs.text("完成")) { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .accessibilityIdentifier("keyboard.done")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { trash = true } label: { Image(systemName: "trash") }
                        .accessibilityLabel(prefs.text("垃圾桶")).accessibilityIdentifier("trash.open")
                    Button { settings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(prefs.text("設定")).accessibilityIdentifier("settings.open")
                }
            }
            .sheet(isPresented: $settings) { AppSettingsView(preferences: prefs, close: { settings = false }) }
            .sheet(isPresented: $trash) { MobileTrashView(store: store) }
            .sheet(item: $editing) { MobilePlanEditor(task: $0, store: store) }
            .alert(prefs.text("儲存提示"), isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button(prefs.text("知道了")) { store.errorMessage = nil }
            } message: { Text(prefs.text(store.errorMessage ?? "")) }
        }
        .foregroundStyle(palette.ink).tint(palette.accent).preferredColorScheme(.light)
        .environment(\.paperPalette, palette).environment(\.notebookPaper, prefs.paper).environment(\.locale, prefs.locale)
        .onChange(of: page) { _, _ in
            if scope == .anytime && content == .diary { content = .tasks }
            if !scope.repeats.contains(repetition) { repetition = .none }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { store.journal.flushAllDrafts() } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in date = Date() }
    }
    private var heading: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(prefs.text(page.title)).font(.system(.largeTitle, design: .serif))
                Spacer()
                Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!store.canUndo).accessibilityLabel(prefs.text("復原上一步"))
            }
            if scope != .anytime {
                HStack {
                    Button { move(-1) } label: { Image(systemName: "chevron.left").padding(6) }
                        .accessibilityIdentifier("journal.previousDate").accessibilityLabel(prefs.text("上一頁日期"))
                    DatePicker(prefs.text("選擇日期"), selection: $date, displayedComponents: .date).labelsHidden().environment(\.colorScheme, prefs.appearance == .leather ? .dark : .light)
                    Spacer(minLength: 0)
                    Button { date = Date() } label: { Text(prefs.text("今天")) }.font(.caption)
                    Button { move(1) } label: { Image(systemName: "chevron.right").padding(6) }
                        .accessibilityIdentifier("journal.nextDate").accessibilityLabel(prefs.text("下一頁日期"))
                }.foregroundStyle(palette.coverMuted)
            }
        }.padding(16).foregroundStyle(palette.coverInk).background(palette.cover, in: RoundedRectangle(cornerRadius: 12))
            .overlay { NotebookCoverTrim(appearance: prefs.appearance) }
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(prefs.text("寫下下一件事")).font(.system(.headline, design: .serif))
            Text(prefs.text("每行一件")).font(.caption).foregroundStyle(palette.faint)
            TextEditor(text: $input).frame(minHeight: 75, maxHeight: 110).scrollContentBackground(.hidden)
                .padding(6).background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(palette.line, lineWidth: 0.7).allowsHitTesting(false) }
                .accessibilityIdentifier("journal.task.input").accessibilityLabel(prefs.text("批量新增待辦，每行一件"))
            if scope != .anytime {
                Picker(prefs.text("重複"), selection: $repetition) {
                    ForEach(scope.repeats) { Text(prefs.text($0.title)).tag($0) }
                }.accessibilityIdentifier("journal.repeat")
            }
            Button {
                if store.add(input, date: scope == .anytime ? nil : date, scope: scope, recurrence: repetition) { input = "" }
            } label: { Label(prefs.text("記下來"), systemImage: "plus").frame(maxWidth: .infinity).padding(5) }
                .buttonStyle(.borderedProminent).disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("journal.task.add")
        }
    }
    private func move(_ amount: Int) {
        let component: Calendar.Component = page == .calendar || scope == .month ? .month : scope == .week ? .weekOfYear : .day
        if let next = store.calendar.date(byAdding: component, value: amount, to: date) { date = next }
    }
}

private struct MobileTaskRow: View {
    let entry: TaskOccurrence
    let store: TaskStore
    let edit: () -> Void
    @Environment(\.paperPalette) private var palette
    @State private var offset: CGFloat = 0
    private var prefs: AppPreferences { store.preferences }
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button { complete(!entry.isCompleted) } label: {
                Image(systemName: entry.isCompleted ? "checkmark.square" : "square").font(.title3).frame(width: 44, height: 44)
            }.buttonStyle(.plain).accessibilityLabel(prefs.text(entry.isCompleted ? "移回待辦" : "完成事項"))
                .accessibilityIdentifier("task.complete.\(entry.task.id)")
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.task.title).font(.system(.body, design: .serif)).strikethrough(entry.isCompleted)
                    .foregroundStyle(entry.isCompleted ? palette.faint : palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let date = entry.date {
                    Text(date.formatted(.dateTime.month().day().locale(prefs.locale))).font(.caption).foregroundStyle(palette.faint)
                }
                if entry.task.recurrence != .none { Text(prefs.text(entry.task.recurrence.title)).font(.caption2).foregroundStyle(palette.faint) }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
            Menu {
                Button(prefs.text("安排日期"), action: edit)
                if !entry.isCompleted { Button(prefs.text("移到隊尾")) { store.later(entry.task) } }
                Button(prefs.text("刪除"), role: .destructive) { store.delete(entry.task) }
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                .accessibilityLabel(prefs.text("事項選項"))
        }.padding(7).background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 10)).offset(x: offset)
            .simultaneousGesture(DragGesture(minimumDistance: 30).onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) * 1.5 { offset = value.translation.width }
            }.onEnded { value in
                if abs(value.translation.width) > abs(value.translation.height) * 1.5 {
                    if value.translation.width > 100 && !entry.isCompleted { complete(true) }
                    else if value.translation.width < -100 && !entry.isCompleted { store.later(entry.task) }
                }
                withAnimation { offset = 0 }
            })
    }
    private func complete(_ completed: Bool) {
        _ = store.setCompleted(entry.task, occurrenceDate: entry.date, completed: completed)
    }
}

private struct MobileTrashView: View {
    let store: TaskStore
    @Environment(\.dismiss) private var dismiss
    private var prefs: AppPreferences { store.preferences }
    var body: some View {
        NavigationStack {
            List {
                if store.deletedTasks.isEmpty { Text(prefs.text("垃圾桶是空的")) }
                ForEach(store.deletedTasks) { task in
                    HStack {
                        Text(task.title)
                        Spacer()
                        Button(prefs.text("還原")) { store.restore(task) }.buttonStyle(.bordered)
                    }
                }
            }.navigationTitle(prefs.text("垃圾桶"))
                .toolbar { Button(prefs.text("完成")) { dismiss() }.accessibilityIdentifier("trash.close") }
        }.environment(\.locale, prefs.locale)
    }
}

private struct MobilePlanEditor: View {
    let task: TaskItem
    let store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var scope: TaskScope
    @State private var date: Date
    @State private var recurrence: TaskRepeat
    private var prefs: AppPreferences { store.preferences }
    init(task: TaskItem, store: TaskStore) {
        self.task = task; self.store = store
        _scope = State(initialValue: task.scope)
        _date = State(initialValue: task.date ?? Date())
        _recurrence = State(initialValue: task.recurrence)
    }
    var body: some View {
        NavigationStack {
            Form {
                Text(task.title)
                Picker(prefs.text("目標類型"), selection: $scope) { ForEach(TaskScope.allCases) { Text(prefs.text($0.title)).tag($0) } }
                if scope != .anytime {
                    DatePicker(prefs.text("安排日期"), selection: $date, displayedComponents: .date)
                    Picker(prefs.text("重複"), selection: $recurrence) { ForEach(scope.repeats) { Text(prefs.text($0.title)).tag($0) } }
                }
            }.navigationTitle(prefs.text("安排日期"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(prefs.text("取消")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(prefs.text("儲存安排")) {
                            if store.updatePlan(task, scope: scope, date: scope == .anytime ? nil : date, recurrence: recurrence) { dismiss() }
                        }
                    }
                }.onChange(of: scope) { _, newScope in if !newScope.repeats.contains(recurrence) { recurrence = .none } }
        }.environment(\.locale, prefs.locale)
    }
}
#endif
