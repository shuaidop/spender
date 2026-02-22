import Foundation
import SwiftData

struct ClassificationResult: Codable {
    let name: String
    let category: String
}

@MainActor @Observable
final class ClassificationEngine {
    private let modelContext: ModelContext
    private static let maxCacheSize = 500

    /// In-memory cache snapshot loaded once per classification run
    private var cacheByPattern: [String: ClassificationCache] = [:]
    private var cacheByCleanName: [String: ClassificationCache] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Classify and standardize transactions using LLM, with local cache for known merchants
    func classifyTransactions(_ transactions: [Transaction]) async {
        let openAIService = OpenAIService()
        guard openAIService.isConfigured else { return }

        // Ensure categories exist in this context before classifying
        ensureCategoriesExist()

        // Purge stale cache entries that were saved as "Uncategorized" (from previous failed runs)
        purgeUncategorizedCache()

        // Pre-warm cache from existing classified transactions in the DB
        warmCacheFromExistingTransactions()

        // Load all cache entries into memory for fast lookups
        loadCacheIntoMemory()

        // Separate into cached and uncached
        var toClassify: [Transaction] = []

        for transaction in transactions where !transaction.categoryOverridden {
            if let cached = lookupCacheInMemory(for: transaction.rawDescription),
               cached.categoryName != "Uncategorized" {
                transaction.cleanDescription = cached.cleanName
                assignCategory(cached.categoryName, to: transaction)
            } else {
                toClassify.append(transaction)
            }
        }

        guard !toClassify.isEmpty else {
            try? modelContext.save()
            return
        }

        // Deduplicate: group transactions by normalized pattern to avoid sending
        // the same merchant to the LLM multiple times in one batch
        var uniqueDescriptions: [String: String] = [:] // pattern -> rawDescription
        var patternToTransactions: [String: [Transaction]] = [:]
        for txn in toClassify {
            let pattern = Self.normalizePattern(txn.rawDescription)
            if uniqueDescriptions[pattern] == nil {
                uniqueDescriptions[pattern] = txn.rawDescription
            }
            patternToTransactions[pattern, default: []].append(txn)
        }

        let dedupedDescriptions = Array(uniqueDescriptions.values)

        // Batch classify via LLM
        let batchSize = 50
        for batchStart in stride(from: 0, to: dedupedDescriptions.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, dedupedDescriptions.count)
            let batch = Array(dedupedDescriptions[batchStart..<batchEnd])

            if let results = await classifyWithLLM(batch, service: openAIService) {
                for (index, result) in results.enumerated() where index < batch.count {
                    let rawDesc = batch[index]
                    let pattern = Self.normalizePattern(rawDesc)

                    // Apply to all transactions sharing this pattern
                    for txn in patternToTransactions[pattern] ?? [] {
                        txn.cleanDescription = result.name
                        assignCategory(result.category, to: txn)
                    }

                    cacheClassification(
                        rawDescription: rawDesc,
                        cleanName: result.name,
                        category: result.category
                    )
                }
            }
        }

        purgeCacheIfNeeded()
        try? modelContext.save()
    }

    /// Classify all uncategorized transactions
    func classifyAllUncategorized() async {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.category == nil && !$0.categoryOverridden }
        )
        guard let transactions = try? modelContext.fetch(descriptor) else { return }
        await classifyTransactions(transactions)
    }

    /// Manual category override — propagates to all transactions with the same normalized pattern
    func overrideCategory(for transaction: Transaction, to category: SpendingCategory) {
        let pattern = Self.normalizePattern(transaction.rawDescription)

        // Update all matching transactions
        let descriptor = FetchDescriptor<Transaction>()
        let allTransactions = (try? modelContext.fetch(descriptor)) ?? []
        for txn in allTransactions where Self.normalizePattern(txn.rawDescription) == pattern {
            txn.category = category
            txn.categoryOverridden = true
        }

        // Update cache
        cacheClassification(
            rawDescription: transaction.rawDescription,
            cleanName: transaction.cleanDescription,
            category: category.name
        )
        try? modelContext.save()
    }

    /// Manual description override — propagates to all transactions with the same normalized pattern
    func overrideDescription(for transaction: Transaction, to newDescription: String) {
        let pattern = Self.normalizePattern(transaction.rawDescription)

        // Update all matching transactions
        let descriptor = FetchDescriptor<Transaction>()
        let allTransactions = (try? modelContext.fetch(descriptor)) ?? []
        for txn in allTransactions where Self.normalizePattern(txn.rawDescription) == pattern {
            txn.cleanDescription = newDescription
        }

        // Update cache
        cacheClassification(
            rawDescription: transaction.rawDescription,
            cleanName: newDescription,
            category: transaction.category?.name ?? "Uncategorized"
        )
        try? modelContext.save()
    }

    // MARK: - Pattern Normalization

    /// Normalize a raw transaction description into a stable cache key.
    /// Strips reference numbers, common prefixes, city/state suffixes, and normalizes whitespace.
    static func normalizePattern(_ raw: String) -> String {
        var s = raw.lowercased()

        // Remove common merchant prefixes: TST*, SQ *, PP*, SP *, GOOGLE *, etc.
        let prefixes = [
            "tst\\*\\s*", "sq \\*\\s*", "sq\\*\\s*",
            "pp\\*\\s*", "sp \\*\\s*", "sp\\*\\s*",
            "cko\\*\\s*", "fs\\*\\s*",
        ]
        for prefix in prefixes {
            if let range = s.range(of: "^" + prefix, options: .regularExpression) {
                s.removeSubrange(range)
            }
        }

        // Remove reference/transaction IDs after * (e.g. "AMAZON.COM*2K7HJ1LA0" → "AMAZON.COM")
        // Pattern: asterisk followed by alphanumeric sequence (at least 4 chars)
        if let range = s.range(of: "\\*[a-z0-9]{4,}", options: .regularExpression) {
            s.removeSubrange(range)
        }

        // Remove trailing location patterns: city, state abbreviation, zip
        // e.g. "SAN FRANCISCO CA 94105" or "NEW YORK NY"
        let locationPatterns = [
            "\\s+[a-z]{2}\\s+\\d{5}(-\\d{4})?$",  // " CA 94105" or " CA 94105-1234"
            "\\s+[a-z ]+,?\\s+[a-z]{2}\\s*$",       // " SAN FRANCISCO CA" or " SAN FRANCISCO, CA"
            "\\s+\\d{5}(-\\d{4})?$",                  // trailing zip code
        ]
        for pattern in locationPatterns {
            if let range = s.range(of: pattern, options: .regularExpression) {
                s.removeSubrange(range)
            }
        }

        // Remove trailing "#1234" store numbers
        if let range = s.range(of: "\\s*#\\d+$", options: .regularExpression) {
            s.removeSubrange(range)
        }

        // Remove "amzn.com/bill" style suffixes (URLs after the merchant name)
        if let range = s.range(of: "\\s+\\S+\\.com/\\S*$", options: .regularExpression) {
            s.removeSubrange(range)
        }

        // Normalize whitespace and trim
        s = s.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))

        return s
    }

    // MARK: - Private

    private func classifyWithLLM(_ descriptions: [String], service: OpenAIService) async -> [ClassificationResult]? {
        let categories = SpendingCategory.defaults.map(\.name).joined(separator: ", ")

        let prompt = """
        For each credit card transaction below, provide:
        1. A standardized merchant name (e.g. "AMAZON.COM*2K7HJ1LA0" → "Amazon", "TST* CHIPOTLE ONLINE" → "Chipotle", "UBER   *EATS" → "Uber Eats", "SQ *BLUE BOTTLE COFFEE" → "Blue Bottle Coffee", "GOOGLE *YouTube Premium" → "YouTube Premium")
        2. A spending category from EXACTLY this list: \(categories)

        Rules for merchant names:
        - Remove transaction IDs, reference numbers, asterisks, prefixes like "TST*", "SQ *", "PP*", "SP *"
        - Remove city/state/zip suffixes
        - Use the commonly known brand name in proper title case
        - For the same merchant with slight variations, always use the same standardized name

        Category guidelines:
        - Sit-down restaurants → "Dining Out"
        - Food delivery apps (Uber Eats, DoorDash, HungryPanda, Fantuan) → "Food Delivery"
        - Coffee shops, tea shops, bakeries → "Coffee & Tea"
        - Fast casual chains (Sweetgreen, Chopt, Chipotle) → "Fast Casual"
        - Uber/Lyft rides → "Rideshare", subway/bus/ferry → "Public Transit"
        - Airlines, in-flight purchases → "Flights", hotels → "Hotels"
        - Amazon, Alibaba, online stores → "Online Shopping"
        - Physical retail stores → "In Store Shopping"
        - Luxury brands (LV, Dior, Saks) → "Luxury"
        - B&H Photo, electronics stores → "Electronics"
        - Cursor, OpenAI, GoDaddy, AWS → "Software"
        - YouTube Premium, streaming services → "Streaming"
        - Apple.com/Bill, Microsoft 365 → "App Subscriptions"
        - Wine, liquor, beer → "Alcohol"
        - Salon, spa, haircut → "Salon & Spa"
        - Skincare, cosmetics → "Beauty & Skincare"
        - Car wash, auto service, DMV → "Car Maintenance"
        - Parking lots/garages → "Parking"
        - Rent, mortgage → "Rent"
        - Vending machines → "Vending Machines"

        Transactions:
        \(descriptions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        Respond with a JSON array of objects. Example:
        [{"name": "Amazon", "category": "Online Shopping"}, {"name": "Chipotle", "category": "Fast Casual"}]

        Only respond with the JSON array, nothing else.
        """

        do {
            let response = try await service.chat(
                systemPrompt: "You are a financial transaction classifier. For each transaction, provide a clean merchant name and spending category. Respond only with a JSON array.",
                userMessage: prompt
            )

            let cleaned = response
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let data = cleaned.data(using: .utf8),
               let results = try? JSONDecoder().decode([ClassificationResult].self, from: data) {
                return results
            }
        } catch {
            print("LLM classification error: \(error)")
        }

        return nil
    }

    /// Load all cache entries into memory for O(1) lookups during classification
    private func loadCacheIntoMemory() {
        let descriptor = FetchDescriptor<ClassificationCache>()
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        cacheByPattern = [:]
        cacheByCleanName = [:]
        for entry in entries {
            cacheByPattern[entry.merchantPattern] = entry
            let cleanKey = entry.cleanName.lowercased()
            // Keep the most recently used entry per clean name
            if let existing = cacheByCleanName[cleanKey] {
                if entry.lastUsed > existing.lastUsed {
                    cacheByCleanName[cleanKey] = entry
                }
            } else {
                cacheByCleanName[cleanKey] = entry
            }
        }
    }

    /// Fast in-memory lookup: try normalized pattern first, then clean name as fallback
    private func lookupCacheInMemory(for rawDescription: String) -> ClassificationCache? {
        let normalized = Self.normalizePattern(rawDescription)

        // Primary: exact pattern match
        if let found = cacheByPattern[normalized] {
            found.lastUsed = Date()
            return found
        }

        // Secondary: try the raw description lowercased as a clean name lookup
        // (handles cases where the same merchant has different raw patterns)
        let simplifiedName = rawDescription
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()

        for (cleanName, entry) in cacheByCleanName {
            if simplifiedName.contains(cleanName) || cleanName.contains(simplifiedName) {
                // Only use if the match is reasonably specific (> 4 chars)
                if cleanName.count > 4 {
                    entry.lastUsed = Date()
                    return entry
                }
            }
        }

        return nil
    }

    /// Pre-warm cache from already-classified transactions in the DB.
    /// This fills cache gaps from transactions classified in previous sessions.
    private func warmCacheFromExistingTransactions() {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.categoryOverridden }
        )
        guard let classified = try? modelContext.fetch(descriptor) else { return }

        for txn in classified {
            guard let catName = txn.category?.name, catName != "Uncategorized" else { continue }
            let pattern = Self.normalizePattern(txn.rawDescription)

            // Only add if not already cached
            let cacheDescriptor = FetchDescriptor<ClassificationCache>(
                predicate: #Predicate<ClassificationCache> { $0.merchantPattern == pattern }
            )
            if (try? modelContext.fetchCount(cacheDescriptor)) == 0 {
                let cache = ClassificationCache(
                    merchantPattern: pattern,
                    cleanName: txn.cleanDescription,
                    categoryName: catName
                )
                modelContext.insert(cache)
            }
        }
        try? modelContext.save()
    }

    private func cacheClassification(rawDescription: String, cleanName: String, category: String) {
        let normalized = Self.normalizePattern(rawDescription)
        let descriptor = FetchDescriptor<ClassificationCache>(
            predicate: #Predicate<ClassificationCache> { $0.merchantPattern == normalized }
        )

        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.cleanName = cleanName
            existing.categoryName = category
            existing.lastUsed = Date()
        } else {
            let cache = ClassificationCache(
                merchantPattern: normalized,
                cleanName: cleanName,
                categoryName: category
            )
            modelContext.insert(cache)
        }
    }

    /// Keep cache at max 200 entries, purging least recently used
    private func purgeCacheIfNeeded() {
        let countDescriptor = FetchDescriptor<ClassificationCache>()
        let total = (try? modelContext.fetchCount(countDescriptor)) ?? 0
        guard total > Self.maxCacheSize else { return }

        // Fetch all sorted by lastUsed ascending (oldest first)
        var descriptor = FetchDescriptor<ClassificationCache>(
            sortBy: [SortDescriptor(\.lastUsed, order: .forward)]
        )
        descriptor.fetchLimit = total - Self.maxCacheSize

        if let toDelete = try? modelContext.fetch(descriptor) {
            for entry in toDelete {
                modelContext.delete(entry)
            }
        }
    }

    /// Ensure default spending categories exist in the current model context.
    /// This guards against the race condition where classification runs before category seeding.
    /// Also adds any new categories from updated defaults.
    private func ensureCategoriesExist() {
        let descriptor = FetchDescriptor<SpendingCategory>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingNames = Set(existing.map(\.name))

        var inserted = false
        for (index, cat) in SpendingCategory.defaults.enumerated() {
            if !existingNames.contains(cat.name) {
                let category = SpendingCategory(
                    name: cat.name,
                    iconName: cat.icon,
                    colorHex: cat.color,
                    sortOrder: index
                )
                modelContext.insert(category)
                inserted = true
            }
        }
        if inserted {
            try? modelContext.save()
        }
    }

    /// Remove cache entries that were saved as "Uncategorized" — these are stale failures
    /// that should be re-classified by the LLM on next import.
    private func purgeUncategorizedCache() {
        let uncategorized = "Uncategorized"
        let descriptor = FetchDescriptor<ClassificationCache>(
            predicate: #Predicate<ClassificationCache> { $0.categoryName == uncategorized }
        )
        if let stale = try? modelContext.fetch(descriptor) {
            for entry in stale {
                modelContext.delete(entry)
            }
        }
    }

    /// Map LLM category names that don't match defaults to the closest valid category.
    /// Also maps old category names from previous versions for backward compatibility.
    private static let categoryAliases: [String: String] = [
        // Old category names → new names
        "Dining": "Dining Out",
        "Transportation": "Rideshare",
        "Travel": "Flights",
        "Shopping": "Online Shopping",
        "Subscriptions": "App Subscriptions",
        "Personal Care": "Salon & Spa",
        "Home": "Home & Household",
        "Income/Credits": "Income & Credits",
        // Common LLM outputs that need mapping
        "Restaurant": "Dining Out",
        "Restaurants": "Dining Out",
        "Taxi": "Rideshare",
        "Ride Share": "Rideshare",
        "Transit": "Public Transit",
        "Airline": "Flights",
        "Hotel": "Hotels",
        "Clothing": "In Store Shopping",
        "Subscription": "App Subscriptions",
        "Spa": "Salon & Spa",
        "Beauty": "Beauty & Skincare",
        "Health": "Healthcare",
        "Rent/Housing": "Rent",
        "Wine": "Alcohol",
        "Liquor": "Alcohol",
    ]

    private func assignCategory(_ categoryName: String, to transaction: Transaction) {
        let resolvedName = Self.categoryAliases[categoryName] ?? categoryName

        let descriptor = FetchDescriptor<SpendingCategory>(
            predicate: #Predicate<SpendingCategory> { $0.name == resolvedName }
        )

        if let category = (try? modelContext.fetch(descriptor))?.first {
            transaction.category = category
        } else {
            // Case-insensitive fallback: fetch all and match manually
            let allDescriptor = FetchDescriptor<SpendingCategory>()
            let allCategories = (try? modelContext.fetch(allDescriptor)) ?? []
            let lowered = resolvedName.lowercased()
            if let match = allCategories.first(where: { $0.name.lowercased() == lowered }) {
                transaction.category = match
            } else {
                // Fall back to Uncategorized
                transaction.category = allCategories.first(where: { $0.name == "Uncategorized" })
            }
        }
    }
}
