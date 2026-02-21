import Foundation
import SwiftData

@MainActor
final class DataCleanupService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Delete transactions older than the retention period
    func cleanupOldData() throws {
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        guard let settings = try modelContext.fetch(settingsDescriptor).first else { return }

        let retentionMonths = settings.dataRetentionMonths
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .month, value: -retentionMonths, to: Date()) else { return }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date < cutoffDate }
        )
        let oldTransactions = try modelContext.fetch(descriptor)

        for txn in oldTransactions {
            modelContext.delete(txn)
        }

        // Clean up old summaries too
        let summaryDescriptor = FetchDescriptor<SpendingSummary>(
            predicate: #Predicate<SpendingSummary> { $0.periodEnd < cutoffDate }
        )
        let oldSummaries = try modelContext.fetch(summaryDescriptor)
        for summary in oldSummaries {
            modelContext.delete(summary)
        }

        settings.lastCleanupDate = Date()
        try modelContext.save()
    }

    /// Clear all user data (transactions, accounts, summaries, cursors)
    func clearAllData() throws {
        try modelContext.delete(model: Transaction.self)
        try modelContext.delete(model: Account.self)
        try modelContext.delete(model: SpendingSummary.self)
        try modelContext.delete(model: SyncCursor.self)
        try modelContext.save()
    }
}
