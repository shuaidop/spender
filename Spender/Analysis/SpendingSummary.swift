import Foundation

struct CategorySpending: Identifiable {
    let id = UUID()
    let categoryName: String
    let iconName: String
    let colorHex: String
    let totalAmount: Decimal
    let percentage: Double
    let transactionCount: Int
}

struct CardSpending: Identifiable {
    let id = UUID()
    let cardName: String
    let colorHex: String
    let totalAmount: Decimal
    let transactionCount: Int
}

struct MerchantSpending: Identifiable {
    let id = UUID()
    let merchantName: String
    let totalAmount: Decimal
    let transactionCount: Int
    let categoryName: String?
}

struct MonthlyTotal: Identifiable {
    let id = UUID()
    let monthKey: String
    let monthLabel: String
    let totalAmount: Decimal
    let creditAmount: Decimal

    var netAmount: Decimal { totalAmount - creditAmount }
}

struct SpendingSummary {
    let totalSpend: Decimal
    let averageDaily: Decimal
    let averagePerTransaction: Decimal
    let highestSingle: Decimal
    let highestMerchant: String
    let transactionCount: Int
    let dayCount: Int
    let creditTotal: Decimal
    let creditCount: Int
}
