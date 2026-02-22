import Foundation

struct ParsedTransaction: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let postDate: Date?
    let rawDescription: String
    let amount: Decimal
    let isCredit: Bool
    /// Category provided by the bank (e.g. Amex provides "Travel-Airline")
    let sourceCategory: String?
    /// Card member name (for multi-member accounts like Amex)
    let cardMember: String?

    init(date: Date, postDate: Date? = nil, rawDescription: String, amount: Decimal,
         isCredit: Bool, sourceCategory: String? = nil, cardMember: String? = nil) {
        self.date = date
        self.postDate = postDate
        self.rawDescription = rawDescription
        self.amount = amount
        self.isCredit = isCredit
        self.sourceCategory = sourceCategory
        self.cardMember = cardMember
    }
}

struct ParsedStatement: Sendable {
    let transactions: [ParsedTransaction]
    let statementMonth: String
    let accountLastFour: String?
    let cardProductName: String?
    let openingBalance: Decimal?
    let closingBalance: Decimal?
    let warnings: [String]
}

enum ParserError: Error, LocalizedError {
    case unsupportedFormat(String)
    case extractionFailed(String)
    case noTransactionsFound
    case dateParsingFailed(String)
    case amountParsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let detail): "Unsupported format: \(detail)"
        case .extractionFailed(let detail): "Extraction failed: \(detail)"
        case .noTransactionsFound: "No transactions found in the statement."
        case .dateParsingFailed(let detail): "Date parsing failed: \(detail)"
        case .amountParsingFailed(let detail): "Amount parsing failed: \(detail)"
        }
    }
}
