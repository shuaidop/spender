import XCTest
import SwiftData
@testable import Spender

@MainActor
final class AnalysisEngineTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var engine: AnalysisEngine!

    override func setUp() async throws {
        let schema = Schema([
            Transaction.self, SpendingCategory.self, Card.self,
            ImportSession.self, ClassificationCache.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        engine = AnalysisEngine(modelContext: context)
    }

    override func tearDown() async throws {
        engine = nil
        container = nil
        context = nil
    }

    // MARK: - Helpers

    private func makeDate(_ str: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str)!
    }

    private func makeCategory(name: String) -> SpendingCategory {
        let cat = SpendingCategory(name: name, iconName: "circle", colorHex: "#FF0000")
        context.insert(cat)
        return cat
    }

    private func makeCard(bank: String, name: String) -> Card {
        let card = Card(bankName: bank, cardName: name, lastFourDigits: "1234")
        context.insert(card)
        return card
    }

    @discardableResult
    private func makeTransaction(
        date: String,
        description: String,
        amount: Decimal,
        isCredit: Bool = false,
        category: SpendingCategory? = nil,
        card: Card? = nil
    ) -> Transaction {
        let txn = Transaction(
            date: makeDate(date),
            rawDescription: description,
            cleanDescription: description,
            amount: amount,
            isCredit: isCredit,
            card: card
        )
        txn.category = category
        context.insert(txn)
        return txn
    }

    // MARK: - Transaction Fetching

    func testFetchesTransactionsInDateRange() throws {
        makeTransaction(date: "2026-01-10", description: "Store A", amount: 10)
        makeTransaction(date: "2026-01-20", description: "Store B", amount: 20)
        makeTransaction(date: "2026-02-05", description: "Store C", amount: 30)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.transactions(from: start, to: end)

        XCTAssertEqual(result.count, 2)
    }

    func testFetchesTransactionsFilteredByCard() throws {
        let chase = makeCard(bank: "Chase", name: "Sapphire")
        let amex = makeCard(bank: "Amex", name: "Platinum")

        makeTransaction(date: "2026-01-10", description: "Store A", amount: 10, card: chase)
        makeTransaction(date: "2026-01-15", description: "Store B", amount: 20, card: amex)
        makeTransaction(date: "2026-01-20", description: "Store C", amount: 30, card: chase)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.transactions(from: start, to: end, card: chase)

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.card?.id == chase.id })
    }

    // MARK: - Spending by Category

    func testSpendingByCategoryGroupsCorrectly() throws {
        let dining = makeCategory(name: "Dining")
        let shopping = makeCategory(name: "Shopping")

        makeTransaction(date: "2026-01-10", description: "Restaurant A", amount: 50, category: dining)
        makeTransaction(date: "2026-01-12", description: "Restaurant B", amount: 30, category: dining)
        makeTransaction(date: "2026-01-15", description: "Amazon", amount: 100, category: shopping)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.spendingByCategory(from: start, to: end)

        XCTAssertEqual(result.count, 2)

        let diningSpend = result.first { $0.categoryName == "Dining" }
        let shoppingSpend = result.first { $0.categoryName == "Shopping" }

        XCTAssertNotNil(diningSpend)
        XCTAssertNotNil(shoppingSpend)
        XCTAssertEqual(diningSpend?.totalAmount, 80)
        XCTAssertEqual(shoppingSpend?.totalAmount, 100)
        XCTAssertEqual(diningSpend?.transactionCount, 2)
        XCTAssertEqual(shoppingSpend?.transactionCount, 1)
    }

    func testSpendingByCategorySubtractsCredits() throws {
        let dining = makeCategory(name: "Dining")

        makeTransaction(date: "2026-01-10", description: "Restaurant", amount: 50, category: dining)
        makeTransaction(date: "2026-01-12", description: "Refund", amount: 20, isCredit: true, category: dining)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.spendingByCategory(from: start, to: end)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.totalAmount, 30, "Credits should be subtracted from category total")
        XCTAssertEqual(result.first?.transactionCount, 2)
    }

    func testSpendingByCategoryPercentages() throws {
        let dining = makeCategory(name: "Dining")
        let shopping = makeCategory(name: "Shopping")

        makeTransaction(date: "2026-01-10", description: "Restaurant", amount: 75, category: dining)
        makeTransaction(date: "2026-01-15", description: "Amazon", amount: 25, category: shopping)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.spendingByCategory(from: start, to: end)

        let diningPct = result.first { $0.categoryName == "Dining" }?.percentage ?? 0
        let shoppingPct = result.first { $0.categoryName == "Shopping" }?.percentage ?? 0

        XCTAssertEqual(diningPct, 75, accuracy: 0.01)
        XCTAssertEqual(shoppingPct, 25, accuracy: 0.01)
    }

    func testSpendingByCategorySortedByAmount() throws {
        let dining = makeCategory(name: "Dining")
        let shopping = makeCategory(name: "Shopping")
        let travel = makeCategory(name: "Travel")

        makeTransaction(date: "2026-01-10", description: "Restaurant", amount: 50, category: dining)
        makeTransaction(date: "2026-01-12", description: "Amazon", amount: 200, category: shopping)
        makeTransaction(date: "2026-01-14", description: "Hotel", amount: 100, category: travel)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.spendingByCategory(from: start, to: end)

        XCTAssertEqual(result.first?.categoryName, "Shopping", "Highest spending category should be first")
    }

    func testSpendingByCategoryHandlesUncategorized() throws {
        makeTransaction(date: "2026-01-10", description: "Unknown Store", amount: 50)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.spendingByCategory(from: start, to: end)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.categoryName, "Uncategorized")
    }

    // MARK: - Spending by Card

    func testSpendingByCardGroupsCorrectly() throws {
        let chase = makeCard(bank: "Chase", name: "Sapphire")
        let amex = makeCard(bank: "Amex", name: "Platinum")

        makeTransaction(date: "2026-01-10", description: "Store A", amount: 100, card: chase)
        makeTransaction(date: "2026-01-12", description: "Store B", amount: 200, card: amex)
        makeTransaction(date: "2026-01-14", description: "Store C", amount: 50, card: chase)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.spendingByCard(from: start, to: end)

        XCTAssertEqual(result.count, 2)

        let chaseSpend = result.first { $0.cardName.contains("Chase") }
        let amexSpend = result.first { $0.cardName.contains("Amex") }

        XCTAssertEqual(chaseSpend?.totalAmount, 150)
        XCTAssertEqual(amexSpend?.totalAmount, 200)
    }

    func testSpendingByCardExcludesCredits() throws {
        let card = makeCard(bank: "Chase", name: "Freedom")

        makeTransaction(date: "2026-01-10", description: "Purchase", amount: 100, card: card)
        makeTransaction(date: "2026-01-12", description: "Payment", amount: 500, isCredit: true, card: card)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.spendingByCard(from: start, to: end)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.totalAmount, 100)
    }

    // MARK: - Top Merchants

    func testTopMerchantsRanking() throws {
        makeTransaction(date: "2026-01-10", description: "Amazon", amount: 50)
        makeTransaction(date: "2026-01-12", description: "Amazon", amount: 75)
        makeTransaction(date: "2026-01-14", description: "Starbucks", amount: 5)
        makeTransaction(date: "2026-01-15", description: "Starbucks", amount: 6)
        makeTransaction(date: "2026-01-16", description: "Starbucks", amount: 4)
        makeTransaction(date: "2026-01-18", description: "Netflix", amount: 15)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.topMerchants(from: start, to: end)

        XCTAssertEqual(result.first?.merchantName, "Amazon", "Highest spending merchant should be first")
        XCTAssertEqual(result.first?.totalAmount, 125)
        XCTAssertEqual(result.first?.transactionCount, 2)
    }

    func testTopMerchantsRespectsLimit() throws {
        for i in 1...15 {
            makeTransaction(date: "2026-01-\(String(format: "%02d", min(i, 28)))", description: "Merchant \(i)", amount: Decimal(i * 10))
        }
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.topMerchants(from: start, to: end, limit: 5)

        XCTAssertEqual(result.count, 5, "Should respect the limit parameter")
    }

    func testTopMerchantsExcludesCredits() throws {
        makeTransaction(date: "2026-01-10", description: "Amazon", amount: 50)
        makeTransaction(date: "2026-01-12", description: "Amazon Refund", amount: 25, isCredit: true)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.topMerchants(from: start, to: end)

        XCTAssertEqual(result.count, 1, "Credits should be excluded from top merchants")
    }

    // MARK: - Monthly Totals

    func testMonthlyTotalsReturns12Months() throws {
        makeTransaction(date: "2026-01-15", description: "Jan Purchase", amount: 100)
        makeTransaction(date: "2026-03-15", description: "Mar Purchase", amount: 200)
        try context.save()

        let result = engine.monthlyTotals(year: 2026)

        XCTAssertEqual(result.count, 12, "Should return 12 months")
        XCTAssertEqual(result[0].monthKey, "2026-01")
        XCTAssertEqual(result[0].monthLabel, "Jan")
        XCTAssertEqual(result[11].monthKey, "2026-12")
        XCTAssertEqual(result[11].monthLabel, "Dec")
    }

    func testMonthlyTotalsAccumulatesCorrectly() throws {
        makeTransaction(date: "2026-01-10", description: "Purchase 1", amount: 50)
        makeTransaction(date: "2026-01-20", description: "Purchase 2", amount: 75)
        makeTransaction(date: "2026-02-15", description: "Purchase 3", amount: 100)
        try context.save()

        let result = engine.monthlyTotals(year: 2026)

        XCTAssertEqual(result[0].totalAmount, 125, "January total should be 125")
        XCTAssertEqual(result[1].totalAmount, 100, "February total should be 100")
        XCTAssertEqual(result[2].totalAmount, 0, "March total should be 0")
    }

    func testMonthlyTotalsExcludesCredits() throws {
        makeTransaction(date: "2026-01-10", description: "Purchase", amount: 100)
        makeTransaction(date: "2026-01-15", description: "Payment", amount: 500, isCredit: true)
        try context.save()

        let result = engine.monthlyTotals(year: 2026)

        XCTAssertEqual(result[0].totalAmount, 100, "Credits should be excluded from monthly totals")
    }

    // MARK: - Summary Stats

    func testSummaryStatsCalculation() throws {
        makeTransaction(date: "2026-01-05", description: "Small Purchase", amount: 10)
        makeTransaction(date: "2026-01-10", description: "Big Purchase", amount: 200)
        makeTransaction(date: "2026-01-15", description: "Medium Purchase", amount: 90)
        makeTransaction(date: "2026-01-20", description: "Payment", amount: 300, isCredit: true)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.summaryStats(from: start, to: end)

        XCTAssertEqual(result.totalSpend, 300, "Total should sum non-credit amounts")
        XCTAssertEqual(result.transactionCount, 3, "Should count only charges")
        XCTAssertEqual(result.highestSingle, 200, "Highest single should be 200")
        XCTAssertEqual(result.averagePerTransaction, 100, "Average should be 100")
        XCTAssertEqual(result.creditTotal, 300, "Credit total should be 300")
    }

    func testSummaryStatsDayCount() throws {
        makeTransaction(date: "2026-01-15", description: "Purchase", amount: 100)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-01-31")
        let result = engine.summaryStats(from: start, to: end)

        XCTAssertEqual(result.dayCount, 30, "Day count should be 30 (Jan 1 to Jan 31)")
    }

    func testSummaryStatsTopMerchant() throws {
        makeTransaction(date: "2026-01-10", description: "Amazon", amount: 50)
        makeTransaction(date: "2026-01-12", description: "Amazon", amount: 75)
        makeTransaction(date: "2026-01-14", description: "Starbucks", amount: 10)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.summaryStats(from: start, to: end)

        XCTAssertEqual(result.highestMerchant, "Amazon", "Top merchant by spend should be Amazon")
    }

    func testSummaryStatsEmptyRange() throws {
        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.summaryStats(from: start, to: end)

        XCTAssertEqual(result.totalSpend, 0)
        XCTAssertEqual(result.transactionCount, 0)
        XCTAssertEqual(result.creditTotal, 0)
    }

    // MARK: - Edge Cases

    func testEmptyDateRange() throws {
        makeTransaction(date: "2026-01-15", description: "Outside Range", amount: 50)
        try context.save()

        let start = makeDate("2026-06-01")
        let end = makeDate("2026-07-01")
        let result = engine.transactions(from: start, to: end)

        XCTAssertEqual(result.count, 0)
    }

    func testSpendingByCategoryReturnsEmptyForNoCharges() throws {
        makeTransaction(date: "2026-01-10", description: "Payment", amount: 500, isCredit: true)
        try context.save()

        let start = makeDate("2026-01-01")
        let end = makeDate("2026-02-01")
        let result = engine.spendingByCategory(from: start, to: end)

        XCTAssertEqual(result.count, 0, "No charges means no category spending")
    }
}
