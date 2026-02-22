import Foundation
import SwiftData

@Model
final class Transaction: Hashable {
    static func == (lhs: Transaction, rhs: Transaction) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var id: UUID
    var date: Date
    var postDate: Date?
    var rawDescription: String
    var cleanDescription: String
    var amount: Decimal
    var isCredit: Bool

    var card: Card?
    var category: SpendingCategory?
    var importSession: ImportSession?

    var categoryOverridden: Bool
    var notes: String?

    var monthKey: String
    var yearKey: String

    init(
        date: Date,
        rawDescription: String,
        cleanDescription: String,
        amount: Decimal,
        isCredit: Bool,
        card: Card? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.rawDescription = rawDescription
        self.cleanDescription = cleanDescription
        self.amount = amount
        self.isCredit = isCredit
        self.card = card
        self.categoryOverridden = false

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.monthKey = formatter.string(from: date)
        formatter.dateFormat = "yyyy"
        self.yearKey = formatter.string(from: date)
    }
}
