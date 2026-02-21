import Foundation

final class OpenAIService: Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func categorize(
        transactions: [TransactionForCategorization],
        deviceToken: String
    ) async throws -> [CategoryResult] {
        let response: CategorizeResponse = try await apiClient.post(
            path: "/api/openai/categorize",
            body: CategorizeRequest(transactions: transactions),
            deviceToken: deviceToken
        )
        return response.results
    }

    func getInsights(
        spendingData: SpendingDataPayload,
        periodType: String,
        deviceToken: String
    ) async throws -> InsightsResponse {
        try await apiClient.post(
            path: "/api/openai/insights",
            body: InsightsRequest(spendingData: spendingData, periodType: periodType),
            deviceToken: deviceToken
        )
    }

    func chat(
        message: String,
        context: SpendingContext,
        history: [ChatHistoryEntry],
        deviceToken: String
    ) async throws -> ChatResponse {
        try await apiClient.post(
            path: "/api/openai/chat",
            body: ChatRequest(message: message, context: context, history: history),
            deviceToken: deviceToken
        )
    }
}
