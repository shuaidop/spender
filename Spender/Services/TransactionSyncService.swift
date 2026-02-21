import Foundation
import SwiftData

@MainActor
final class TransactionSyncService {
    private let plaidService: PlaidService
    private let modelContext: ModelContext

    init(plaidService: PlaidService, modelContext: ModelContext) {
        self.plaidService = plaidService
        self.modelContext = modelContext
    }

    func syncAllAccounts(deviceToken: String) async throws {
        let accounts = try modelContext.fetch(FetchDescriptor<Account>(
            predicate: #Predicate { $0.isActive }
        ))

        let itemIDs = Set(accounts.map(\.plaidItemID))
        for itemID in itemIDs {
            try await syncItem(deviceToken: deviceToken, itemID: itemID)
        }
    }

    private func syncItem(deviceToken: String, itemID: String) async throws {
        // Get existing cursor
        let cursorDescriptor = FetchDescriptor<SyncCursor>(
            predicate: #Predicate<SyncCursor> { $0.plaidItemID == itemID }
        )
        let existingCursor = try modelContext.fetch(cursorDescriptor).first

        let response = try await plaidService.syncTransactions(
            deviceToken: deviceToken,
            itemId: itemID,
            cursor: existingCursor?.cursor
        )

        // Process added
        for dto in response.added {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            let txn = Transaction(
                plaidTransactionID: dto.transactionId,
                amount: Decimal(dto.amount),
                merchantName: dto.merchantName,
                originalDescription: dto.name,
                date: dateFormatter.date(from: dto.date) ?? Date(),
                isPending: dto.pending,
                isoCurrencyCode: dto.isoCurrencyCode ?? "USD"
            )

            if let authorizedDateStr = dto.authorizedDate {
                txn.authorizedDate = dateFormatter.date(from: authorizedDateStr)
            }

            // Link to account
            let accountDescriptor = FetchDescriptor<Account>(
                predicate: #Predicate<Account> { $0.plaidAccountID == dto.accountId }
            )
            txn.account = try modelContext.fetch(accountDescriptor).first

            txn.plaidCategoryPrimary = dto.personalFinanceCategory?.primary
            txn.plaidCategoryDetailed = dto.personalFinanceCategory?.detailed

            modelContext.insert(txn)
        }

        // Process modified
        for dto in response.modified {
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { $0.plaidTransactionID == dto.transactionId }
            )
            if let existing = try modelContext.fetch(descriptor).first {
                existing.amount = Decimal(dto.amount)
                existing.merchantName = dto.merchantName
                existing.isPending = dto.pending
                existing.updatedAt = Date()
            }
        }

        // Process removed
        for removed in response.removed {
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { $0.plaidTransactionID == removed.transactionId }
            )
            if let existing = try modelContext.fetch(descriptor).first {
                modelContext.delete(existing)
            }
        }

        // Update cursor
        if let syncCursor = existingCursor {
            syncCursor.cursor = response.nextCursor
            syncCursor.lastSyncedAt = Date()
        } else {
            let newCursor = SyncCursor(plaidItemID: itemID)
            newCursor.cursor = response.nextCursor
            modelContext.insert(newCursor)
        }

        try modelContext.save()
    }
}
