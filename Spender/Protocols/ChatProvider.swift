import Foundation

/// Protocol for the chat interaction layer.
/// Swap implementations to change the LLM backend or conversation behavior
/// without touching any views.
@MainActor
protocol ChatProvider: Observable {
    var messages: [ChatMessageData] { get }
    var isStreaming: Bool { get }
    func send(_ text: String, context: SpendingContext) async throws
    func clearHistory()
}
