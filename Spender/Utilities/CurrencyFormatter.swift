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

    static func format(_ amount: Decimal, currencyCode: String = "USD") -> String {
        let f = formatter
        f.currencyCode = currencyCode
        return f.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }

    static func formatCompact(_ amount: Decimal) -> String {
        let doubleAmount = NSDecimalNumber(decimal: amount).doubleValue
        if abs(doubleAmount) >= 1000 {
            return String(format: "$%.1fk", doubleAmount / 1000)
        }
        return format(amount)
    }
}
