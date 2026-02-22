import Foundation

enum CurrencyFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    static func format(_ value: Decimal) -> String {
        formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    static func format(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}
