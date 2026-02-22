import Foundation
import OpenAI

final class OpenAIService: @unchecked Sendable {
    private var client: OpenAI?

    init() {
        if let apiKey = KeychainHelper.retrieve(key: "openai_api_key") {
            self.client = OpenAI(apiToken: apiKey)
        }
    }

    var isConfigured: Bool { client != nil }

    func updateAPIKey(_ key: String) {
        KeychainHelper.save(key: "openai_api_key", value: key)
        self.client = OpenAI(apiToken: key)
    }

    /// Non-streaming chat completion
    func chat(systemPrompt: String, userMessage: String) async throws -> String {
        guard let client else {
            throw OpenAIServiceError.notConfigured
        }

        let query = ChatQuery(
            messages: [
                .init(role: .system, content: systemPrompt)!,
                .init(role: .user, content: userMessage)!,
            ],
            model: .gpt4_o
        )

        let result = try await client.chats(query: query)
        return result.choices.first?.message.content ?? ""
    }

    /// Chat completion with full message history
    func chat(messages: [ChatQuery.ChatCompletionMessageParam]) async throws -> String {
        guard let client else {
            throw OpenAIServiceError.notConfigured
        }

        let query = ChatQuery(messages: messages, model: .gpt4_o)
        let result = try await client.chats(query: query)
        return result.choices.first?.message.content ?? ""
    }

    /// Streaming chat completion
    func chatStream(messages: [ChatQuery.ChatCompletionMessageParam]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let client else {
                    continuation.finish(throwing: OpenAIServiceError.notConfigured)
                    return
                }

                let query = ChatQuery(messages: messages, model: .gpt4_o)

                do {
                    for try await result in client.chatsStream(query: query) {
                        if let content = result.choices.first?.delta.content {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

enum OpenAIServiceError: Error, LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "OpenAI API key not configured. Go to Settings > API Key to set it up."
        }
    }
}
