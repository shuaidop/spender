import Foundation
import SwiftData

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var plaidTransactionID: String
    var amount: Decimal
    var merchantName: String?
    var originalDescription: String
    var date: Date
    var authorizedDate: Date?
    var isPending: Bool
    var isoCurrencyCode: String

    // Categorization
    var plaidCategoryPrimary: String?
    var plaidCategoryDetailed: String?
    var aiCategory: String?
    var aiCategoryConfidence: Double?
    var userOverrideCategory: String?
    var needsCategorization: Bool

    var account: Account?

    var createdAt: Date
    var updatedAt: Date

    /// The effective category: user override > AI > Plaid fallback
    var effectiveCategory: String {
        userOverrideCategory ?? aiCategory ?? plaidCategoryPrimary ?? "Uncategorized"
    }

    init(
        plaidTransactionID: String,
        amount: Decimal,
        merchantName: String?,
        originalDescription: String,
        date: Date,
        isPending: Bool,
        isoCurrencyCode: String = "USD"
    ) {
        self.id = UUID()
        self.plaidTransactionID = plaidTransactionID
        self.amount = amount
        self.merchantName = merchantName
        self.originalDescription = originalDescription
        self.date = date
        self.isPending = isPending
        self.isoCurrencyCode = isoCurrencyCode
        self.needsCategorization = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
