import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var role: String
    var content: String
    var timestamp: Date
    var conversationId: UUID

    init(role: String, content: String, conversationId: UUID) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.conversationId = conversationId
    }
}
