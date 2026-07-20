import SwiftUI

struct ToDoView: View {
    @EnvironmentObject private var todoStore: ToDoStore
    @State private var showAddSheet = false
    @State private var purgeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                ForEach(todoStore.sortedByDueDate) { item in
                    ToDoRow(item: item)
                }
            }
            .overlay {
                if todoStore.items.isEmpty {
                    ContentUnavailableView("ToDoはありません", systemImage: "checklist")
                }
            }
            .navigationTitle("ToDo")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddToDoView()
            }
            .onReceive(purgeTimer) { _ in
                todoStore.purgeExpired()
            }
            .onAppear { todoStore.purgeExpired() }
        }
    }
}

private struct ToDoRow: View {
    @EnvironmentObject private var todoStore: ToDoStore
    let item: ToDoItem

    var body: some View {
        HStack(alignment: .top) {
            Button {
                todoStore.complete(item)
            } label: {
                Image(systemName: "circle")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                HStack(spacing: 8) {
                    Text(item.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.dueDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(item.overdueAt == nil ? .secondary : .red)
                }
                if let deadline = item.deletionDeadline {
                    Text("期限切れ・あと\(hoursRemaining(until: deadline))時間で削除")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Spacer()
        }
        .swipeActions(edge: .trailing) {
            Button("延長") {
                todoStore.extend(item, to: Date().addingTimeInterval(86400))
            }
            .tint(.orange)
            Button("削除", role: .destructive) {
                todoStore.delete(item)
            }
        }
    }

    private func hoursRemaining(until date: Date) -> Int {
        max(0, Int(date.timeIntervalSinceNow / 3600))
    }
}

private struct AddToDoView: View {
    @EnvironmentObject private var todoStore: ToDoStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var category = "その他"
    @State private var dueDate = Date().addingTimeInterval(86400)
    @State private var priority: ToDoPriority = .normal

    var body: some View {
        NavigationStack {
            Form {
                TextField("タイトル", text: $title)
                TextField("カテゴリ", text: $category)
                DatePicker("期限", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                Picker("優先度", selection: $priority) {
                    ForEach(ToDoPriority.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
            }
            .navigationTitle("ToDoを追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        todoStore.add(ToDoItem(title: title, category: category, dueDate: dueDate, priority: priority))
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
