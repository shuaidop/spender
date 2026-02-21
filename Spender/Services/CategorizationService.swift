import Foundation
import SwiftData

@MainActor
final class CategorizationService {
    private let openAIService: OpenAIService
    private let modelContext: ModelContext

    init(openAIService: OpenAIService, modelContext: ModelContext) {
        self.openAIService = openAIService
        self.modelContext = modelContext
    }

    /// Categorize all uncategorized transactions in batches
    func categorizeUncategorized(deviceToken: String) async throws {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.needsCategorization == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let uncategorized = try modelContext.fetch(descriptor)

        guard !uncategorized.isEmpty else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Process in batches
        let batchSize = Constants.categorizationBatchSize
        for batchStart in stride(from: 0, to: uncategorized.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, uncategorized.count)
            let batch = Array(uncategorized[batchStart..<batchEnd])

            let input = batch.map { txn in
                TransactionForCategorization(
                    id: txn.id.uuidString,
                    merchantName: txn.merchantName ?? "",
                    description: txn.originalDescription,
                    amount: NSDecimalNumber(decimal: txn.amount).doubleValue,
                    date: dateFormatter.string(from: txn.date)
                )
            }

            let results = try await openAIService.categorize(
                transactions: input,
                deviceToken: deviceToken
            )

            for result in results {
                if let txn = batch.first(where: { $0.id.uuidString == result.id }) {
                    txn.aiCategory = result.category
                    txn.aiCategoryConfidence = result.confidence
                    txn.needsCategorization = false
                    txn.updatedAt = Date()
                }
            }
        }

        try modelContext.save()
    }
}
