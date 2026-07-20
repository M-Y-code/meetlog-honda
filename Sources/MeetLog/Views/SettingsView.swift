import SwiftUI

struct SettingsView: View {
    @AppStorage("consentRequiredForOtherCategories") private var consentRequiredForOtherCategories = false
    @AppStorage("reminderDayBefore") private var reminderDayBefore = true
    @AppStorage("reminderOnDueDate") private var reminderOnDueDate = true
    @AppStorage("recordingQualityPrioritizesBattery") private var recordingQualityPrioritizesBattery = true

    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var todoStore: ToDoStore
    @State private var showDeleteAllConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("同意確認") {
                    Toggle("商談以外でも同意確認を必須にする", isOn: $consentRequiredForOtherCategories)
                    Text("「商談」カテゴリは常に同意確認が必須です（変更不可）。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("通知タイミング") {
                    Toggle("期限前日に通知", isOn: $reminderDayBefore)
                    Toggle("期限当日に通知", isOn: $reminderOnDueDate)
                }

                Section("録音品質") {
                    Toggle("バッテリー優先（省電力エンコード）", isOn: $recordingQualityPrioritizesBattery)
                }

                Section("データ削除") {
                    Text("録音・文字起こし・要約・同意ログは作成から48時間で自動的に完全削除されます（延長不可）。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("すべての履歴を今すぐ削除", role: .destructive) {
                        showDeleteAllConfirmation = true
                    }
                }
            }
            .navigationTitle("設定")
            .confirmationDialog(
                "すべての録音・要約データを今すぐ完全に削除します。この操作は取り消せません。",
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除する", role: .destructive) {
                    for session in historyStore.sessions {
                        historyStore.delete(session)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}
