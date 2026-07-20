import Foundation

enum RecordingCategory: String, CaseIterable, Identifiable, Codable {
    case negotiation = "商談"
    case internalMeeting = "社内会議"
    case call = "電話"
    case memo = "メモ"
    case other = "その他"

    var id: String { rawValue }

    /// 商談は常に同意確認が必須。他カテゴリは設定でON/OFFできる。
    var requiresConsentByDefault: Bool {
        self == .negotiation
    }

    var consentToggleable: Bool {
        self != .negotiation
    }
}
