import Foundation

struct OptimizationTip: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let details: [String]
    let potentialSavings: Decimal?
    let category: String
    let severity: Severity

    enum Severity: String {
        case info, suggestion, warning
    }
}

final class OptimizationTipGenerator {
    private let engine: AnalysisEngine

    init(engine: AnalysisEngine) {
        self.engine = engine
    }

    func generateTips(from startDate: Date, to endDate: Date) -> [OptimizationTip] {
        var tips: [OptimizationTip] = []

        let summary = engine.summaryStats(from: startDate, to: endDate)
        let byCategory = engine.spendingByCategory(from: startDate, to: endDate)
        let topMerchants = engine.topMerchants(from: startDate, to: endDate, limit: 50)

        // 1. High dining spend (combine Dining Out + Food Delivery + Fast Casual)
        let diningCategories = ["Dining Out", "Food Delivery", "Fast Casual"]
        let diningItems = byCategory.filter { diningCategories.contains($0.categoryName) }
        let totalDiningAmount = diningItems.reduce(Decimal.zero) { $0 + $1.totalAmount }
        let totalDiningCount = diningItems.reduce(0) { $0 + $1.transactionCount }
        let diningPct = diningItems.reduce(0.0) { $0 + $1.percentage }
        if diningPct > 15 {
            let merchantList = topMerchants.filter { diningCategories.contains($0.categoryName ?? "") }.prefix(5)
            tips.append(OptimizationTip(
                title: "Food spending is \(String(format: "%.0f", diningPct))% of total",
                description: "You spent \(CurrencyFormatter.format(totalDiningAmount)) on dining/delivery across \(totalDiningCount) transactions. The recommended budget is under 15% of total spending.",
                details: [
                    "Average per transaction: \(CurrencyFormatter.format(totalDiningAmount / max(Decimal(totalDiningCount), 1)))",
                    "Top merchants:"
                ] + merchantList.map { "  - \($0.merchantName): \(CurrencyFormatter.format($0.totalAmount)) (\($0.transactionCount)x)" } + [
                    "Try meal prepping 2-3 days/week to cut dining costs by 30%",
                    "Consider lunch specials instead of dinner for frequent restaurants"
                ],
                potentialSavings: totalDiningAmount * Decimal(0.3),
                category: "Dining Out",
                severity: .suggestion
            ))
        }

        // 2. Subscription audit (combine Software + Streaming + App Subscriptions)
        let subCategories = ["Software", "Streaming", "App Subscriptions"]
        let subItems = byCategory.filter { subCategories.contains($0.categoryName) }
        let totalSubAmount = subItems.reduce(Decimal.zero) { $0 + $1.totalAmount }
        let totalSubCount = subItems.reduce(0) { $0 + $1.transactionCount }
        if totalSubAmount > 50 {
            let subMerchants = topMerchants.filter { subCategories.contains($0.categoryName ?? "") }
            tips.append(OptimizationTip(
                title: "Monthly subscriptions total \(CurrencyFormatter.format(totalSubAmount))",
                description: "Review each subscription and cancel ones you don't actively use. Many people forget about free trials that converted to paid.",
                details: [
                    "\(totalSubCount) subscription charges detected:",
                ] + subMerchants.map { "  - \($0.merchantName): \(CurrencyFormatter.format($0.totalAmount)) (\($0.transactionCount) charges)" } + [
                    "Ask yourself: Did I use this service in the last 2 weeks?",
                    "Check for annual vs monthly plans — annual often saves 15-20%",
                    "Look for family/shared plans to split costs"
                ],
                potentialSavings: totalSubAmount * Decimal(0.25),
                category: "App Subscriptions",
                severity: .suggestion
            ))
        }

        // 3. Fees detected
        if let fees = byCategory.first(where: { $0.categoryName == "Fees & Interest" }),
           fees.totalAmount > 0 {
            let feeMerchants = topMerchants.filter { $0.categoryName == "Fees & Interest" }
            tips.append(OptimizationTip(
                title: "Fees & interest: \(CurrencyFormatter.format(fees.totalAmount))",
                description: "You're paying unnecessary fees and interest charges. These are 100% avoidable with the right habits.",
                details: feeMerchants.map { "  - \($0.merchantName): \(CurrencyFormatter.format($0.totalAmount))" } + [
                    "Pay statement balance in full every month to avoid interest",
                    "Set up autopay for at least the minimum to avoid late fees",
                    "Call your bank to request a fee waiver — success rate is ~80%",
                    "Consider a no-annual-fee card if you're paying card fees"
                ],
                potentialSavings: fees.totalAmount,
                category: "Fees & Interest",
                severity: .warning
            ))
        }

        // 4. Grocery optimization
        if let groceries = byCategory.first(where: { $0.categoryName == "Groceries" }),
           groceries.totalAmount > 300 {
            let groceryMerchants = topMerchants.filter { $0.categoryName == "Groceries" }.prefix(5)
            let avgPerTrip = groceries.totalAmount / max(Decimal(groceries.transactionCount), 1)
            tips.append(OptimizationTip(
                title: "Grocery spending: \(CurrencyFormatter.format(groceries.totalAmount))",
                description: "You average \(CurrencyFormatter.format(avgPerTrip)) per grocery trip across \(groceries.transactionCount) visits.",
                details: groceryMerchants.map { "  - \($0.merchantName): \(CurrencyFormatter.format($0.totalAmount)) (\($0.transactionCount) trips)" } + [
                    "Try buying in bulk for staples at warehouse stores",
                    "Use grocery store apps for digital coupons and cashback",
                    "Plan meals weekly to reduce impulse purchases and food waste",
                    "Compare prices between your most-visited stores"
                ],
                potentialSavings: groceries.totalAmount * Decimal(0.15),
                category: "Groceries",
                severity: .info
            ))
        }

        // 5. Shopping analysis (combine Online Shopping + In Store Shopping + Luxury + Electronics)
        let shopCategories = ["Online Shopping", "In Store Shopping", "Luxury", "Electronics"]
        let shopItems = byCategory.filter { shopCategories.contains($0.categoryName) }
        let totalShopAmount = shopItems.reduce(Decimal.zero) { $0 + $1.totalAmount }
        let totalShopCount = shopItems.reduce(0) { $0 + $1.transactionCount }
        let shopPct = shopItems.reduce(0.0) { $0 + $1.percentage }
        if shopPct > 20 {
            let shopMerchants = topMerchants.filter { shopCategories.contains($0.categoryName ?? "") }.prefix(5)
            tips.append(OptimizationTip(
                title: "Shopping is \(String(format: "%.0f", shopPct))% of total spending",
                description: "\(CurrencyFormatter.format(totalShopAmount)) spent on shopping across \(totalShopCount) purchases.",
                details: shopMerchants.map { "  - \($0.merchantName): \(CurrencyFormatter.format($0.totalAmount)) (\($0.transactionCount) purchases)" } + [
                    "Implement a 48-hour rule: wait 2 days before non-essential purchases",
                    "Unsubscribe from retailer marketing emails to reduce impulse buys",
                    "Use price tracking tools for items over $50",
                    "Review if any purchases could shift to secondhand or refurbished"
                ],
                potentialSavings: totalShopAmount * Decimal(0.25),
                category: "Online Shopping",
                severity: .suggestion
            ))
        }

        // 6. High-frequency small purchases
        let smallPurchases = topMerchants.filter { $0.transactionCount >= 8 && $0.totalAmount / Decimal($0.transactionCount) < 15 }
        for merchant in smallPurchases.prefix(3) {
            let avgAmount = merchant.totalAmount / Decimal(merchant.transactionCount)
            tips.append(OptimizationTip(
                title: "Frequent purchases at \(merchant.merchantName)",
                description: "\(merchant.transactionCount) visits averaging \(CurrencyFormatter.format(avgAmount)) each, totaling \(CurrencyFormatter.format(merchant.totalAmount)).",
                details: [
                    "That's roughly \(merchant.transactionCount / max(Int(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 30) / 7, 1)) times per week",
                    "Small daily habits are the biggest budget leaks",
                    "If this is coffee: brewing at home saves ~$1,000/year",
                    "If this is food delivery: cooking once more per week saves significantly",
                    "Consider prepaid/gift cards for budgeting at this merchant"
                ],
                potentialSavings: merchant.totalAmount * Decimal(0.4),
                category: merchant.categoryName ?? "Online Shopping",
                severity: .info
            ))
        }

        // 7. Daily spending alert
        if summary.averageDaily > 100 {
            tips.append(OptimizationTip(
                title: "Daily average: \(CurrencyFormatter.format(summary.averageDaily))/day",
                description: "Over \(summary.dayCount) days, you spent \(CurrencyFormatter.format(summary.totalSpend)) total.",
                details: [
                    "Highest single charge: \(CurrencyFormatter.format(summary.highestSingle))",
                    "Average per transaction: \(CurrencyFormatter.format(summary.averagePerTransaction))",
                    "Setting a daily budget of $\(max(Int(truncating: summary.averageDaily * Decimal(0.8) as NSDecimalNumber), 50)) could save \(CurrencyFormatter.format(summary.averageDaily * Decimal(0.2) * Decimal(summary.dayCount)))/month",
                    "Track spending weekly rather than monthly for better awareness",
                    "Use the 50/30/20 rule: 50% needs, 30% wants, 20% savings"
                ],
                potentialSavings: summary.averageDaily * Decimal(0.2) * Decimal(summary.dayCount),
                category: "General",
                severity: .info
            ))
        }

        // 8. Top merchant concentration
        if let topMerchant = topMerchants.first,
           summary.totalSpend > 0 {
            let merchantPct = Double(truncating: (topMerchant.totalAmount / summary.totalSpend * 100) as NSDecimalNumber)
            if merchantPct > 15 {
                tips.append(OptimizationTip(
                    title: "\(topMerchant.merchantName): \(String(format: "%.0f", merchantPct))% of all spending",
                    description: "\(CurrencyFormatter.format(topMerchant.totalAmount)) across \(topMerchant.transactionCount) transactions at a single merchant.",
                    details: [
                        "High concentration at one merchant may indicate:",
                        "  - Lack of price comparison with alternatives",
                        "  - Possible subscription or recurring charges worth reviewing",
                        "  - Opportunity for loyalty rewards optimization",
                        "Check if a competing service offers better rates or cashback",
                        "Look into the merchant's own rewards program if spending is intentional"
                    ],
                    potentialSavings: topMerchant.totalAmount * Decimal(0.15),
                    category: topMerchant.categoryName ?? "Online Shopping",
                    severity: .info
                ))
            }
        }

        // 9. Travel spending (combine Flights + Hotels + Activities & Tours)
        let travelCategories = ["Flights", "Hotels", "Activities & Tours"]
        let travelItems = byCategory.filter { travelCategories.contains($0.categoryName) }
        let totalTravelAmount = travelItems.reduce(Decimal.zero) { $0 + $1.totalAmount }
        let totalTravelCount = travelItems.reduce(0) { $0 + $1.transactionCount }
        if totalTravelAmount > 500 {
            tips.append(OptimizationTip(
                title: "Travel spending: \(CurrencyFormatter.format(totalTravelAmount))",
                description: "\(totalTravelCount) travel-related charges detected.",
                details: topMerchants.filter { travelCategories.contains($0.categoryName ?? "") }.prefix(5).map {
                    "  - \($0.merchantName): \(CurrencyFormatter.format($0.totalAmount))"
                } + [
                    "Book flights 6-8 weeks in advance for best prices",
                    "Use travel credit card points for flights and hotels",
                    "Consider travel insurance for trips over $1,000",
                    "Check if your credit card offers trip protection benefits"
                ],
                potentialSavings: totalTravelAmount * Decimal(0.1),
                category: "Flights",
                severity: .info
            ))
        }

        // 10. Smoke & Tobacco
        if let smoke = byCategory.first(where: { $0.categoryName == "Smoke & Tobacco" }),
           smoke.totalAmount > 0 {
            let monthlyProjected = smoke.totalAmount / max(Decimal(summary.dayCount), 1) * 30
            let yearlyProjected = monthlyProjected * 12
            tips.append(OptimizationTip(
                title: "Tobacco spending: \(CurrencyFormatter.format(smoke.totalAmount))",
                description: "Projected annual cost: \(CurrencyFormatter.format(yearlyProjected)). This is fully avoidable spending with significant health benefits.",
                details: [
                    "Monthly projection: \(CurrencyFormatter.format(monthlyProjected))",
                    "Annual projection: \(CurrencyFormatter.format(yearlyProjected))",
                    "Quitting saves both money and healthcare costs long-term",
                    "Many insurance plans cover cessation programs at no cost"
                ],
                potentialSavings: smoke.totalAmount,
                category: "Smoke & Tobacco",
                severity: .warning
            ))
        }

        return tips.sorted { severityOrder($0.severity) > severityOrder($1.severity) }
    }

    private func severityOrder(_ severity: OptimizationTip.Severity) -> Int {
        switch severity {
        case .warning: 3
        case .suggestion: 2
        case .info: 1
        }
    }
}
