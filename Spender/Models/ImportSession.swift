import Foundation
import SwiftData

@Model
final class ImportSession {
    var id: UUID
    var importDate: Date
    var fileName: String
    var bankName: String
    var statementMonth: String
    var transactionCount: Int
    var totalAmount: Decimal

    @Relationship(deleteRule: .cascade, inverse: \Transaction.importSession)
    var transactions: [Transaction]

    init(fileName: String, bankName: String, statementMonth: String) {
        self.id = UUID()
        self.importDate = Date()
        self.fileName = fileName
        self.bankName = bankName
        self.statementMonth = statementMonth
        self.transactionCount = 0
        self.totalAmount = 0
        self.transactions = []
    }
}
