#if os(macOS)
import SwiftUI

struct JournalEditor: View {
    let journal: JournalStore
    let date: Date
    let scope: TaskScope
    private var text: Binding<String> {
        Binding(get: { journal.text(on: date, scope: scope) }, set: { journal.setDraft($0, on: date, scope: scope) })
    }
    private var title: String {
        switch scope { case .day, .anytime: "這一天的日記"; case .week: "這一週的手記"; case .month: "這個月的手記" }
    }
    private var prompt: String {
        switch scope {
        case .day, .anytime: "今天發生了什麼？\n記下一個瞬間、一點心情，或想留給明天的話。"
        case .week: "這一週，哪些事值得記住？\n有什麼收穫、轉折，或想調整的地方？"
        case .month: "回望這個月…\n記下發生的事、走過的路，與下一個月的期待。"
        }
    }
    var body: some View {
        let currentText = text.wrappedValue
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 23, design: .serif))
                    Text("寫下經歷與心情，留在這個週期。").font(.system(size: 11)).foregroundStyle(Paper.faint)
                }
                Spacer()
                Image(systemName: "pencil.and.outline").font(.system(size: 22)).foregroundStyle(Paper.accent.opacity(0.7))
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .font(.system(size: 15, design: .serif)).lineSpacing(8)
                    .scrollContentBackground(.hidden).padding(9)
                    .accessibilityLabel(title).accessibilityIdentifier("journal.diary.input")
                if currentText.isEmpty {
                    Text(prompt).font(.system(size: 15, design: .serif)).lineSpacing(8).foregroundStyle(Paper.faint.opacity(0.65))
                        .padding(.leading, 14).padding(.top, 12).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .frame(minHeight: 300)
            .background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Paper.line.opacity(0.65), lineWidth: 1).allowsHitTesting(false) }
            HStack {
                Text(status).font(.system(size: 10)).foregroundStyle(journal.errorMessage == nil ? Paper.faint : .red)
                Spacer()
                Text("\(currentText.count) 字").font(.system(size: 10, design: .monospaced)).foregroundStyle(Paper.faint)
            }
            if let error = journal.errorMessage { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Button { journal.undo(on: date, scope: scope) } label: { Label("復原上次儲存", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Paper.faint)
                    .disabled(!journal.canUndo(on: date, scope: scope))
                Spacer()
                Button("儲存日記") { journal.saveDraft(on: date, scope: scope) }
                    .buttonStyle(.borderedProminent).keyboardShortcut("s", modifiers: .command)
                    .disabled(!journal.hasDraft(on: date, scope: scope)).accessibilityIdentifier("journal.diary.save")
            }
        }
        .task(id: currentText) {
            guard journal.hasDraft(on: date, scope: scope) else { return }
            do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            guard !Task.isCancelled else { return }
            journal.saveDraft(on: date, scope: scope)
        }
        .onDisappear { journal.saveDraft(on: date, scope: scope) }
    }
    private var status: String {
        if journal.errorMessage != nil { return "尚未儲存 · 文字已保留" }
        if journal.hasDraft(on: date, scope: scope) { return "正在保存…" }
        if let entry = journal.entry(on: date, scope: scope) { return "已儲存 · " + entry.updatedAt.formatted(.dateTime.month().day().hour().minute()) }
        return "自動儲存 · ⌘ S 可立即保存"
    }
}

struct TaskTrashView: View {
    let store: TaskStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("垃圾桶").font(.system(size: 25, design: .serif))
                Spacer()
                Button("完成") { dismiss() }
            }
            Text("\(store.deletedTasks.count) 件事項 · 可隨時還原，完成紀錄仍保留。")
                .font(.system(size: 11)).foregroundStyle(Paper.faint)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if store.deletedTasks.isEmpty {
                        ContentUnavailableView("垃圾桶是空的", systemImage: "trash", description: Text("刪除的事項會先放在這裡。"))
                    }
                    ForEach(store.deletedTasks) { task in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(task.title).font(.system(size: 15, design: .serif)).fixedSize(horizontal: false, vertical: true)
                                Text(task.scope.title + (task.completed ? " · 已完成" : " · 未完成") + (task.recurrence == .none ? "" : " · 重複系列"))
                                    .font(.system(size: 10)).foregroundStyle(Paper.faint)
                                if let date = task.deletedAt { Text("刪除於 " + date.formatted(.dateTime.month().day().hour().minute())).font(.system(size: 10)).foregroundStyle(Paper.faint) }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Button("還原") { store.restore(task) }.buttonStyle(.bordered)
                                .accessibilityLabel("還原 \(task.title)")
                        }.padding(14).background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
        }.padding(24).frame(width: 400, height: 490).background(Paper.sheet).foregroundStyle(Paper.ink).tint(Paper.accent).preferredColorScheme(.light)
    }
}
#endif
