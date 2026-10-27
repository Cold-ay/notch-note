import SwiftUI

struct JournalEditor: View {
    @Environment(\.paperPalette) private var paper
    let journal: JournalStore
    let date: Date
    let scope: TaskScope
    private var prefs: AppPreferences { journal.preferences }
    private var text: Binding<String> {
        Binding(get: { journal.text(on: date, scope: scope) }, set: { journal.setDraft($0, on: date, scope: scope) })
    }
    private var title: String {
        switch scope { case .day, .anytime: prefs.text("這一天的日記"); case .week: prefs.text("這一週的手記"); case .month: prefs.text("這個月的手記") }
    }
    private var prompt: String {
        switch scope {
        case .day, .anytime: prefs.text("今天發生了什麼？\n記下一個瞬間、一點心情，或想留給明天的話。")
        case .week: prefs.text("這一週，哪些事值得記住？\n有什麼收穫、轉折，或想調整的地方？")
        case .month: prefs.text("回望這個月…\n記下發生的事、走過的路，與下一個月的期待。")
        }
    }
    var body: some View {
        let currentText = text.wrappedValue
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 23, design: .serif))
                    Text(prefs.text("寫下經歷與心情，留在這個週期。")).font(.system(size: 11)).foregroundStyle(paper.faint)
                }
                Spacer()
                Image(systemName: "pencil.and.outline").font(.system(size: 22)).foregroundStyle(paper.accent.opacity(0.7))
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .font(.system(size: 15, design: .serif)).lineSpacing(8)
                    .scrollContentBackground(.hidden).padding(9)
                    .accessibilityLabel(title).accessibilityIdentifier("journal.diary.input")
                if currentText.isEmpty {
                    Text(prompt).font(.system(size: 15, design: .serif)).lineSpacing(8).foregroundStyle(paper.faint.opacity(0.65))
                        .padding(.leading, 14).padding(.top, 12).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .frame(minHeight: 300)
            .background { RuledPaper().overlay(.white.opacity(0.35)).clipShape(RoundedRectangle(cornerRadius: 10)).allowsHitTesting(false) }
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(paper.line.opacity(0.65), lineWidth: 1).allowsHitTesting(false) }
            HStack {
                Text(status).font(.system(size: 10)).foregroundStyle(journal.errorMessage == nil ? paper.faint : .red)
                Spacer()
                Text(prefs.format("%d 字", currentText.count)).font(.system(size: 10, design: .monospaced)).foregroundStyle(paper.faint)
            }
            if let error = journal.errorMessage { Text(prefs.text(error)).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Button { journal.undo(on: date, scope: scope) } label: { Label(prefs.text("復原上次儲存"), systemImage: "arrow.uturn.backward") }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(paper.faint)
                    .disabled(!journal.canUndo(on: date, scope: scope))
                Spacer()
                Button(prefs.text("儲存日記")) { journal.saveDraft(on: date, scope: scope) }
                    .buttonStyle(.borderedProminent).keyboardShortcut("s", modifiers: .command)
                    .disabled(!journal.hasDraft(on: date, scope: scope)).accessibilityIdentifier("journal.diary.save")
            }
        }
        .environment(\.locale, prefs.locale)
        .task(id: currentText) {
            guard journal.hasDraft(on: date, scope: scope) else { return }
            do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            guard !Task.isCancelled else { return }
            journal.saveDraft(on: date, scope: scope)
        }
        .onDisappear { journal.saveDraft(on: date, scope: scope) }
    }
    private var status: String {
        if journal.errorMessage != nil { return prefs.text("尚未儲存 · 文字已保留") }
        if journal.hasDraft(on: date, scope: scope) { return prefs.text("正在保存…") }
        if let entry = journal.entry(on: date, scope: scope) { return prefs.text("已儲存 · ") + entry.updatedAt.formatted(.dateTime.month().day().hour().minute().locale(prefs.locale)) }
        return prefs.text("自動儲存 · ⌘ S 可立即保存")
    }
}

#if os(macOS)
struct TaskTrashView: View {
    @Environment(\.paperPalette) private var paper
    let store: TaskStore
    private var prefs: AppPreferences { store.preferences }
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(prefs.text("垃圾桶")).font(.system(size: 25, design: .serif))
                Spacer()
                Button(prefs.text("完成")) { dismiss() }
            }
            Text(prefs.format("%d 件事項 · 可隨時還原，完成紀錄仍保留。", store.deletedTasks.count))
                .font(.system(size: 11)).foregroundStyle(paper.faint)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if store.deletedTasks.isEmpty {
                        ContentUnavailableView(prefs.text("垃圾桶是空的"), systemImage: "trash", description: Text(prefs.text("刪除的事項會先放在這裡。")))
                    }
                    ForEach(store.deletedTasks) { task in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(task.title).font(.system(size: 15, design: .serif)).fixedSize(horizontal: false, vertical: true)
                                Text(prefs.text(task.scope.title) + (task.completed ? prefs.text(" · 已完成") : prefs.text(" · 未完成")) + (task.recurrence == .none ? "" : prefs.text(" · 重複系列")))
                                    .font(.system(size: 10)).foregroundStyle(paper.faint)
                                if let date = task.deletedAt { Text(prefs.text("刪除於 ") + date.formatted(.dateTime.month().day().hour().minute().locale(prefs.locale))).font(.system(size: 10)).foregroundStyle(paper.faint) }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Button(prefs.text("還原")) { store.restore(task) }.buttonStyle(.bordered)
                                .accessibilityLabel(prefs.text("還原 ") + task.title)
                        }.padding(14).background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            if let error = store.errorMessage { Text(prefs.text(error)).font(.caption).foregroundStyle(.red) }
        }.padding(24).frame(width: 400, height: 490).background(paper.sheet).foregroundStyle(paper.ink).tint(paper.accent).preferredColorScheme(.light)
    }
}
#endif
