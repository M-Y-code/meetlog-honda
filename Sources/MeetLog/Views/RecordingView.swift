import SwiftUI

private enum RecordingFlowState {
    case setup
    case consent
    case active
    case summary
}

struct RecordingView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var flowState: RecordingFlowState = .setup
    @State private var category: RecordingCategory = .negotiation
    @State private var title: String = ""
    @AppStorage("consentRequiredForOtherCategories") private var requireConsentForOtherCategories = false

    @State private var coordinator: RecordingCoordinator?
    @State private var showSummarySheet = false

    var body: some View {
        NavigationStack {
            Group {
                switch flowState {
                case .setup:
                    setupView
                case .consent:
                    ConsentView(
                        category: category,
                        onAgree: { beginRecording(consentObtained: true) },
                        onDecline: { flowState = .setup }
                    )
                case .active:
                    if let coordinator {
                        RecordingActiveView(
                            coordinator: coordinator,
                            showSummarySheet: $showSummarySheet,
                            onStop: { await stopRecording() }
                        )
                    }
                case .summary:
                    if let coordinator {
                        SummaryConfirmationView(coordinator: coordinator, onDone: reset)
                    }
                }
            }
            .navigationTitle("録音")
        }
    }

    private var setupView: some View {
        Form {
            Section("カテゴリ") {
                Picker("カテゴリ", selection: $category) {
                    ForEach(RecordingCategory.allCases) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
                .pickerStyle(.inline)
            }
            Section("タイトル（任意）") {
                TextField("例：A社 新型フィット提案", text: $title)
            }
            Section {
                Button {
                    startFlow()
                } label: {
                    Text("録音を開始")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func startFlow() {
        let requiresConsent = category == .negotiation || (category.consentToggleable && requireConsentForOtherCategories)
        if requiresConsent {
            flowState = .consent
        } else {
            beginRecording(consentObtained: false)
        }
    }

    private func beginRecording(consentObtained: Bool) {
        let session = RecordingSession(
            category: category,
            title: title.isEmpty ? "\(category.rawValue) \(Date().formatted(date: .abbreviated, time: .shortened))" : title,
            consentObtainedAt: consentObtained ? Date() : nil
        )
        let newCoordinator = RecordingCoordinator(session: session)
        coordinator = newCoordinator
        flowState = .active
        newCoordinator.start()
    }

    private func stopRecording() async {
        guard let coordinator else { return }
        await coordinator.stop()
        flowState = .summary
    }

    private func reset() {
        if let coordinator {
            historyStore.add(coordinator.session)
        }
        coordinator = nil
        title = ""
        flowState = .setup
    }
}
