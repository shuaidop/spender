import Foundation
import SwiftData

@Model
final class Card: Hashable {
    static func == (lhs: Card, rhs: Card) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var id: UUID
    var bankName: String
    var cardName: String
    var lastFourDigits: String
    var cardType: String
    var colorHex: String

    @Relationship(deleteRule: .nullify, inverse: \Transaction.card)
    var transactions: [Transaction]

    init(
        bankName: String,
        cardName: String,
        lastFourDigits: String,
        cardType: String = "credit",
        colorHex: String = "#007AFF"
    ) {
        self.id = UUID()
        self.bankName = bankName
        self.cardName = cardName
        self.lastFourDigits = lastFourDigits
        self.cardType = cardType
        self.colorHex = colorHex
        self.transactions = []
    }

    var displayName: String {
        "\(bankName) \(cardName) (\(lastFourDigits))"
    }
}
