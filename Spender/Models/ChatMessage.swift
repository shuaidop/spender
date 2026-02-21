import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
}

enum ChatAttachment: Codable {
    case spendingChart(chartType: String, periodType: String)
    case transactionList(transactionIDs: [String])
    case summaryCard(summaryText: String)
}

struct ChatMessageData: Identifiable, Codable {
    let id: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date
    let attachments: [ChatAttachment]?

    init(
        role: ChatRole,
        content: String,
        attachments: [ChatAttachment]? = nil
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.attachments = attachments
    }
}
