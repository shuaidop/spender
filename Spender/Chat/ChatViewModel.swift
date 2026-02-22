import Foundation
import SwiftData
import OpenAI

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var currentStreamText: String = ""
    var conversationId: UUID = UUID()
    var contextScope: ContextScope = .lastMonth
    var errorMessage: String?

    private let openAIService = OpenAIService()
    private var modelContext: ModelContext?
    private var spendingEngine: AnalysisEngine?

    var isConfigured: Bool { openAIService.isConfigured }

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.spendingEngine = AnalysisEngine(modelContext: modelContext)
        loadConversation()
    }

    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let modelContext, let engine = spendingEngine else { return }

        let userText = inputText
        inputText = ""
        errorMessage = nil

        // Save user message
        let userMessage = ChatMessage(role: "user", content: userText, conversationId: conversationId)
        modelContext.insert(userMessage)
        messages.append(userMessage)
        try? modelContext.save()

        // Build context
        let contextBuilder = SpendingContextBuilder(engine: engine)
        let spendingContext = contextBuilder.buildContext(scope: contextScope)

        let systemPrompt = """
        You are a personal finance analyst for the user. You have access to their credit card spending data.
        Analyze their spending patterns, answer questions about their finances, and provide actionable advice.

        Be specific with numbers and dates. Reference actual merchants and categories from their data.
        When suggesting optimizations, be concrete about potential savings.
        Use markdown formatting for better readability.

        Here is the user's spending data:

        \(spendingContext)
        """

        // Build message history
        var apiMessages: [ChatQuery.ChatCompletionMessageParam] = [
            .init(role: .system, content: systemPrompt)!,
        ]

        for msg in messages.suffix(20) {
            let role: ChatQuery.ChatCompletionMessageParam.Role =
                msg.role == "user" ? .user : .assistant
            if let param = ChatQuery.ChatCompletionMessageParam(role: role, content: msg.content) {
                apiMessages.append(param)
            }
        }

        // Stream response
        isStreaming = true
        currentStreamText = ""

        do {
            for try await chunk in openAIService.chatStream(messages: apiMessages) {
                currentStreamText += chunk
            }

            let assistantMessage = ChatMessage(
                role: "assistant",
                content: currentStreamText,
                conversationId: conversationId
            )
            modelContext.insert(assistantMessage)
            messages.append(assistantMessage)
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }

        isStreaming = false
        currentStreamText = ""
    }

    func newConversation() {
        conversationId = UUID()
        messages = []
    }

    func loadConversation() {
        guard let modelContext else { return }
        let id = conversationId
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> { $0.conversationId == id },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        messages = (try? modelContext.fetch(descriptor)) ?? []
    }
}
