import Foundation
import SwiftData
import Observation

/// Default ChatProvider implementation backed by OpenAI via the backend proxy.
@MainActor
@Observable
final class ChatService: ChatProvider {
    private(set) var messages: [ChatMessageData] = []
    private(set) var isStreaming = false

    private let openAIService: OpenAIService
    private let modelContext: ModelContext

    init(openAIService: OpenAIService, modelContext: ModelContext) {
        self.openAIService = openAIService
        self.modelContext = modelContext
    }

    func send(_ text: String, context: SpendingContext) async throws {
        let userMessage = ChatMessageData(role: .user, content: text)
        messages.append(userMessage)
        isStreaming = true

        defer { isStreaming = false }

        // Build history from recent messages
        let history = messages.prefix(20).map { msg in
            ChatHistoryEntry(role: msg.role.rawValue, content: msg.content)
        }

        // Get device token
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        guard let settings = try modelContext.fetch(settingsDescriptor).first else {
            let errorMsg = ChatMessageData(role: .assistant, content: "Please set up the app first.")
            messages.append(errorMsg)
            return
        }

        let response = try await openAIService.chat(
            message: text,
            context: context,
            history: history,
            deviceToken: settings.deviceToken
        )

        let assistantMessage = ChatMessageData(role: .assistant, content: response.reply)
        messages.append(assistantMessage)
    }

    func clearHistory() {
        messages = []
    }
}
