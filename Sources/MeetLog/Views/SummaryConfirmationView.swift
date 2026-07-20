import SwiftUI
import UIKit

struct SummaryConfirmationView: View {
    @ObservedObject var coordinator: RecordingCoordinator
    let onDone: () -> Void

    @EnvironmentObject private var todoStore: ToDoStore
    @State private var selectedTodos: Set<String> = []
    @State private var dueDates: [String: Date] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if coordinator.isFinalizing {
                    ProgressView("最終要約を生成中…")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let final = coordinator.session.finalSummary {
                    header(final: final)
                    block(title: "概要", text: final.overview)
                    block(title: "要望・懸念点", text: final.requestsAndConcerns)
                    block(title: "決定事項・保留事項", text: final.decisionsAndPending)

                    if !final.todoCandidates.isEmpty {
                        todoCandidatesSection(final.todoCandidates)
                    }

                    shareBlock(final: final)
                } else {
                    Text("要約の生成に失敗しました。")
                        .foregroundStyle(.red)
                }

                Button("完了") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("サマリー確認")
    }

    private func header(final: FinalSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(coordinator.session.title).font(.title3.bold())
            Text("このデータは \(coordinator.session.deletionDeadline.formatted(date: .abbreviated, time: .shortened)) に自動削除されます")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func block(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text)
        }
    }

    private func todoCandidatesSection(_ candidates: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ToDo候補").font(.headline)
            ForEach(candidates, id: \.self) { candidate in
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(candidate, isOn: Binding(
                        get: { selectedTodos.contains(candidate) },
                        set: { isOn in
                            if isOn { selectedTodos.insert(candidate) } else { selectedTodos.remove(candidate) }
                        }
                    ))
                    if selectedTodos.contains(candidate) {
                        DatePicker(
                            "期限",
                            selection: Binding(
                                get: { dueDates[candidate] ?? Date().addingTimeInterval(86400) },
                                set: { dueDates[candidate] = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }
            Button("選択したToDoを登録") {
                registerSelectedTodos()
            }
            .buttonStyle(.bordered)
            .disabled(selectedTodos.isEmpty)
        }
    }

    private func shareBlock(final: FinalSummary) -> some View {
        let shareText = "【\(coordinator.session.title)】\n\n概要:\n\(final.overview)\n\n要望・懸念点:\n\(final.requestsAndConcerns)\n\n決定事項・保留事項:\n\(final.decisionsAndPending)"
        return HStack {
            ShareLink(item: shareText) {
                Label("要約を共有", systemImage: "square.and.arrow.up")
            }
            Button {
                UIPasteboard.general.string = shareText
            } label: {
                Label("コピー", systemImage: "doc.on.doc")
            }
        }
        .buttonStyle(.bordered)
    }

    private func registerSelectedTodos() {
        for candidate in selectedTodos {
            let due = dueDates[candidate] ?? Date().addingTimeInterval(86400)
            let item = ToDoItem(
                title: candidate,
                category: coordinator.session.category.rawValue,
                dueDate: due,
                relatedRecordingID: coordinator.session.id
            )
            todoStore.add(item)
        }
        selectedTodos.removeAll()
    }
}
