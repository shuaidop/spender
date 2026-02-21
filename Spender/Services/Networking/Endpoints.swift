import Foundation

// MARK: - Plaid DTOs

struct CreateLinkTokenRequest: Codable {
    let deviceToken: String
}

struct CreateLinkTokenResponse: Codable {
    let linkToken: String
}

struct ExchangeTokenRequest: Codable {
    let publicToken: String
    let deviceToken: String
}

struct ExchangeTokenResponse: Codable {
    let itemId: String
    let accounts: [PlaidAccountDTO]
}

struct PlaidAccountDTO: Codable {
    let accountId: String
    let name: String
    let officialName: String?
    let type: String
    let subtype: String?
    let mask: String?
    let balances: PlaidBalancesDTO
}

struct PlaidBalancesDTO: Codable {
    let available: Double?
    let current: Double?
    let isoCurrencyCode: String?
}

struct SyncTransactionsRequest: Codable {
    let deviceToken: String
    let itemId: String
    let cursor: String?
}

struct SyncTransactionsResponse: Codable {
    let added: [PlaidTransactionDTO]
    let modified: [PlaidTransactionDTO]
    let removed: [PlaidRemovedTransactionDTO]
    let nextCursor: String
}

struct PlaidTransactionDTO: Codable {
    let transactionId: String
    let accountId: String
    let amount: Double
    let name: String
    let merchantName: String?
    let date: String
    let authorizedDate: String?
    let pending: Bool
    let isoCurrencyCode: String?
    let personalFinanceCategory: PlaidCategoryDTO?
}

struct PlaidCategoryDTO: Codable {
    let primary: String
    let detailed: String
}

struct PlaidRemovedTransactionDTO: Codable {
    let transactionId: String
}

// MARK: - OpenAI DTOs

struct CategorizeRequest: Codable {
    let transactions: [TransactionForCategorization]
}

struct TransactionForCategorization: Codable {
    let id: String
    let merchantName: String
    let description: String
    let amount: Double
    let date: String
}

struct CategorizeResponse: Codable {
    let results: [CategoryResult]
}

struct CategoryResult: Codable {
    let id: String
    let category: String
    let confidence: Double
}

struct InsightsRequest: Codable {
    let spendingData: SpendingDataPayload
    let periodType: String
}

struct SpendingDataPayload: Codable {
    let current: PeriodData
    let previous: PeriodData
}

struct PeriodData: Codable {
    let startDate: String
    let endDate: String
    let total: Double
    let byCategory: [String: Double]
    let count: Int
}

struct InsightsResponse: Codable {
    let summary: String
    let suggestions: [String]
    let highlights: [String]
}

// MARK: - Chat DTOs

struct ChatRequest: Codable {
    let message: String
    let context: SpendingContext
    let history: [ChatHistoryEntry]
}

struct ChatHistoryEntry: Codable {
    let role: String
    let content: String
}

struct ChatResponse: Codable {
    let reply: String
}
