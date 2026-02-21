import Foundation

enum Constants {
    /// Base URL for the Cloudflare Worker backend.
    /// Update this when deploying to production.
    static let apiBaseURL = "https://spender-api.your-subdomain.workers.dev"

    /// Default categories for transaction categorization
    static let categoryNames = [
        "Groceries", "Dining", "Transportation", "Subscriptions",
        "Shopping", "Entertainment", "Health", "Travel",
        "Bills & Utilities", "Gas", "Personal Care", "Education",
        "Gifts & Donations", "Other",
    ]

    /// Batch size for OpenAI categorization requests
    static let categorizationBatchSize = 50

    /// Max transactions to include in chat context
    static let chatContextTransactionLimit = 100
}
