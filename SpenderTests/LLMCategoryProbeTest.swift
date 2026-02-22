import XCTest
@testable import Spender

/// Integration test: parse real PDFs, call the LLM with the same prompt, print returned categories.
/// Run only this test to see what category names the LLM actually returns.
@MainActor
final class LLMCategoryProbeTest: XCTestCase {

    private let outputPath = "/tmp/llm_category_probe_output.txt"
    private var lines: [String] = []

    private func log(_ s: String) {
        print(s)
        lines.append(s)
    }

    private func flush() {
        try? lines.joined(separator: "\n").write(toFile: outputPath, atomically: true, encoding: .utf8)
    }

    func testProbeRealLLMCategories() async throws {
        let projectRoot = "/Users/johnnypan/Desktop/Other/spender"

        // All Amex PDFs
        let amexPDFs = [
            "\(projectRoot)/amex_pdf/2025-08-29.pdf",
            "\(projectRoot)/amex_pdf/2025-09-28.pdf",
            "\(projectRoot)/amex_pdf/2025-10-29.pdf",
            "\(projectRoot)/amex_pdf/2025-11-28.pdf",
            "\(projectRoot)/amex_pdf/2025-12-29.pdf",
            "\(projectRoot)/amex_pdf/2026-01-29 (1).pdf",
            "\(projectRoot)/fils/2026-01-29.pdf",
        ]

        // All Chase PDFs
        let chasePDFs = [
            "\(projectRoot)/fils/20250819-statements-0727-.pdf",
            "\(projectRoot)/fils/20250919-statements-0727-.pdf",
            "\(projectRoot)/fils/20251019-statements-0727-.pdf",
            "\(projectRoot)/fils/20251119-statements-0727-.pdf",
            "\(projectRoot)/fils/20251219-statements-0727-.pdf",
            "\(projectRoot)/fils/20260119-statements-0727-.pdf",
            "\(projectRoot)/fils/20260204-statements-2415-.pdf",
        ]

        var allDescriptions: [String] = []

        // Parse Amex PDFs
        let amexParser = AmexPDFStatementParser()
        for path in amexPDFs {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                log("WARNING: File not found: \(path)")
                continue
            }
            do {
                let statement = try amexParser.parse(fileURL: url)
                let descs = statement.transactions.map(\.rawDescription)
                log("--- Amex PDF: \(url.lastPathComponent) -> \(descs.count) transactions ---")
                allDescriptions.append(contentsOf: descs)
            } catch {
                log("WARNING: Amex parse error for \(url.lastPathComponent): \(error)")
            }
        }

        // Parse Chase PDFs
        let chaseParser = ChaseStatementParser()
        for path in chasePDFs {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                log("WARNING: File not found: \(path)")
                continue
            }
            do {
                let statement = try chaseParser.parse(fileURL: url)
                let descs = statement.transactions.map(\.rawDescription)
                log("--- Chase PDF: \(url.lastPathComponent) -> \(descs.count) transactions ---")
                allDescriptions.append(contentsOf: descs)
            } catch {
                log("WARNING: Chase parse error for \(url.lastPathComponent): \(error)")
            }
        }

        guard !allDescriptions.isEmpty else {
            XCTFail("No transactions parsed from any file")
            return
        }

        // Deduplicate descriptions for the LLM call (to save tokens)
        let unique = Array(Set(allDescriptions)).sorted()
        log("\n=== \(unique.count) unique descriptions out of \(allDescriptions.count) total ===\n")

        // Call LLM with the same prompt as ClassificationEngine
        let service = OpenAIService()
        guard service.isConfigured else {
            log("WARNING: OpenAI API key not configured - skipping LLM probe.")
            flush()
            return
        }

        let categoryList = SpendingCategory.defaults.map(\.name).joined(separator: ", ")

        // Batch in groups of 50 (same as ClassificationEngine)
        let batchSize = 50
        var allResults: [(description: String, name: String, category: String)] = []

        for batchStart in stride(from: 0, to: unique.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, unique.count)
            let batch = Array(unique[batchStart..<batchEnd])

            let prompt = """
            For each credit card transaction below, provide:
            1. A standardized merchant name (e.g. "AMAZON.COM*2K7HJ1LA0" -> "Amazon", "TST* CHIPOTLE ONLINE" -> "Chipotle", "UBER   *EATS" -> "Uber Eats", "SQ *BLUE BOTTLE COFFEE" -> "Blue Bottle Coffee", "GOOGLE *YouTube Premium" -> "YouTube Premium")
            2. A spending category from this list: \(categoryList)

            Rules for merchant names:
            - Remove transaction IDs, reference numbers, asterisks, prefixes like "TST*", "SQ *", "PP*", "SP *"
            - Remove city/state/zip suffixes
            - Use the commonly known brand name in proper title case
            - For the same merchant with slight variations, always use the same standardized name

            Transactions:
            \(batch.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

            Respond with a JSON array of objects. Example:
            [{"name": "Amazon", "category": "Shopping"}, {"name": "Chipotle", "category": "Dining"}]

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
                    for (i, result) in results.enumerated() where i < batch.count {
                        allResults.append((description: batch[i], name: result.name, category: result.category))
                    }
                    log("Batch \(batchStart/batchSize + 1): parsed \(results.count) results")
                } else {
                    log("WARNING: Failed to parse LLM JSON response:\n\(cleaned.prefix(500))")
                }
            } catch {
                log("WARNING: LLM call error: \(error)")
            }
        }

        // Print all results
        log("\n========================================")
        log("  LLM CLASSIFICATION RESULTS")
        log("========================================")

        let validCategories = Set(SpendingCategory.defaults.map(\.name))
        var unmatchedCategories: [String: Int] = [:]
        var matchedCategories: [String: Int] = [:]

        for r in allResults {
            let matchSymbol = validCategories.contains(r.category) ? "OK" : "MISS"
            log("[\(matchSymbol)] \(r.description)")
            log("   -> name: \"\(r.name)\"  category: \"\(r.category)\"")

            if validCategories.contains(r.category) {
                matchedCategories[r.category, default: 0] += 1
            } else {
                unmatchedCategories[r.category, default: 0] += 1
            }
        }

        log("\n========================================")
        log("  SUMMARY")
        log("========================================")
        let matched = allResults.filter { validCategories.contains($0.category) }.count
        log("Total classified: \(allResults.count)")
        log("Matched valid category: \(matched)")
        log("Unmatched: \(allResults.count - matched)")

        if !matchedCategories.isEmpty {
            log("\nMATCHED CATEGORIES:")
            for (cat, count) in matchedCategories.sorted(by: { $0.value > $1.value }) {
                log("   \"\(cat)\" x \(count)")
            }
        }

        if !unmatchedCategories.isEmpty {
            log("\nUNMATCHED CATEGORIES (LLM returned these, but they don't match defaults):")
            for (cat, count) in unmatchedCategories.sorted(by: { $0.value > $1.value }) {
                log("   \"\(cat)\" x \(count)")
            }
        }

        log("\nValid categories: \(validCategories.sorted().joined(separator: ", "))")

        flush()
        log("Output written to: \(outputPath)")
    }
}
