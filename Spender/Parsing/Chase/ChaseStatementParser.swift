import Foundation

final class ChaseStatementParser: StatementParser {
    static let parserID = "chase_credit"
    static let displayName = "Chase Credit Card"
    static let bankName = "Chase"

    static let supportedFileTypes: [StatementFileType] = [.pdf]

    // Chase statements are PDFs containing these markers
    static func canParse(fileURL: URL) -> Bool {
        guard StatementFileType(url: fileURL) == .pdf else { return false }
        guard let text = try? PDFTextExtractor.extractText(from: fileURL) else { return false }
        let indicators = ["CARDMEMBER", "ACCOUNT ACTIVITY", "chase.com"]
        let matchCount = indicators.filter { text.localizedCaseInsensitiveContains($0) }.count
        return matchCount >= 2
    }

    required init() {}

    func parse(fileURL: URL) throws -> ParsedStatement {
        let pdfText = try PDFTextExtractor.extractText(from: fileURL)
        return try parseText(pdfText)
    }

    func parseText(_ pdfText: String) throws -> ParsedStatement {
        let lines = pdfText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let statementPeriod = extractStatementPeriod(from: lines)
        let accountLastFour = extractAccountLastFour(from: lines)
        let cardProduct = extractCardProduct(from: lines)
        var transactions: [ParsedTransaction] = []
        var warnings: [String] = []

        // Parse the ACCOUNT ACTIVITY section
        // Chase format observed from actual PDF:
        //
        //   ACCOUNT ACTIVITY
        //   ...
        //   PAYMENTS AND OTHER CREDITS
        //   02/01 AUTOMATIC PAYMENT - THANK YOU -563.34
        //   PURCHASE
        //   01/27 Microsoft*Microsoft 365 P 425-6816830 WA 10.65
        //   01/30 DNH*GODADDY#4006277866 480-5058855 AZ 44.59
        //   02/01 Amazon web services aws.amazon.co WA .52
        //
        // Transaction line pattern: MM/DD  description  [-]amount
        // - Amount has no $ sign
        // - Negative amounts have a leading minus (credits/payments)
        // - Amounts can omit leading zero: .52 instead of 0.52

        var inActivitySection = false
        var currentSection = ""

        for line in lines {
            // Detect start of ACCOUNT ACTIVITY
            if line == "ACCOUNT ACTIVITY" {
                inActivitySection = true
                continue
            }

            // Detect end of ACCOUNT ACTIVITY (INTEREST CHARGES section follows)
            if inActivitySection && (line.hasPrefix("INTEREST CHARGE") || line.hasPrefix("2026 Totals") || line.hasPrefix("20") && line.contains("Totals Year-to-Date")) {
                // Check for year totals pattern like "2026 Totals Year-to-Date"
                if line.contains("Totals Year-to-Date") || line.hasPrefix("INTEREST CHARGE") {
                    break
                }
            }

            guard inActivitySection else { continue }

            // Track section headers
            let sectionHeaders = [
                "PAYMENTS AND OTHER CREDITS",
                "PURCHASE",
                "CASH ADVANCES",
                "BALANCE TRANSFERS",
                "FEES CHARGED",
            ]
            if sectionHeaders.contains(where: { line.hasPrefix($0) }) {
                currentSection = line
                continue
            }

            // Skip non-transaction lines (headers, subtotals, etc.)
            guard line.first?.isNumber == true else { continue }

            // Try to parse as transaction
            if let parsed = parseTransactionLine(line, statementPeriod: statementPeriod, section: currentSection) {
                transactions.append(parsed)
            } else {
                // Only warn if it starts with a date pattern (MM/DD)
                if line.range(of: #"^\d{2}/\d{2}\s"#, options: .regularExpression) != nil {
                    warnings.append("Could not parse: \(String(line.prefix(80)))")
                }
            }
        }

        guard !transactions.isEmpty else {
            throw ParserError.noTransactionsFound
        }

        let statementMonth = statementPeriod?.closingMonthKey ?? "unknown"

        return ParsedStatement(
            transactions: transactions,
            statementMonth: statementMonth,
            accountLastFour: accountLastFour,
            cardProductName: cardProduct,
            openingBalance: nil,
            closingBalance: nil,
            warnings: warnings
        )
    }

    // MARK: - Transaction Line Parsing

    private func parseTransactionLine(_ line: String, statementPeriod: StatementPeriod?, section: String) -> ParsedTransaction? {
        // Pattern: MM/DD  description  [-]amount
        // Amount patterns: 563.34, -563.34, .52, 10.65, 1,234.56
        // The amount is always at the end of the line
        let pattern = #"^(\d{2}/\d{2})\s+(.+?)\s+(-?[\d,]*\.?\d{2})$"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let dateRange = Range(match.range(at: 1), in: line),
              let descRange = Range(match.range(at: 2), in: line),
              let amountRange = Range(match.range(at: 3), in: line) else {
            return nil
        }

        let dateStr = String(line[dateRange])
        let description = String(line[descRange]).trimmingCharacters(in: .whitespaces)
        let amountStr = String(line[amountRange]).replacingOccurrences(of: ",", with: "")

        guard let amount = Decimal(string: amountStr) else { return nil }

        // Resolve the year from the statement period
        guard let date = resolveDate(dateStr, statementPeriod: statementPeriod) else { return nil }

        // Determine if credit: negative amount OR in payments section
        let isCredit = amount < 0 || section.contains("PAYMENTS") || section.contains("CREDITS")
        let absAmount = abs(amount)

        return ParsedTransaction(
            date: date,
            postDate: nil,
            rawDescription: description,
            amount: isCredit ? -absAmount : absAmount,
            isCredit: isCredit
        )
    }

    // MARK: - Date Resolution

    /// Resolve MM/DD to a full date using the statement period to determine the year.
    /// Transactions can span a year boundary (e.g., statement 12/05/25 - 01/04/26,
    /// a transaction on 12/15 is in 2025, a transaction on 01/02 is in 2026).
    private func resolveDate(_ mmdd: String, statementPeriod: StatementPeriod?) -> Date? {
        let parts = mmdd.split(separator: "/")
        guard parts.count == 2,
              let txnMonth = Int(parts[0]),
              let txnDay = Int(parts[1]) else { return nil }

        guard let period = statementPeriod else {
            // Fallback: use current year
            let year = Calendar.current.component(.year, from: Date())
            return makeDate(year: year, month: txnMonth, day: txnDay)
        }

        let openMonth = Calendar.current.component(.month, from: period.openDate)
        let openYear = Calendar.current.component(.year, from: period.openDate)
        let closeYear = Calendar.current.component(.year, from: period.closeDate)

        // If the statement spans a year boundary
        if openYear != closeYear {
            // Transaction months >= opening month belong to openYear
            // Transaction months < opening month belong to closeYear
            let year = txnMonth >= openMonth ? openYear : closeYear
            return makeDate(year: year, month: txnMonth, day: txnDay)
        } else {
            return makeDate(year: closeYear, month: txnMonth, day: txnDay)
        }
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date? {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }

    // MARK: - Statement Period Extraction

    struct StatementPeriod {
        let openDate: Date
        let closeDate: Date

        var closingMonthKey: String {
            DateFormatters.monthKey.string(from: closeDate)
        }
    }

    private func extractStatementPeriod(from lines: [String]) -> StatementPeriod? {
        // Pattern: "Opening/Closing Date 01/05/26 - 02/04/26"
        // Also handle: "Opening/Closing Date 01/05/2026 - 02/04/2026"
        for line in lines {
            guard line.localizedCaseInsensitiveContains("Opening/Closing Date") ||
                  line.localizedCaseInsensitiveContains("Opening/ Closing Date") else { continue }

            // Extract the two dates
            let datePattern = #"(\d{2}/\d{2}/\d{2,4})\s*-\s*(\d{2}/\d{2}/\d{2,4})"#
            guard let regex = try? NSRegularExpression(pattern: datePattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let openRange = Range(match.range(at: 1), in: line),
                  let closeRange = Range(match.range(at: 2), in: line) else { continue }

            let openStr = String(line[openRange])
            let closeStr = String(line[closeRange])

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = openStr.count > 8 ? "MM/dd/yyyy" : "MM/dd/yy"

            guard let openDate = formatter.date(from: openStr),
                  let closeDate = formatter.date(from: closeStr) else { continue }

            return StatementPeriod(openDate: openDate, closeDate: closeDate)
        }

        // Fallback: try "Statement Date: MM/DD/YY" pattern
        for line in lines {
            guard line.contains("Statement Date") else { continue }
            let datePattern = #"(\d{2}/\d{2}/\d{2,4})"#
            guard let regex = try? NSRegularExpression(pattern: datePattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let dateRange = Range(match.range(at: 1), in: line) else { continue }

            let dateStr = String(line[dateRange])
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = dateStr.count > 8 ? "MM/dd/yyyy" : "MM/dd/yy"

            guard let closeDate = formatter.date(from: dateStr) else { continue }
            let openDate = Calendar.current.date(byAdding: .month, value: -1, to: closeDate)!
            return StatementPeriod(openDate: openDate, closeDate: closeDate)
        }

        return nil
    }

    // MARK: - Card Product Name

    private func extractCardProduct(from lines: [String]) -> String? {
        // Chase statements typically mention the card product in early lines
        // e.g. "Sapphire Preferred", "Freedom Unlimited", "Amazon Prime"
        let chaseProducts = [
            "Sapphire Reserve", "Sapphire Preferred", "Sapphire",
            "Freedom Unlimited", "Freedom Flex", "Freedom",
            "Amazon Prime", "Amazon",
            "Ink Business Preferred", "Ink Business Unlimited", "Ink Business Cash", "Ink",
            "Slate", "United Explorer", "United", "Southwest", "Marriott",
            "Aeroplan",
        ]

        let searchText = lines.prefix(40).joined(separator: " ")
        for product in chaseProducts {
            if searchText.localizedCaseInsensitiveContains(product) {
                return product
            }
        }
        return nil
    }

    // MARK: - Account Number

    private func extractAccountLastFour(from lines: [String]) -> String? {
        // Pattern: "Account Number: XXXX XXXX XXXX 2415"
        // or: "Account number: XXXX XXXX XXXX 2415"
        for line in lines {
            if line.localizedCaseInsensitiveContains("Account Number") || line.localizedCaseInsensitiveContains("Account number") {
                // Extract last 4 digits
                let digitPattern = #"(\d{4})\s*$"#
                if let regex = try? NSRegularExpression(pattern: digitPattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let range = Range(match.range(at: 1), in: line) {
                    return String(line[range])
                }
            }
        }
        return nil
    }
}
