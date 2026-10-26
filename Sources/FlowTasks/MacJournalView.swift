#if os(macOS)
import AppKit
import CoreText
import SwiftUI

private enum Paper {
    static let sheet = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let ink = Color(red: 0.25, green: 0.25, blue: 0.22)
    static let faint = Color(red: 0.49, green: 0.47, blue: 0.41)
    static let accent = Color(red: 0.58, green: 0.30, blue: 0.22)
    static let line = Color(red: 0.76, green: 0.78, blue: 0.73)
}

private enum JournalPage: String, CaseIterable, Identifiable {
    case day = "日記", week = "週目標", month = "月目標", anytime = "待完成", calendar = "日曆"
    var id: String { rawValue }
    var scope: TaskScope {
        switch self { case .day, .calendar: .day; case .week: .week; case .month: .month; case .anytime: .anytime }
    }
    static func page(for scope: TaskScope) -> Self {
        switch scope { case .day: .day; case .week: .week; case .month: .month; case .anytime: .anytime }
    }
}

struct MacJournalView: View {
    @Bindable var store: TaskStore
    var floating = false
    var dismiss: (() -> Void)?
    @State private var input = ""
    @State private var page = Date()
    @State private var lastToday = Date()
    @State private var section = JournalPage.day
    @State private var draftScope = TaskScope.day
    @State private var plannedDate = Date()
    @State private var repetition = TaskRepeat.none
    @State private var choosingDate = false
    @State private var editing: TaskItem?
    @State private var showHistory = false
    @FocusState private var writing: Bool
    private var isToday: Bool { store.calendar.isDateInToday(page) }
    private var entries: [TaskOccurrence] {
        store.occurrences(on: page, scope: section.scope, carryOver: isToday && section != .calendar)
    }
    private var records: [TaskRecord] {
        if section == .anytime { return store.tasks.filter { $0.scope == .anytime }.flatMap(\.records).sorted { $0.timestamp < $1.timestamp } }
        return store.records(on: page, scope: section == .week || section == .month ? section.scope : nil)
    }
    private var inputCount: Int { input.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }
    private var heading: String {
        switch section {
        case .day, .calendar: isToday ? "留給今天的事" : page.formatted(.dateTime.month().day()) + " 的事項"
        case .week: "這一週，想做到的事"
        case .month: "這個月，慢慢靠近的目標"
        case .anytime: "還沒定日子，也值得記下"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            navigation
            Rectangle().fill(Paper.line.opacity(0.6)).frame(height: 1)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if section == .calendar {
                        JournalCalendar(date: $page, store: store).padding(.horizontal, 24).padding(.top, 12)
                    }
                    sectionHeading(heading, detail: "\(entries.filter(\.isCompleted).count) / \(entries.count)")
                    if entries.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(section == .anytime ? "先收下念頭，日子可以慢慢選。" : "這一頁，還有空白。").font(.system(size: 15, design: .serif))
                            Text("在下面寫下事項，再選擇日期或目標類型。").font(.system(size: 11)).foregroundStyle(Paper.faint)
                        }.padding(.leading, 38).padding(.trailing, 24).padding(.vertical, 18)
                    }
                    // Completed rows stay in place: no moving target beneath a second click.
                    ForEach(entries) { entry in
                        JournalTaskRow(entry: entry, store: store, edit: { editing = entry.task })
                    }
                    if !records.isEmpty {
                        DisclosureGroup(isExpanded: $showHistory) {
                            ForEach(records) { record in JournalRecordRow(record: record) }
                        } label: {
                            Text("日記紀錄 · \(records.count)").font(.system(size: 11, weight: .medium)).foregroundStyle(Paper.faint)
                        }.padding(.horizontal, 24).padding(.top, 22)
                    }
                }.padding(.bottom, 22)
            }
            .background { RuledPaper().allowsHitTesting(false).accessibilityHidden(true) }
            if let error = store.errorMessage {
                HStack(alignment: .top) {
                    Text(error).font(.caption).textSelection(.enabled)
                    Spacer()
                    Button("關閉") { store.errorMessage = nil }
                }.padding(12).foregroundStyle(Color.red).background(Paper.sheet)
            }
            composer
        }
        .foregroundStyle(Paper.ink).background(Paper.sheet)
        .clipShape(RoundedRectangle(cornerRadius: floating ? 20 : 0))
        .overlay { if floating { RoundedRectangle(cornerRadius: 20).strokeBorder(Paper.line.opacity(0.65), lineWidth: 1).allowsHitTesting(false) } }
        .tint(Paper.accent).preferredColorScheme(.light)
        .frame(minWidth: 400, minHeight: 600)
        .sheet(item: $editing) { task in TaskPlanEditor(task: task, store: store) }
        .onChange(of: section) { _, newSection in
            draftScope = newSection.scope
            if !draftScope.repeats.contains(repetition) { repetition = .none }
            plannedDate = page
        }
        .onChange(of: page) { _, day in plannedDate = day }
        .onChange(of: draftScope) { _, scope in
            if !scope.repeats.contains(repetition) { repetition = .none }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            if store.calendar.isDate(page, inSameDayAs: lastToday) { page = Date() }
            lastToday = Date()
        }
    }

    private var navigation: some View {
        HStack(spacing: 0) {
            ForEach(JournalPage.allCases) { item in
                Button { section = item } label: {
                    VStack(spacing: 9) {
                        HStack(spacing: 3) {
                            Text(item.rawValue)
                            if item == .anytime {
                                let count = store.tasks.filter { $0.scope == .anytime && !$0.completed }.count
                                if count > 0 { Text("\(count)").font(.system(size: 9, design: .monospaced)) }
                            }
                        }.font(.system(size: 11, weight: item == section ? .semibold : .regular))
                        Rectangle().fill(item == section ? Paper.accent : .clear).frame(height: 2)
                    }.padding(.top, 10).frame(maxWidth: .infinity).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(item == section ? Paper.accent : Paper.faint)
                    .accessibilityIdentifier("journal.tab.\(item.id)").accessibilityAddTraits(item == section ? [.isSelected] : [])
            }
        }.padding(.horizontal, 18)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                Image(systemName: "book.closed").font(.system(size: 12))
                Text("FLOWTASKS / 日常手記").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.2)
                Spacer()
                if floating {
                    Capsule().fill(Paper.faint.opacity(0.3)).frame(width: 30, height: 3)
                        .frame(width: 52, height: 22).overlay { JournalDragHandle() }.help("拖動面板")
                }
                if let dismiss {
                    Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 11)).frame(width: 26, height: 26) }
                        .buttonStyle(.plain).help("隱藏面板；從選單列重新打開").accessibilityLabel("隱藏浮動日記")
                }
            }.foregroundStyle(Paper.faint)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(headerTitle).font(.system(size: 27, weight: .regular, design: .serif))
                    Text(headerDetail).font(.system(size: 10, design: .monospaced)).foregroundStyle(Paper.faint)
                }
                Spacer(minLength: 4)
                if section != .anytime {
                    HStack(spacing: 7) {
                        Button { movePage(-1) } label: { Image(systemName: "chevron.left").frame(width: 22, height: 28) }.accessibilityLabel("上一頁日期")
                        Button { choosingDate.toggle() } label: { Image(systemName: "calendar").frame(width: 22, height: 28) }.accessibilityLabel("選擇日期")
                            .popover(isPresented: $choosingDate) {
                                VStack {
                                    DatePicker("選擇日期", selection: $page, displayedComponents: .date).datePickerStyle(.graphical)
                                    Button("回到今天") { page = Date(); choosingDate = false }
                                }.padding(16).frame(width: 300)
                            }
                        Button { movePage(1) } label: { Image(systemName: "chevron.right").frame(width: 22, height: 28) }.accessibilityLabel("下一頁日期")
                    }.buttonStyle(.plain).foregroundStyle(Paper.faint)
                }
            }
            HStack(spacing: 6) {
                Circle().fill(Paper.accent).frame(width: 5, height: 5)
                Text(section == .anytime ? "暫時沒有期限，仍然記在心上。" : "\(entries.filter { !$0.isCompleted }.count) 件待完成 · 劃過的事，留在這一頁。")
                Spacer(minLength: 0)
                if !isToday && section != .anytime { Button("今天") { page = Date() }.buttonStyle(.plain).foregroundStyle(Paper.accent) }
            }.font(.system(size: 10)).foregroundStyle(Paper.faint)
        }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 10)
    }

    private var headerTitle: String {
        switch section {
        case .anytime: "有一天，會做到。"
        case .month, .calendar: page.formatted(.dateTime.year().month(.wide))
        case .week: "這一週的目標"
        case .day: page.formatted(.dateTime.month(.wide).day())
        }
    }
    private var headerDetail: String {
        if section == .anytime { return "沒有期限 / 隨時安排日期" }
        if section == .week {
            let period = store.interval(for: page, scope: .week)
            let end = store.calendar.date(byAdding: .day, value: -1, to: period.end)!
            return period.start.formatted(.dateTime.month().day()) + " – " + end.formatted(.dateTime.month().day()) + " · 週一至週日"
        }
        return page.formatted(.dateTime.year().weekday(.wide))
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("寫下接下來的事", systemImage: "pencil.tip").font(.system(size: 11, weight: .medium))
                Spacer()
                Text("每行一件").font(.system(size: 10)).foregroundStyle(Paper.faint)
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $input).font(.system(size: 14, design: .serif)).scrollContentBackground(.hidden)
                    .focused($writing).padding(.horizontal, 3).padding(.vertical, 5)
                    .accessibilityLabel("寫下待辦，每行一件").accessibilityIdentifier("journal.input")
                if input.isEmpty {
                    Text("讀十頁書，或每天練習 Duolingo…").font(.system(size: 13, design: .serif)).foregroundStyle(Paper.faint.opacity(0.65))
                        .padding(.leading, 8).padding(.top, 8).allowsHitTesting(false).accessibilityHidden(true)
                }
            }.frame(height: 56).background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(writing ? Paper.accent.opacity(0.6) : Paper.line.opacity(0.7), lineWidth: 1).allowsHitTesting(false) }
            HStack(spacing: 9) {
                Picker("類型", selection: $draftScope) { ForEach(TaskScope.allCases) { Text($0.title).tag($0) } }
                    .labelsHidden().frame(width: 103).accessibilityLabel("新增事項類型")
                if draftScope != .anytime {
                    DatePicker("安排日期", selection: $plannedDate, displayedComponents: .date).labelsHidden().datePickerStyle(.field)
                        .accessibilityLabel("安排日期；週月目標會歸入該日期所屬週月")
                } else {
                    Text("沒有完成期限").font(.system(size: 10)).foregroundStyle(Paper.faint)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 7) {
                if draftScope != .anytime {
                    Picker("重複", selection: $repetition) { ForEach(draftScope.repeats) { Text($0.title).tag($0) } }
                        .font(.system(size: 10)).frame(width: 140).accessibilityLabel("重複方式")
                }
                Spacer(minLength: 0)
                Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }.buttonStyle(.plain).disabled(!store.canUndo).help("撤回最後一步")
                Button(action: addTasks) {
                    Text(inputCount > 1 ? "記下 \(inputCount) 件" : "記下來").font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 8).foregroundStyle(.white)
                        .background(Paper.accent.opacity(inputCount == 0 ? 0.4 : 1), in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).disabled(inputCount == 0).keyboardShortcut(.return, modifiers: .command).help("⌘ Enter 加入")
                    .accessibilityIdentifier("journal.add")
            }
        }.padding(.horizontal, 24).padding(.top, 13).padding(.bottom, 16)
            .background(Paper.sheet.shadow(color: .black.opacity(0.04), radius: 6, y: -3))
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .medium))
            Spacer()
            Text(detail).font(.system(size: 10, design: .monospaced))
        }.foregroundStyle(Paper.faint).padding(.leading, 38).padding(.trailing, 25).padding(.top, 20).padding(.bottom, 10)
    }
    private func movePage(_ delta: Int) {
        let component: Calendar.Component = section == .week ? .weekOfYear : section == .month || section == .calendar ? .month : .day
        if let next = store.calendar.date(byAdding: component, value: delta, to: page) { page = next }
    }
    private func addTasks() {
        if store.add(input, date: draftScope == .anytime ? nil : plannedDate, scope: draftScope, recurrence: repetition) {
            input = ""
            if section.scope != draftScope { section = .page(for: draftScope) }
            page = plannedDate
            writing = true
        }
    }
}

// Native controls accept the first click in an inactive floating panel. No parent drag
// recognizer or text-selection view wraps the checkbox, and its entire 32pt bounds hit.
struct JournalCheckbox: NSViewRepresentable {
    var completed: Bool
    var label: String
    var action: (Bool) -> Bool
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeNSView(context: Context) -> FirstClickCheckboxButton {
        let button = FirstClickCheckboxButton()
        button.setButtonType(.switch)
        button.title = ""
        button.imagePosition = .imageOnly
        button.controlSize = .regular
        button.contentTintColor = NSColor(red: 0.58, green: 0.30, blue: 0.22, alpha: 1)
        button.target = context.coordinator
        button.action = #selector(Coordinator.changed(_:))
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }
    func updateNSView(_ button: FirstClickCheckboxButton, context: Context) {
        context.coordinator.action = action
        button.state = completed ? .on : .off
        button.setAccessibilityLabel(label)
        button.setAccessibilityIdentifier("journal.checkbox")
        button.toolTip = completed ? "重新開啟，保留原本紀錄" : "完成，留下鉛筆筆跡"
    }
    @MainActor final class Coordinator: NSObject {
        var action: (Bool) -> Bool
        init(action: @escaping (Bool) -> Bool) { self.action = action }
        @objc func changed(_ sender: NSButton) {
            let checked = sender.state == .on
            if !action(checked) { sender.state = checked ? .off : .on }
        }
    }
}

final class FirstClickCheckboxButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, isEnabled, frame.contains(point) else { return nil }
        return self
    }
}

private struct JournalTaskRow: View {
    let entry: TaskOccurrence
    let store: TaskStore
    let edit: () -> Void
    @State private var dragOffset: CGFloat = 0
    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            JournalCheckbox(completed: entry.isCompleted, label: (entry.isCompleted ? "重新開啟 " : "完成 ") + entry.task.title) { target in
                store.setCompleted(entry.task, occurrenceDate: entry.date, completed: target)
            }.frame(width: 32, height: 32).padding(.top, -5)
            VStack(alignment: .leading, spacing: 6) {
                if entry.isCompleted { PencilTitle(title: entry.task.title) }
                else { Text(entry.task.title).font(.system(size: 15, design: .serif)).lineSpacing(5).fixedSize(horizontal: false, vertical: true) }
                Text(detail).font(.system(size: 10)).foregroundStyle(Paper.faint)
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 5) {
                Menu {
                    if entry.task.recurrence == .none {
                        Button("安排日期／改成目標／設定重複", action: edit)
                    } else if entry.task.repeatEnd == nil {
                        Button("本期後停止重複，保留紀錄") { store.stopRepeating(entry.task) }
                    }
                    Button("移到清單尾端") { store.later(entry.task) }
                } label: { Image(systemName: "ellipsis").frame(width: 22, height: 20) }
                    .menuStyle(.borderlessButton).fixedSize().help("事項設定").accessibilityLabel("設定 \(entry.task.title)")
                Image(systemName: "line.3.horizontal").font(.system(size: 10)).foregroundStyle(Paper.faint.opacity(0.6))
                    .frame(width: 24, height: 18).contentShape(Rectangle()).help("只在此把手拖動：右滑完成，左滑移到隊尾")
                    .gesture(DragGesture(minimumDistance: 20).onChanged { value in
                        if abs(value.translation.width) > abs(value.translation.height) { dragOffset = max(-60, min(60, value.translation.width)) }
                    }.onEnded { value in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            if value.translation.width > 70 { store.setCompleted(entry.task, occurrenceDate: entry.date, completed: true) }
                            else if value.translation.width < -70 { store.later(entry.task) }
                        }
                        dragOffset = 0
                    })
            }.foregroundStyle(Paper.faint)
        }
        .padding(.leading, 27).padding(.trailing, 20).padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Paper.line.opacity(0.4)).frame(height: 0.5).padding(.leading, 38).padding(.trailing, 24).allowsHitTesting(false) }
        .offset(x: dragOffset)
    }
    private var detail: String {
        var parts: [String] = []
        if let date = entry.date { parts.append(date.formatted(.dateTime.month().day())) }
        else { parts.append("沒有期限") }
        if entry.task.recurrence != .none { parts.append(entry.task.recurrence.title + "重複") }
        if entry.task.repeatEnd != nil { parts.append("本期後停止重複") }
        if entry.isCompleted {
            if let date = entry.completedAt { parts.append(date.formatted(.dateTime.month().day().hour().minute()) + " 完成") }
            else { parts.append("舊版已完成 · 未記錄時間") }
        }
        return parts.joined(separator: " · ")
    }
}

private struct JournalRecordRow: View {
    let record: TaskRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if record.action == .completed { PencilTitle(title: record.title) }
            else { Text(record.title).font(.system(size: 14, design: .serif)).foregroundStyle(Paper.faint) }
            Text(record.timestamp.formatted(.dateTime.month().day().hour().minute()) + (record.action == .completed ? " 完成" : " 重新開啟"))
                .font(.system(size: 10)).foregroundStyle(Paper.faint)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
    }
}

private struct JournalCalendar: View {
    @Binding var date: Date
    let store: TaskStore
    private var month: DateInterval { store.interval(for: date, scope: .month) }
    private var days: [Date] {
        let count = store.calendar.range(of: .day, in: .month, for: date)!.count
        return (0..<count).compactMap { store.calendar.date(byAdding: .day, value: $0, to: month.start) }
    }
    private var offset: Int { (store.calendar.component(.weekday, from: month.start) + 5) % 7 }
    var body: some View {
        VStack(spacing: 7) {
            HStack {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in Text(day).font(.system(size: 10)).frame(maxWidth: .infinity).foregroundStyle(Paper.faint) }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
                ForEach(0..<offset, id: \.self) { _ in Color.clear.frame(height: 32) }
                ForEach(days, id: \.self) { day in
                    let selected = store.calendar.isDate(day, inSameDayAs: date)
                    let occurrences = store.occurrences(on: day, scope: .day)
                    Button { date = day } label: {
                        VStack(spacing: 3) {
                            Text("\(store.calendar.component(.day, from: day))").font(.system(size: 11, weight: store.calendar.isDateInToday(day) ? .bold : .regular))
                            Circle().fill(occurrences.isEmpty ? .clear : selected ? .white.opacity(0.8) : Paper.accent).frame(width: 3, height: 3)
                        }.frame(maxWidth: .infinity).frame(height: 32).contentShape(Rectangle())
                            .background(selected ? Paper.accent : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                            .foregroundStyle(selected ? .white : Paper.ink)
                    }.buttonStyle(.plain).accessibilityLabel(day.formatted(date: .complete, time: .omitted) + "，\(occurrences.count) 件事項")
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }.padding(10).background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct TaskPlanEditor: View {
    let task: TaskItem
    let store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var scope: TaskScope
    @State private var date: Date
    @State private var recurrence = TaskRepeat.none
    init(task: TaskItem, store: TaskStore) {
        self.task = task; self.store = store
        _scope = State(initialValue: task.scope)
        _date = State(initialValue: task.date ?? Date())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("為這件事，留個位置。").font(.system(size: 22, design: .serif))
            Text(task.title).font(.body).fixedSize(horizontal: false, vertical: true)
            Picker("類型", selection: $scope) { ForEach(TaskScope.allCases) { Text($0.title).tag($0) } }
            if scope != .anytime {
                DatePicker("安排日期", selection: $date, displayedComponents: .date)
                Picker("重複", selection: $recurrence) { ForEach(scope.repeats) { Text($0.title).tag($0) } }
            }
            Text(scope == .week ? "週一至週日為一週，整週都能看到目標。" : scope == .month ? "整個月都能看到目標。" : "未完成的日事項會留在今天，未來事項到當天才出現。")
                .font(.caption).foregroundStyle(Paper.faint)
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
            HStack { Button("取消") { dismiss() }; Spacer(); Button("儲存安排") {
                if store.updatePlan(task, scope: scope, date: scope == .anytime ? nil : date, recurrence: recurrence) { dismiss() }
            }.buttonStyle(.borderedProminent) }
        }.padding(26).frame(width: 360).background(Paper.sheet).tint(Paper.accent).preferredColorScheme(.light)
            .onChange(of: scope) { _, scope in if !scope.repeats.contains(recurrence) { recurrence = .none } }
    }
}
// Text stays selectable and accessible; two graphite strokes follow each wrapped line.
private struct PencilTitle: View {
    let title: String
    var body: some View {
        Text(title).font(.system(size: 15, design: .serif)).lineSpacing(5)
            .foregroundStyle(Paper.faint).fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .overlay {
                GeometryReader { geometry in
                    Canvas { context, _ in
                        let descriptor = NSFont.systemFont(ofSize: 15).fontDescriptor.withDesign(.serif) ?? NSFont.systemFont(ofSize: 15).fontDescriptor
                        let font = NSFont(descriptor: descriptor, size: 15) ?? NSFont.systemFont(ofSize: 15)
                        let text = NSAttributedString(string: title, attributes: [.font: font])
                        let typesetter = CTTypesetterCreateWithAttributedString(text)
                        var index = 0
                        var lineIndex = 0
                        while index < text.length {
                            let count = CTTypesetterSuggestLineBreak(typesetter, index, Double(geometry.size.width))
                            guard count > 0 else { break }
                            let line = CTTypesetterCreateLine(typesetter, CFRange(location: index, length: count))
                            let width = min(geometry.size.width, CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
                            let y = CGFloat(lineIndex) * (font.ascender - font.descender + font.leading + 5) + 9
                            var stroke = Path()
                            stroke.move(to: CGPoint(x: 0, y: y + 1))
                            stroke.addLine(to: CGPoint(x: width * 0.32, y: y - 0.4))
                            stroke.addLine(to: CGPoint(x: width * 0.69, y: y + 0.7))
                            stroke.addLine(to: CGPoint(x: width, y: y - 0.6))
                            context.stroke(stroke, with: .color(Paper.ink.opacity(0.6)), style: StrokeStyle(lineWidth: 0.85, lineCap: .round))
                            context.stroke(stroke.offsetBy(dx: 0.3, dy: 1.4), with: .color(Paper.ink.opacity(0.16)), lineWidth: 0.5)
                            index += count
                            lineIndex += 1
                        }
                    }
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            .accessibilityLabel("已完成：\(title)")
    }
}

private struct RuledPaper: View {
    var body: some View {
        Canvas { context, size in
            var lines = Path()
            for y in stride(from: CGFloat(1), to: size.height, by: 32) {
                lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(lines, with: .color(Paper.line.opacity(0.17)), lineWidth: 0.5)
            var margin = Path()
            margin.move(to: CGPoint(x: 25, y: 0)); margin.addLine(to: CGPoint(x: 25, y: size.height))
            context.stroke(margin, with: .color(Paper.accent.opacity(0.17)), lineWidth: 0.7)
        }.background(Paper.sheet)
    }
}
#endif
