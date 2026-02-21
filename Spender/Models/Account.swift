import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var plaidItemID: String
    var plaidAccountID: String
    var institutionName: String
    var accountName: String
    var accountType: String
    var accountSubtype: String
    var mask: String
    var currentBalance: Decimal?
    var availableBalance: Decimal?
    var isoCurrencyCode: String
    var isActive: Bool
    var connectedAt: Date
    var lastSyncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction] = []

    init(
        plaidItemID: String,
        plaidAccountID: String,
        institutionName: String,
        accountName: String,
        accountType: String,
        accountSubtype: String,
        mask: String,
        isoCurrencyCode: String = "USD"
    ) {
        self.id = UUID()
        self.plaidItemID = plaidItemID
        self.plaidAccountID = plaidAccountID
        self.institutionName = institutionName
        self.accountName = accountName
        self.accountType = accountType
        self.accountSubtype = accountSubtype
        self.mask = mask
        self.isoCurrencyCode = isoCurrencyCode
        self.isActive = true
        self.connectedAt = Date()
    }
}
