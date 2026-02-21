import Foundation
import SwiftUI

/// Data point for daily spending (used in weekly charts)
struct DailySpend: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Decimal
    let category: String
}

/// Data point for monthly spending totals
struct MonthlySpend: Identifiable {
    let id = UUID()
    let month: Date
    let totalSpend: Decimal
}

/// Data point for spending by category
struct CategorySpend: Identifiable {
    let id = UUID()
    let category: String
    let amount: Decimal
    let color: Color
    let transactionCount: Int

    var percentage: Double {
        0 // Computed by the view model relative to total
    }
}

/// Data point for weekly trend over time
struct WeeklyTotal: Identifiable {
    let id = UUID()
    let weekStart: Date
    let total: Decimal
}

/// Context sent to the LLM for spending-aware chat
struct SpendingContext: Codable {
    let totalSpendThisMonth: Double
    let totalSpendLastMonth: Double
    let topCategories: [String: Double]
    let recentTransactions: [TransactionSummary]

    struct TransactionSummary: Codable {
        let merchantName: String
        let amount: Double
        let category: String
        let date: String
    }
}
