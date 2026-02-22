import XCTest
import SwiftData
@testable import Spender

@MainActor
final class ClassificationCacheTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            Transaction.self, SpendingCategory.self, Card.self,
            ImportSession.self, ClassificationCache.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - Helpers

    private func insertDefaultCategories() {
        for (i, def) in SpendingCategory.defaults.enumerated() {
            let cat = SpendingCategory(name: def.name, iconName: def.icon, colorHex: def.color, sortOrder: i)
            context.insert(cat)
        }
        try! context.save()
    }

    private func makeTransaction(raw: String, clean: String = "", amount: Decimal = 10.0) -> Transaction {
        let txn = Transaction(
            date: Date(),
            rawDescription: raw,
            cleanDescription: clean.isEmpty ? raw : clean,
            amount: amount,
            isCredit: false
        )
        context.insert(txn)
        return txn
    }

    private func fetchCategory(named name: String) -> SpendingCategory? {
        let descriptor = FetchDescriptor<SpendingCategory>(
            predicate: #Predicate<SpendingCategory> { $0.name == name }
        )
        return try? context.fetch(descriptor).first
    }

    private func fetchAllCache() -> [ClassificationCache] {
        (try? context.fetch(FetchDescriptor<ClassificationCache>())) ?? []
    }

    // MARK: - Override Category Propagation

    func testOverrideCategoryPropagatesToMatchingTransactions() throws {
        insertDefaultCategories()
        let engine = ClassificationEngine(modelContext: context)

        let txn1 = makeTransaction(raw: "AMAZON.COM*ABC12345")
        let txn2 = makeTransaction(raw: "AMAZON.COM*XYZ67890")
        try context.save()

        let shopping = fetchCategory(named: "Online Shopping")!
        engine.overrideCategory(for: txn1, to: shopping)

        XCTAssertEqual(txn1.category?.name, "Online Shopping")
        XCTAssertEqual(txn2.category?.name, "Online Shopping", "Override should propagate to matching transactions")
        XCTAssertTrue(txn1.categoryOverridden)
        XCTAssertTrue(txn2.categoryOverridden)
    }

    func testOverrideCategoryDoesNotAffectDifferentMerchant() throws {
        insertDefaultCategories()
        let engine = ClassificationEngine(modelContext: context)

        let amazon = makeTransaction(raw: "AMAZON.COM*ABC12345")
        let walmart = makeTransaction(raw: "WALMART STORE #1234")
        try context.save()

        let shopping = fetchCategory(named: "Online Shopping")!
        engine.overrideCategory(for: amazon, to: shopping)

        XCTAssertEqual(amazon.category?.name, "Online Shopping")
        XCTAssertNil(walmart.category, "Different merchants should not be affected")
    }

    // MARK: - Override Category Updates Cache

    func testOverrideCategoryCreatesCache() throws {
        insertDefaultCategories()
        let engine = ClassificationEngine(modelContext: context)

        let txn = makeTransaction(raw: "STARBUCKS #12345", clean: "Starbucks")
        try context.save()

        let dining = fetchCategory(named: "Dining Out")!
        engine.overrideCategory(for: txn, to: dining)

        let cacheEntries = fetchAllCache()
        let normalized = ClassificationEngine.normalizePattern("STARBUCKS #12345")
        let match = cacheEntries.first { $0.merchantPattern == normalized }
        XCTAssertNotNil(match, "Cache entry should exist after override")
        XCTAssertEqual(match?.categoryName, "Dining Out")
        XCTAssertEqual(match?.cleanName, "Starbucks")
    }

    // MARK: - Override Description Propagation

    func testOverrideDescriptionPropagatesToMatchingTransactions() throws {
        insertDefaultCategories()
        let engine = ClassificationEngine(modelContext: context)

        let txn1 = makeTransaction(raw: "AMZN.COM*2K7HJ1LA0", clean: "AMZN.COM")
        let txn2 = makeTransaction(raw: "AMZN.COM*3X9YZ2MB1", clean: "AMZN.COM")
        try context.save()

        engine.overrideDescription(for: txn1, to: "Amazon")

        XCTAssertEqual(txn1.cleanDescription, "Amazon")
        XCTAssertEqual(txn2.cleanDescription, "Amazon", "Description override should propagate")
    }

    func testOverrideDescriptionDoesNotAffectDifferentMerchant() throws {
        insertDefaultCategories()
        let engine = ClassificationEngine(modelContext: context)

        let txn1 = makeTransaction(raw: "UBER   *EATS", clean: "UBER EATS")
        let txn2 = makeTransaction(raw: "LYFT *RIDE", clean: "LYFT RIDE")
        try context.save()

        engine.overrideDescription(for: txn1, to: "Uber Eats")

        XCTAssertEqual(txn1.cleanDescription, "Uber Eats")
        XCTAssertEqual(txn2.cleanDescription, "LYFT RIDE", "Different merchants should not be affected")
    }

    // MARK: - Cache Upsert

    func testCacheUpsertUpdatesExistingEntry() throws {
        insertDefaultCategories()
        let engine = ClassificationEngine(modelContext: context)

        let txn = makeTransaction(raw: "NETFLIX", clean: "Netflix")
        try context.save()

        let entertainment = fetchCategory(named: "Entertainment")!
        engine.overrideCategory(for: txn, to: entertainment)

        var entries = fetchAllCache().filter { $0.merchantPattern == "netflix" }
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.categoryName, "Entertainment")

        let streaming = fetchCategory(named: "Streaming")!
        engine.overrideCategory(for: txn, to: streaming)

        entries = fetchAllCache().filter { $0.merchantPattern == "netflix" }
        XCTAssertEqual(entries.count, 1, "Should upsert, not create duplicate cache entries")
        XCTAssertEqual(entries.first?.categoryName, "Streaming")
    }

    // MARK: - Cache Stores Normalized Pattern

    func testCacheUsesNormalizedPattern() throws {
        insertDefaultCategories()
        let engine = ClassificationEngine(modelContext: context)

        let txn = makeTransaction(raw: "TST* CHIPOTLE ONLINE   SAN FRANCISCO CA 94105", clean: "Chipotle")
        try context.save()

        let dining = fetchCategory(named: "Dining Out")!
        engine.overrideCategory(for: txn, to: dining)

        let normalized = ClassificationEngine.normalizePattern(txn.rawDescription)
        let match = fetchAllCache().first { $0.merchantPattern == normalized }
        XCTAssertNotNil(match)
        XCTAssertFalse(normalized.contains("tst"), "Normalized pattern should not contain prefix")
        XCTAssertFalse(normalized.contains("94105"), "Normalized pattern should not contain zip code")
    }

    // MARK: - Skips Already Overridden Transactions

    func testOverrideCategorySetsOverriddenFlag() throws {
        insertDefaultCategories()
        let engine = ClassificationEngine(modelContext: context)

        let txn = makeTransaction(raw: "COFFEE SHOP")
        XCTAssertFalse(txn.categoryOverridden)
        try context.save()

        let dining = fetchCategory(named: "Dining Out")!
        engine.overrideCategory(for: txn, to: dining)

        XCTAssertTrue(txn.categoryOverridden, "Override should set categoryOverridden flag")
    }
}
