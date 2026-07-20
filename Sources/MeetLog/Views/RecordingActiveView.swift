import SwiftUI

struct RecordingActiveView: View {
    @ObservedObject var coordinator: RecordingCoordinator
    @Binding var showSummarySheet: Bool
    let onStop: () async -> Void

    @State private var isStopping = false
    @State private var elapsedTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var displayedElapsed: TimeInterval = 0

    var body: some View {
        VStack(spacing: 24) {
            Text(formatted(displayedElapsed))
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
                .onReceive(elapsedTimer) { _ in
                    displayedElapsed = coordinator.elapsed
                }

            Circle()
                .fill(.red)
                .frame(width: 14, height: 14)
                .opacity(coordinator.isRecording ? 1 : 0.2)

            if let errorMessage = coordinator.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                showSummarySheet = true
            } label: {
                Label("要約を見る", systemImage: "text.alignleft")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(role: .destructive) {
                isStopping = true
                Task {
                    await onStop()
                    isStopping = false
                }
            } label: {
                if isStopping {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("録音停止")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isStopping)
            .padding(.bottom, 24)
        }
        .padding()
        .sheet(isPresented: $showSummarySheet) {
            RollingSummaryPanel(coordinator: coordinator)
        }
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct RollingSummaryPanel: View {
    @ObservedObject var coordinator: RecordingCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if coordinator.session.rollingSummary.lastRefinedAt == nil {
                        Text("まだ要約が生成されていません。しばらくお待ちください。")
                            .foregroundStyle(.secondary)
                    } else {
                        summaryBlock(title: "概要", text: coordinator.session.rollingSummary.overview)
                        summaryBlock(title: "要望・懸念点", text: coordinator.session.rollingSummary.requestsAndConcerns)
                        summaryBlock(title: "決定事項・保留事項", text: coordinator.session.rollingSummary.decisionsAndPending)

                        if let lastRefinedAt = coordinator.session.rollingSummary.lastRefinedAt {
                            Text("最終更新: \(lastRefinedAt.formatted(date: .omitted, time: .standard))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("要約を見る")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                isRefreshing = true
                await coordinator.refreshIfStale()
                isRefreshing = false
            }
            .overlay {
                if isRefreshing {
                    ProgressView()
                }
            }
        }
    }

    private func summaryBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text.isEmpty ? "（まだ内容がありません）" : text)
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
        }
    }
}
