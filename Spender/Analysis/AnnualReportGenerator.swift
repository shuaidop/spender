import Foundation

final class AnnualReportGenerator {
    private let engine: AnalysisEngine

    init(engine: AnalysisEngine) {
        self.engine = engine
    }

    func generate(year: Int) -> String {
        let startDate = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endDate = Calendar.current.date(from: DateComponents(year: year, month: 12, day: 31))!

        let summary = engine.summaryStats(from: startDate, to: endDate)
        let byCategory = engine.spendingByCategory(from: startDate, to: endDate)
        let byCard = engine.spendingByCard(from: startDate, to: endDate)
        let topMerchants = engine.topMerchants(from: startDate, to: endDate, limit: 20)
        let monthly = engine.monthlyTotals(year: year)

        var report = """
        # Annual Spending Report — \(year)

        ## Summary
        - **Total Spending:** \(CurrencyFormatter.format(summary.totalSpend))
        - **Total Credits/Refunds:** \(CurrencyFormatter.format(summary.creditTotal))
        - **Net Spending:** \(CurrencyFormatter.format(summary.totalSpend - summary.creditTotal))
        - **Total Transactions:** \(summary.transactionCount)
        - **Average Daily Spending:** \(CurrencyFormatter.format(summary.averageDaily))
        - **Average Per Transaction:** \(CurrencyFormatter.format(summary.averagePerTransaction))
        - **Highest Single Charge:** \(CurrencyFormatter.format(summary.highestSingle))
        - **Top Merchant:** \(summary.highestMerchant)

        ## Monthly Breakdown

        """

        for m in monthly {
            report += "- **\(m.monthLabel):** \(CurrencyFormatter.format(m.totalAmount))\n"
        }

        report += "\n## Category Breakdown\n\n"

        for cat in byCategory {
            report += "- **\(cat.categoryName):** \(CurrencyFormatter.format(cat.totalAmount)) (\(String(format: "%.1f%%", cat.percentage))) — \(cat.transactionCount) transactions\n"
        }

        report += "\n## Card Breakdown\n\n"

        for card in byCard {
            report += "- **\(card.cardName):** \(CurrencyFormatter.format(card.totalAmount)) (\(card.transactionCount) transactions)\n"
        }

        report += "\n## Top 20 Merchants\n\n"

        for (i, merchant) in topMerchants.enumerated() {
            var line = "\(i + 1). **\(merchant.merchantName)** — \(CurrencyFormatter.format(merchant.totalAmount)) (\(merchant.transactionCount) transactions)"
            if let cat = merchant.categoryName {
                line += " *[\(cat)]*"
            }
            report += line + "\n"
        }

        report += "\n## Month-over-Month Changes\n\n"

        for i in 1..<monthly.count {
            let prev = monthly[i - 1].totalAmount
            let curr = monthly[i].totalAmount
            if prev > 0 {
                let change = Double(truncating: ((curr - prev) / prev * 100) as NSDecimalNumber)
                let arrow = change >= 0 ? "+" : ""
                report += "- \(monthly[i - 1].monthLabel) → \(monthly[i].monthLabel): **\(arrow)\(String(format: "%.1f", change))%**\n"
            }
        }

        return report
    }

    func generateMonthly(year: Int, month: Int) -> String {
        let monthNames = ["January", "February", "March", "April", "May", "June",
                          "July", "August", "September", "October", "November", "December"]
        let monthName = monthNames[month - 1]

        let startDate = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!

        let summary = engine.summaryStats(from: startDate, to: endDate)
        let byCategory = engine.spendingByCategory(from: startDate, to: endDate)
        let byCard = engine.spendingByCard(from: startDate, to: endDate)
        let topMerchants = engine.topMerchants(from: startDate, to: endDate, limit: 20)
        let credits = engine.creditDetails(from: startDate, to: endDate)

        let netSpending = summary.totalSpend - summary.creditTotal

        var report = """
        # Monthly Spending Report — \(monthName) \(year)

        ## Summary
        - **Total Spending:** \(CurrencyFormatter.format(summary.totalSpend))
        - **Credits/Payments:** \(CurrencyFormatter.format(summary.creditTotal)) (\(summary.creditCount) transactions)
        - **Net Spending:** \(CurrencyFormatter.format(netSpending))
        - **Total Transactions:** \(summary.transactionCount) charges + \(summary.creditCount) credits
        - **Average Daily Spending:** \(CurrencyFormatter.format(summary.averageDaily))
        - **Average Per Transaction:** \(CurrencyFormatter.format(summary.averagePerTransaction))
        - **Highest Single Charge:** \(CurrencyFormatter.format(summary.highestSingle))
        - **Top Merchant:** \(summary.highestMerchant)

        ## Category Breakdown

        """

        for cat in byCategory {
            report += "- **\(cat.categoryName):** \(CurrencyFormatter.format(cat.totalAmount)) (\(String(format: "%.1f%%", cat.percentage))) — \(cat.transactionCount) transactions\n"
        }

        if !byCard.isEmpty {
            report += "\n## Card Breakdown\n\n"
            for card in byCard {
                report += "- **\(card.cardName):** \(CurrencyFormatter.format(card.totalAmount)) (\(card.transactionCount) transactions)\n"
            }
        }

        report += "\n## Top Merchants\n\n"
        for (i, merchant) in topMerchants.enumerated() {
            var line = "\(i + 1). **\(merchant.merchantName)** — \(CurrencyFormatter.format(merchant.totalAmount)) (\(merchant.transactionCount) transactions)"
            if let cat = merchant.categoryName {
                line += " *[\(cat)]*"
            }
            report += line + "\n"
        }

        if !credits.isEmpty {
            report += "\n## Credits & Payments\n\n"
            for credit in credits {
                report += "- **\(credit.merchantName):** \(CurrencyFormatter.format(credit.totalAmount))"
                if credit.transactionCount > 1 {
                    report += " (\(credit.transactionCount) transactions)"
                }
                report += "\n"
            }
        }

        // Compare with previous month
        if month > 1 {
            let prevStart = Calendar.current.date(from: DateComponents(year: year, month: month - 1, day: 1))!
            let prevEnd = startDate
            let prevSummary = engine.summaryStats(from: prevStart, to: prevEnd)

            if prevSummary.transactionCount > 0 {
                let change = summary.totalSpend - prevSummary.totalSpend
                let pctChange = prevSummary.totalSpend > 0
                    ? Double(truncating: (change / prevSummary.totalSpend * 100) as NSDecimalNumber)
                    : 0.0

                report += "\n## Month-over-Month\n\n"
                report += "- **\(monthNames[month - 2]):** \(CurrencyFormatter.format(prevSummary.totalSpend))\n"
                report += "- **\(monthName):** \(CurrencyFormatter.format(summary.totalSpend))\n"
                report += "- **Change:** \(String(format: "%+.1f%%", pctChange)) (\(change >= 0 ? "+" : "")\(CurrencyFormatter.format(abs(change))))\n"
            }
        }

        return report
    }
}
