import SwiftUI

struct ConsentView: View {
    let category: RecordingCategory
    let onAgree: () -> Void
    let onDecline: () -> Void

    @State private var checked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("録音を開始する前に、相手の同意を得てください")
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("声かけ例")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("「本日の商談内容は、正確な記録・振り返りのためアプリで録音させていただいてもよろしいでしょうか」")
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Toggle("相手の同意を得ました", isOn: $checked)
                .toggleStyle(.switch)

            Spacer()

            Button {
                onAgree()
            } label: {
                Text("録音開始")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!checked)

            Button("同意なしでテキストメモにする", role: .cancel) {
                onDecline()
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .navigationTitle(category.rawValue)
    }
}
