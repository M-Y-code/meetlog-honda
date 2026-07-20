import SwiftUI

@main
struct MeetLogApp: App {
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var todoStore = ToDoStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(historyStore)
                .environmentObject(todoStore)
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            RecordingView()
                .tabItem { Label("録音", systemImage: "mic.circle") }

            HistoryView()
                .tabItem { Label("履歴", systemImage: "clock") }

            ToDoView()
                .tabItem { Label("ToDo", systemImage: "checklist") }

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
    }
}
