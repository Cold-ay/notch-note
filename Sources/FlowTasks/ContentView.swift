import SwiftUI

struct ContentView: View {
    @Bindable var store: TaskStore
    @State private var section = "待辦"
    @State private var input = ""
    @State private var selectedDate = Date()
    @State private var assignDate = false
    @State private var newDate = Date()
    private let accent = Color(red: 0.30, green: 0.40, blue: 0.93)
    var visible: [TaskItem] {
        if section == "已完成" { return store.tasks.filter(\.completed) }
        if section == "日曆" { return store.pending.filter { task in task.date.map { Calendar.current.isDate($0, inSameDayAs: selectedDate) } ?? false } }
        return store.pending
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("留出空間，專注現在。").font(.largeTitle.bold())
                            Text("還有 \(store.pending.count) 件待辦 · 一次處理一件就好").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(!store.canUndo).accessibilityLabel("復原上一步")
                    }
                    Picker("檢視", selection: $section) { ForEach(["待辦", "日曆", "已完成"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                    if section == "日曆" {
                        DatePicker("選擇日期", selection: $selectedDate, displayedComponents: .date).datePickerStyle(.graphical)
                    }
                    if section == "待辦", let first = store.pending.first {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("現在，做這件事").font(.caption.bold()).foregroundStyle(accent)
                            TaskCard(task: first, store: store, prominent: true)
                            Text("右滑完成 · 左滑移到隊尾 · 隨時可以復原").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("把腦中的事情放下來").font(.headline)
                        Text("每行一件事，可以一次貼上整份清單。").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $input).frame(height: 86).padding(8).background(.background, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.2))).accessibilityLabel("批量新增待辦，每行一件")
                        Toggle("安排日期", isOn: $assignDate)
                        if assignDate { DatePicker("待辦日期", selection: $newDate, displayedComponents: .date) }
                        Button { if store.add(input, date: assignDate ? newDate : nil) { input = "" } } label: {
                            Label("加入待辦", systemImage: "plus").frame(maxWidth: .infinity).padding(6)
                        }.buttonStyle(.borderedProminent).disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }.padding(18).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 20))
                    LazyVStack(alignment: .leading, spacing: 12) {
                        Text("\(section) · \(visible.count)").font(.headline)
                        if visible.isEmpty { ContentUnavailableView("這裡暫時沒有事項", systemImage: "checkmark.circle", description: Text("新增待辦，或選擇其他日期。")) }
                        ForEach(visible) { task in TaskCard(task: task, store: store) }
                    }
                }.padding(24).frame(maxWidth: 760)
            }
            .navigationTitle("FlowTasks")
            .tint(accent)
            .alert("儲存提示", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("知道了") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
    }
}

struct TaskCard: View {
    let task: TaskItem
    var store: TaskStore
    var prominent = false
    @State private var offset: CGFloat = 0
    @State private var scheduling = false
    @State private var date = Date()
    var body: some View {
        HStack(spacing: 12) {
            Button { store.complete(task) } label: { Image(systemName: task.completed ? "checkmark.circle.fill" : "circle").font(.title2) }.buttonStyle(.plain).accessibilityLabel(task.completed ? "還原為待辦" : "完成事項")
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title).font(prominent ? .title2.bold() : .body).strikethrough(task.completed).fixedSize(horizontal: false, vertical: true)
                if let date = task.date { Text(date, style: .date).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
            Menu {
                Button("安排日期") { date = task.date ?? Date(); scheduling = true }
                Button("移除日期") { store.schedule(task, date: nil) }
                if !task.completed { Button("移到隊尾") { store.later(task) } }
            } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("事項選項")
        }
        .padding(prominent ? 24 : 16)
        .background(prominent ? Color.indigo.opacity(0.12) : Color.gray.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        .offset(x: offset)
        .simultaneousGesture(DragGesture(minimumDistance: 25).onChanged { value in
            if abs(value.translation.width) > abs(value.translation.height) { offset = value.translation.width }
        }.onEnded { value in
            if abs(value.translation.width) > abs(value.translation.height) {
                if value.translation.width > 100 { store.complete(task) }
                else if value.translation.width < -100 && !task.completed { store.later(task) }
            }
            withAnimation { offset = 0 }
        })
        .sheet(isPresented: $scheduling) {
            VStack(spacing: 20) {
                DatePicker("安排日期", selection: $date, displayedComponents: .date).datePickerStyle(.graphical)
                Button("儲存日期") { store.schedule(task, date: date); scheduling = false }.buttonStyle(.borderedProminent)
                Button("取消") { scheduling = false }
            }.padding(24).frame(minWidth: 300, minHeight: 380)
        }
    }
}
