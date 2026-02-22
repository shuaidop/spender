import Foundation
import SwiftData

@Observable
final class AnalysisEngine {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func transactions(from startDate: Date, to endDate: Date, card: Card? = nil) -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { txn in
                txn.date >= startDate && txn.date < endDate
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        let all = (try? modelContext.fetch(descriptor)) ?? []

        if let card {
            return all.filter { $0.card?.id == card.id }
        }
        return all
    }

    func spendingByCategory(from startDate: Date, to endDate: Date, card: Card? = nil) -> [CategorySpending] {
        let txns = transactions(from: startDate, to: endDate, card: card)

        var grouped: [String: (amount: Decimal, count: Int, icon: String, color: String)] = [:]

        for txn in txns {
            let name = txn.category?.name ?? "Uncategorized"
            let icon = txn.category?.iconName ?? "questionmark.circle.fill"
            let color = txn.category?.colorHex ?? "#95A5A6"
            var entry = grouped[name] ?? (amount: 0, count: 0, icon: icon, color: color)
            // Credits subtract from the category total
            if txn.isCredit {
                entry.amount -= abs(txn.amount)
            } else {
                entry.amount += txn.amount
            }
            entry.count += 1
            grouped[name] = entry
        }

        // Filter out categories with zero or negative net totals, compute percentages from positive ones
        let positiveCategories = grouped.filter { $0.value.amount > 0 }
        let totalAmount = positiveCategories.values.reduce(Decimal.zero) { $0 + $1.amount }
        guard totalAmount > 0 else { return [] }

        return positiveCategories.map { name, data in
            CategorySpending(
                categoryName: name,
                iconName: data.icon,
                colorHex: data.color,
                totalAmount: data.amount,
                percentage: Double(truncating: (data.amount / totalAmount * 100) as NSDecimalNumber),
                transactionCount: data.count
            )
        }
        .sorted { $0.totalAmount > $1.totalAmount }
    }

    func spendingByCard(from startDate: Date, to endDate: Date) -> [CardSpending] {
        let txns = transactions(from: startDate, to: endDate)
            .filter { !$0.isCredit }

        var grouped: [String: (amount: Decimal, count: Int, color: String)] = [:]

        for txn in txns {
            let name = txn.card?.displayName ?? "Unknown Card"
            let color = txn.card?.colorHex ?? "#95A5A6"
            var entry = grouped[name] ?? (amount: 0, count: 0, color: color)
            entry.amount += txn.amount
            entry.count += 1
            grouped[name] = entry
        }

        return grouped.map { name, data in
            CardSpending(
                cardName: name,
                colorHex: data.color,
                totalAmount: data.amount,
                transactionCount: data.count
            )
        }
        .sorted { $0.totalAmount > $1.totalAmount }
    }

    func topMerchants(from startDate: Date, to endDate: Date, limit: Int = 10) -> [MerchantSpending] {
        let txns = transactions(from: startDate, to: endDate)
            .filter { !$0.isCredit }

        var grouped: [String: (amount: Decimal, count: Int, category: String?)] = [:]

        for txn in txns {
            let name = txn.cleanDescription
            var entry = grouped[name] ?? (amount: 0, count: 0, category: txn.category?.name)
            entry.amount += txn.amount
            entry.count += 1
            grouped[name] = entry
        }

        return grouped.map { name, data in
            MerchantSpending(
                merchantName: name,
                totalAmount: data.amount,
                transactionCount: data.count,
                categoryName: data.category
            )
        }
        .sorted { $0.totalAmount > $1.totalAmount }
        .prefix(limit)
        .map { $0 }
    }

    func monthlyTotals(year: Int) -> [MonthlyTotal] {
        let yearStr = String(year)
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.yearKey == yearStr }
        )

        let allTxns = (try? modelContext.fetch(descriptor)) ?? []

        var monthlyCharges: [String: Decimal] = [:]
        var monthlyCredits: [String: Decimal] = [:]
        for txn in allTxns {
            if txn.isCredit {
                monthlyCredits[txn.monthKey, default: 0] += txn.amount
            } else {
                monthlyCharges[txn.monthKey, default: 0] += txn.amount
            }
        }

        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        return (1...12).map { month in
            let key = String(format: "%04d-%02d", year, month)
            return MonthlyTotal(
                monthKey: key,
                monthLabel: monthNames[month - 1],
                totalAmount: monthlyCharges[key] ?? 0,
                creditAmount: monthlyCredits[key] ?? 0
            )
        }
    }

    func creditDetails(from startDate: Date, to endDate: Date, card: Card? = nil) -> [MerchantSpending] {
        let txns = transactions(from: startDate, to: endDate, card: card)
            .filter { $0.isCredit }

        var grouped: [String: (amount: Decimal, count: Int, category: String?)] = [:]

        for txn in txns {
            let name = txn.cleanDescription
            var entry = grouped[name] ?? (amount: 0, count: 0, category: txn.category?.name)
            entry.amount += txn.amount
            entry.count += 1
            grouped[name] = entry
        }

        return grouped.map { name, data in
            MerchantSpending(
                merchantName: name,
                totalAmount: data.amount,
                transactionCount: data.count,
                categoryName: data.category
            )
        }
        .sorted { $0.totalAmount > $1.totalAmount }
    }

    func summaryStats(from startDate: Date, to endDate: Date) -> SpendingSummary {
        let txns = transactions(from: startDate, to: endDate)
        let charges = txns.filter { !$0.isCredit }
        let credits = txns.filter { $0.isCredit }

        let totalSpend = charges.reduce(Decimal.zero) { $0 + $1.amount }
        let creditTotal = credits.reduce(Decimal.zero) { $0 + abs($1.amount) }
        let dayCount = max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
        let avgDaily = totalSpend / Decimal(dayCount)
        let avgPerTxn = charges.isEmpty ? Decimal.zero : totalSpend / Decimal(charges.count)
        let highest = charges.max(by: { $0.amount < $1.amount })

        // Find top merchant
        var merchantTotals: [String: Decimal] = [:]
        for txn in charges {
            merchantTotals[txn.cleanDescription, default: 0] += txn.amount
        }
        let topMerchant = merchantTotals.max(by: { $0.value < $1.value })?.key ?? "N/A"

        return SpendingSummary(
            totalSpend: totalSpend,
            averageDaily: avgDaily,
            averagePerTransaction: avgPerTxn,
            highestSingle: highest?.amount ?? 0,
            highestMerchant: topMerchant,
            transactionCount: charges.count,
            dayCount: dayCount,
            creditTotal: creditTotal,
            creditCount: credits.count
        )
    }
}
