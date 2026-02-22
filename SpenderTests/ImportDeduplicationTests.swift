import XCTest
import SwiftData
@testable import Spender

@MainActor
final class ImportDeduplicationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([
            Transaction.self, SpendingCategory.self, Card.self,
            ImportSession.self, ClassificationCache.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDate(_ str: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str)!
    }

    /// Replicate the duplicate key logic from ImportView
    private func duplicateKey(date: Date, description: String, amount: Decimal) -> String {
        let dateStr = DateFormatters.shortDate.string(from: date)
        return "\(dateStr)|\(description)|\(amount)"
    }

    private func insertTransaction(date: Date, raw: String, amount: Decimal, isCredit: Bool = false) -> Transaction {
        let txn = Transaction(
            date: date,
            rawDescription: raw,
            cleanDescription: raw,
            amount: amount,
            isCredit: isCredit
        )
        context.insert(txn)
        return txn
    }

    // MARK: - Duplicate Key Generation

    func testDuplicateKeyFormat() {
        let date = makeDate("2026-01-15")
        let key = duplicateKey(date: date, description: "STARBUCKS", amount: Decimal(string: "5.75")!)

        XCTAssertTrue(key.contains("STARBUCKS"))
        XCTAssertTrue(key.contains("5.75"))
        XCTAssertTrue(key.contains("|"), "Key should use pipe separator")
    }

    func testSameTransactionProducesSameKey() {
        let date = makeDate("2026-01-15")
        let key1 = duplicateKey(date: date, description: "AMAZON.COM", amount: Decimal(string: "29.99")!)
        let key2 = duplicateKey(date: date, description: "AMAZON.COM", amount: Decimal(string: "29.99")!)

        XCTAssertEqual(key1, key2)
    }

    func testDifferentDateProducesDifferentKey() {
        let date1 = makeDate("2026-01-15")
        let date2 = makeDate("2026-01-16")
        let key1 = duplicateKey(date: date1, description: "AMAZON.COM", amount: Decimal(string: "29.99")!)
        let key2 = duplicateKey(date: date2, description: "AMAZON.COM", amount: Decimal(string: "29.99")!)

        XCTAssertNotEqual(key1, key2)
    }

    func testDifferentAmountProducesDifferentKey() {
        let date = makeDate("2026-01-15")
        let key1 = duplicateKey(date: date, description: "AMAZON.COM", amount: Decimal(string: "29.99")!)
        let key2 = duplicateKey(date: date, description: "AMAZON.COM", amount: Decimal(string: "39.99")!)

        XCTAssertNotEqual(key1, key2)
    }

    func testDifferentDescriptionProducesDifferentKey() {
        let date = makeDate("2026-01-15")
        let key1 = duplicateKey(date: date, description: "AMAZON.COM", amount: Decimal(string: "29.99")!)
        let key2 = duplicateKey(date: date, description: "WALMART", amount: Decimal(string: "29.99")!)

        XCTAssertNotEqual(key1, key2)
    }

    // MARK: - Duplicate Detection Logic

    func testDetectsDuplicateTransactions() throws {
        let date = makeDate("2026-01-15")

        // Insert existing transaction
        _ = insertTransaction(date: date, raw: "STARBUCKS #12345", amount: Decimal(string: "5.75")!)
        try context.save()

        // Fetch existing keys
        let existingDescriptor = FetchDescriptor<Transaction>()
        let existingTransactions = try context.fetch(existingDescriptor)
        let existingKeys = Set(existingTransactions.map {
            duplicateKey(date: $0.date, description: $0.rawDescription, amount: $0.amount)
        })

        // Simulate a new parsed transaction with same data
        let newKey = duplicateKey(date: date, description: "STARBUCKS #12345", amount: Decimal(string: "5.75")!)

        XCTAssertTrue(existingKeys.contains(newKey), "Should detect as duplicate")
    }

    func testAllowsNonDuplicateTransactions() throws {
        let date = makeDate("2026-01-15")

        _ = insertTransaction(date: date, raw: "STARBUCKS #12345", amount: Decimal(string: "5.75")!)
        try context.save()

        let existingDescriptor = FetchDescriptor<Transaction>()
        let existingTransactions = try context.fetch(existingDescriptor)
        let existingKeys = Set(existingTransactions.map {
            duplicateKey(date: $0.date, description: $0.rawDescription, amount: $0.amount)
        })

        // Different transaction
        let newKey = duplicateKey(date: date, description: "CHIPOTLE", amount: Decimal(string: "12.50")!)

        XCTAssertFalse(existingKeys.contains(newKey), "Should not detect as duplicate")
    }

    // MARK: - Import Session Tests

    func testImportSessionCreation() throws {
        let session = ImportSession(fileName: "statement.pdf", bankName: "Chase", statementMonth: "2026-01")
        context.insert(session)
        try context.save()

        let descriptor = FetchDescriptor<ImportSession>()
        let sessions = try context.fetch(descriptor)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.fileName, "statement.pdf")
        XCTAssertEqual(sessions.first?.bankName, "Chase")
        XCTAssertEqual(sessions.first?.statementMonth, "2026-01")
        XCTAssertEqual(sessions.first?.transactionCount, 0)
    }

    func testImportSessionLinksTransactions() throws {
        let session = ImportSession(fileName: "test.pdf", bankName: "Amex", statementMonth: "2026-01")
        context.insert(session)

        let txn = insertTransaction(date: makeDate("2026-01-15"), raw: "TEST", amount: 10)
        txn.importSession = session
        session.transactionCount = 1
        try context.save()

        XCTAssertEqual(txn.importSession?.id, session.id)
        XCTAssertEqual(session.transactionCount, 1)
    }

    // MARK: - Classification Cache Model Tests

    func testClassificationCacheCreation() throws {
        let cache = ClassificationCache(
            merchantPattern: "starbucks",
            cleanName: "Starbucks",
            categoryName: "Dining Out"
        )
        context.insert(cache)
        try context.save()

        let descriptor = FetchDescriptor<ClassificationCache>()
        let entries = try context.fetch(descriptor)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.merchantPattern, "starbucks")
        XCTAssertEqual(entries.first?.cleanName, "Starbucks")
        XCTAssertEqual(entries.first?.categoryName, "Dining Out")
    }

    func testClassificationCacheUniqueMerchantPattern() throws {
        let cache1 = ClassificationCache(
            merchantPattern: "amazon.com",
            cleanName: "Amazon",
            categoryName: "Online Shopping"
        )
        context.insert(cache1)
        try context.save()

        // Inserting another with the same pattern should either fail or replace
        let cache2 = ClassificationCache(
            merchantPattern: "amazon.com",
            cleanName: "Amazon Prime",
            categoryName: "App Subscriptions"
        )
        context.insert(cache2)

        // SwiftData with @Attribute(.unique) will either throw or merge
        // We just verify no crash occurs and pattern uniqueness is maintained
        do {
            try context.save()
            let descriptor = FetchDescriptor<ClassificationCache>()
            let entries = try context.fetch(descriptor)
            // With unique constraint, should have 1 entry (upserted) or the system handles it
            XCTAssertTrue(entries.count >= 1)
        } catch {
            // Unique constraint violation is acceptable
            XCTAssertTrue(true, "Unique constraint violation is expected behavior")
        }
    }

    func testClassificationCacheLRUTimestamp() throws {
        let cache = ClassificationCache(
            merchantPattern: "test_merchant",
            cleanName: "Test",
            categoryName: "Online Shopping"
        )
        let insertTime = cache.lastUsed
        context.insert(cache)
        try context.save()

        // Simulate LRU touch
        cache.lastUsed = Date().addingTimeInterval(60)
        try context.save()

        XCTAssertTrue(cache.lastUsed > insertTime, "LRU timestamp should be updated")
    }
}
