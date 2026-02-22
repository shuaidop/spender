import Foundation

enum ContextScope: String, CaseIterable, Identifiable {
    case lastMonth = "Last Month"
    case lastThreeMonths = "Last 3 Months"
    case yearToDate = "Year to Date"
    case annual = "Full Year"

    var id: String { rawValue }

    func dates(year: Int = Calendar.current.component(.year, from: Date())) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .lastMonth:
            let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let start = cal.date(byAdding: .month, value: -1, to: thisMonth)!
            return (start, thisMonth)
        case .lastThreeMonths:
            let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let start = cal.date(byAdding: .month, value: -3, to: thisMonth)!
            return (start, thisMonth)
        case .yearToDate:
            let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let start = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: 1, day: 1))!
            return (start, thisMonth)
        case .annual:
            let start = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
            let nextYear = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
            let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
            return (start, min(nextYear, tomorrow))
        }
    }
}

final class SpendingContextBuilder {
    private let engine: AnalysisEngine

    init(engine: AnalysisEngine) {
        self.engine = engine
    }

    func buildContext(scope: ContextScope) -> String {
        let dates = scope.dates()
        let summary = engine.summaryStats(from: dates.start, to: dates.end)
        let byCategory = engine.spendingByCategory(from: dates.start, to: dates.end)
        let byCard = engine.spendingByCard(from: dates.start, to: dates.end)
        let topMerchants = engine.topMerchants(from: dates.start, to: dates.end, limit: 15)

        var context = """
        SPENDING DATA (\(scope.rawValue))
        Period: \(DateFormatters.shortDate.string(from: dates.start)) - \(DateFormatters.shortDate.string(from: dates.end))

        SUMMARY:
        Total Spent: \(CurrencyFormatter.format(summary.totalSpend))
        Credits/Refunds: \(CurrencyFormatter.format(summary.creditTotal))
        Transactions: \(summary.transactionCount)
        Daily Average: \(CurrencyFormatter.format(summary.averageDaily))
        Per Transaction Average: \(CurrencyFormatter.format(summary.averagePerTransaction))

        BY CATEGORY:
        """

        for cat in byCategory {
            context += "\n\(cat.categoryName): \(CurrencyFormatter.format(cat.totalAmount)) (\(String(format: "%.1f%%", cat.percentage)), \(cat.transactionCount) txns)"
        }

        context += "\n\nBY CARD:"
        for card in byCard {
            context += "\n\(card.cardName): \(CurrencyFormatter.format(card.totalAmount)) (\(card.transactionCount) txns)"
        }

        context += "\n\nTOP MERCHANTS:"
        for (i, merchant) in topMerchants.enumerated() {
            context += "\n\(i + 1). \(merchant.merchantName): \(CurrencyFormatter.format(merchant.totalAmount)) (\(merchant.transactionCount) txns)"
        }

        return context
    }
}
