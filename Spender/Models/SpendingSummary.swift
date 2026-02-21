import Foundation
import SwiftData

@Model
final class SpendingSummary {
    @Attribute(.unique) var id: UUID
    var periodType: String
    var periodStart: Date
    var periodEnd: Date
    var totalSpend: Decimal
    var categoryBreakdown: [String: Double]
    var transactionCount: Int
    var topMerchant: String?
    var topMerchantAmount: Decimal?
    var generatedAt: Date

    // AI-generated content
    var aiSummaryText: String?
    var aiSuggestions: [String]?

    init(periodType: String, periodStart: Date, periodEnd: Date) {
        self.id = UUID()
        self.periodType = periodType
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.totalSpend = 0
        self.categoryBreakdown = [:]
        self.transactionCount = 0
        self.generatedAt = Date()
    }
}
