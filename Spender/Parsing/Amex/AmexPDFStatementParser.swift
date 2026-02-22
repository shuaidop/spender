import Foundation

final class AmexPDFStatementParser: StatementParser {
    static let parserID = "amex_pdf"
    static let displayName = "American Express (PDF)"
    static let bankName = "Amex"
    static let supportedFileTypes: [StatementFileType] = [.pdf]

    static func canParse(fileURL: URL) -> Bool {
        guard StatementFileType(url: fileURL) == .pdf else { return false }
        guard let text = try? PDFTextExtractor.extractText(from: fileURL) else { return false }
        let indicators = ["Platinum Card", "American Express", "Account Ending", "Closing Date"]
        let matchCount = indicators.filter { text.localizedCaseInsensitiveContains($0) }.count
        return matchCount >= 3
    }

    required init() {}

    func parse(fileURL: URL) throws -> ParsedStatement {
        let pdfText = try PDFTextExtractor.extractText(from: fileURL)
        return try parseText(pdfText)
    }

    func parseText(_ pdfText: String) throws -> ParsedStatement {
        let lines = pdfText.components(separatedBy: .newlines)

        let closingDate = extractClosingDate(from: lines)
        let accountLastDigits = extractAccountLastDigits(from: lines)
        let cardProduct = extractCardProduct(from: lines)
        let statementMonth = closingDate.map { DateFormatters.monthKey.string(from: $0) } ?? "unknown"

        var transactions: [ParsedTransaction] = []
        var warnings: [String] = []

        // Parse each transaction section
        let sections = extractTransactionSections(from: lines)

        for section in sections {
            let parsed = parseTransactionSection(section, warnings: &warnings)
            transactions.append(contentsOf: parsed)
        }

        guard !transactions.isEmpty else {
            throw ParserError.noTransactionsFound
        }

        return ParsedStatement(
            transactions: transactions,
            statementMonth: statementMonth,
            accountLastFour: accountLastDigits,
            cardProductName: cardProduct,
            openingBalance: nil,
            closingBalance: nil,
            warnings: warnings
        )
    }

    // MARK: - Section Extraction

    private enum SectionType {
        case payments
        case credits
        case newCharges
    }

    private struct TransactionSection {
        let type: SectionType
        let lines: [String]
    }

    private func extractTransactionSections(from lines: [String]) -> [TransactionSection] {
        var sections: [TransactionSection] = []
        var currentType: SectionType?
        var currentLines: [String] = []
        var inSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect section starts
            if trimmed.hasPrefix("Payments Details") {
                if inSection, let type = currentType {
                    sections.append(TransactionSection(type: type, lines: currentLines))
                }
                currentType = .payments
                currentLines = []
                inSection = true
                continue
            }

            if trimmed.hasPrefix("Credits Details") {
                if inSection, let type = currentType {
                    sections.append(TransactionSection(type: type, lines: currentLines))
                }
                currentType = .credits
                currentLines = []
                inSection = true
                continue
            }

            if trimmed.hasPrefix("New Charges Details") {
                if inSection, let type = currentType {
                    sections.append(TransactionSection(type: type, lines: currentLines))
                }
                currentType = .newCharges
                currentLines = []
                inSection = true
                continue
            }

            // Detect section ends
            if inSection {
                let endMarkers = [
                    "Fees", "Interest Charged", "Total Fees", "Total Interest",
                    "About Trailing Interest", "Interest Charge Calculation",
                    "Information on Pay Over Time", "IMPORTANT NOTICES",
                    "Payments and Credits Summary", "New Charges Summary"
                ]
                if endMarkers.contains(where: { trimmed.hasPrefix($0) }) {
                    if let type = currentType {
                        sections.append(TransactionSection(type: type, lines: currentLines))
                    }
                    currentType = nil
                    currentLines = []
                    inSection = false
                    continue
                }

                // Skip page break markers from PDFTextExtractor
                if trimmed.contains("---PAGE_BREAK---") { continue }
                currentLines.append(trimmed)
            }
        }

        // Flush remaining section
        if inSection, let type = currentType {
            sections.append(TransactionSection(type: type, lines: currentLines))
        }

        return sections
    }

    // MARK: - Transaction Parsing

    /// Parse transactions from a section, handling both interleaved and split-column PDFKit extraction.
    ///
    /// PDFKit sometimes extracts table columns separately on pages with many rows:
    /// - All Date/Description entries first (left column)
    /// - Then "Type Foreign Spend Amount" header
    /// - Then all amount blocks (right column)
    ///
    /// Split-column regions are signaled by a merged header like:
    ///   "Date Description 10/31/25 Alipay China Shanghai"
    /// and end when "Type [Foreign Spend] Amount" appears standalone.
    private func parseTransactionSection(_ section: TransactionSection, warnings: inout [String]) -> [ParsedTransaction] {
        var transactions: [ParsedTransaction] = []
        let lines = section.lines

        // Skip header lines (card member info, column headers)
        var startIndex = 0
        for (i, line) in lines.enumerated() {
            if line.hasPrefix("Date") && line.contains("Amount") {
                startIndex = i + 1
                break
            }
        }

        let datePattern = #"^(\d{2}/\d{2}/\d{2})\*?\s"#
        let dateRegex = try! NSRegularExpression(pattern: datePattern)

        func isDateLine(_ s: String) -> Bool {
            dateRegex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
        }

        var currentBlock: [String] = []
        var pendingDescriptions: [[String]] = []  // description-only blocks awaiting amounts
        var currentAmountBlock: [String] = []
        var inAmountRegion = false

        func flushCurrentBlock() {
            guard !currentBlock.isEmpty else { return }
            let hasDollarAmount = currentBlock.contains { $0.contains("$") }
            if hasDollarAmount {
                // Complete transaction block (interleaved format)
                if let txn = parseTransactionBlock(currentBlock, sectionType: section.type) {
                    transactions.append(txn)
                } else {
                    let desc = currentBlock.first ?? "unknown"
                    warnings.append("Could not parse Amex transaction: \(String(desc.prefix(60)))")
                }
            } else {
                // Description-only block (split-column format) — queue for later matching
                pendingDescriptions.append(currentBlock)
            }
            currentBlock = []
        }

        func matchAmountToPendingDescription() {
            guard !currentAmountBlock.isEmpty, !pendingDescriptions.isEmpty else {
                currentAmountBlock = []
                return
            }
            let desc = pendingDescriptions.removeFirst()
            let combined = desc + currentAmountBlock
            if let txn = parseTransactionBlock(combined, sectionType: section.type) {
                transactions.append(txn)
            } else {
                let d = desc.first ?? "unknown"
                warnings.append("Could not parse Amex transaction: \(String(d.prefix(60)))")
            }
            currentAmountBlock = []
        }

        for i in startIndex..<lines.count {
            let line = lines[i]

            // 1. Merged column header: "Date Description MM/DD/YY ..." (no "Amount")
            //    Signals start of a split-column region — strip prefix and treat as first description
            if line.hasPrefix("Date Description") && !line.contains("Amount") {
                let rest = String(line.dropFirst("Date Description".count)).trimmingCharacters(in: .whitespaces)
                if isDateLine(rest) {
                    if inAmountRegion {
                        matchAmountToPendingDescription()
                        inAmountRegion = false
                    }
                    flushCurrentBlock()
                    currentBlock = [rest]
                    continue
                }
            }

            // 2. Full column header at page break: "Date Description Type [Foreign Spend] Amount"
            //    Just skip it — it's a page-boundary repeat of the header
            if line.hasPrefix("Date") && line.contains("Description") && line.contains("Amount") {
                if inAmountRegion {
                    matchAmountToPendingDescription()
                    inAmountRegion = false
                }
                flushCurrentBlock()
                continue
            }

            // 3. Standalone "Type [Foreign Spend] Amount" — end of description batch, start of amounts
            if line.hasPrefix("Type") && line.contains("Amount") {
                flushCurrentBlock()
                inAmountRegion = true
                continue
            }

            // 4. Amount region: collect amount blocks, each ending with a $-prefixed line
            if inAmountRegion {
                // A date line means we've exited the amount region
                if isDateLine(line) {
                    matchAmountToPendingDescription()
                    inAmountRegion = false
                    // Fall through to normal mode below
                } else {
                    currentAmountBlock.append(line)
                    if line.hasPrefix("$") || line.hasPrefix("-$") {
                        matchAmountToPendingDescription()
                        if pendingDescriptions.isEmpty {
                            inAmountRegion = false
                        }
                    }
                    continue
                }
            }

            // 5. Normal mode: accumulate date-initiated blocks
            if isDateLine(line) {
                flushCurrentBlock()
                currentBlock = [line]
            } else if !currentBlock.isEmpty {
                currentBlock.append(line)
            }
        }

        // Flush remaining
        if inAmountRegion {
            matchAmountToPendingDescription()
        }
        flushCurrentBlock()

        // Warn about any unmatched description blocks
        for desc in pendingDescriptions {
            let d = desc.first ?? "unknown"
            warnings.append("Could not parse Amex transaction (no amount): \(String(d.prefix(60)))")
        }

        return transactions
    }

    private func parseTransactionBlock(_ block: [String], sectionType: SectionType) -> ParsedTransaction? {
        guard let firstLine = block.first else { return nil }

        // Extract date from first line: MM/DD/YY or MM/DD/YY*
        let datePattern = #"^(\d{2}/\d{2}/\d{2})\*?\s+(.*)$"#
        guard let dateRegex = try? NSRegularExpression(pattern: datePattern),
              let dateMatch = dateRegex.firstMatch(in: firstLine, range: NSRange(firstLine.startIndex..., in: firstLine)),
              let dateRange = Range(dateMatch.range(at: 1), in: firstLine),
              let restRange = Range(dateMatch.range(at: 2), in: firstLine) else {
            return nil
        }

        let dateStr = String(firstLine[dateRange])
        var descriptionParts = [String(firstLine[restRange])]

        // Extract amount — find the last $-prefixed number in the block
        // Pattern: -$1,234.56 or $1,234.56 or -$0.52
        let amountPattern = #"(-?\$[\d,]+\.?\d*)"#
        let amountRegex = try? NSRegularExpression(pattern: amountPattern)

        var lastAmount: String?
        var amountLineIndex: Int?

        for (i, line) in block.enumerated() {
            let matches = amountRegex?.matches(in: line, range: NSRange(line.startIndex..., in: line)) ?? []
            if let lastMatch = matches.last, let range = Range(lastMatch.range(at: 1), in: line) {
                lastAmount = String(line[range])
                amountLineIndex = i
            }
        }

        guard let amountStr = lastAmount else { return nil }

        // Build description from lines between date line and amount
        // Skip "Pay Over Time and/or Cash Advance" type annotations and foreign spend info
        let skipPatterns = [
            "Pay Over Time", "and/or Cash", "Advance", "Pay In Full",
            "China Yuan", "Renminb", "Canadian Dollar", "Euro",
            "British Pound", "Japanese Yen", "Australian Dollar",
            "Hong Kong Dollar", "Singapore Dollar", "Korean Won",
        ]

        for i in 1..<block.count {
            let line = block[i]
            // Stop at the amount line content after the amount
            if i == amountLineIndex {
                // Extract description part before the amount on this line
                if let amountRange = line.range(of: amountStr) {
                    let before = String(line[line.startIndex..<amountRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if !before.isEmpty && !skipPatterns.contains(where: { before.hasPrefix($0) }) {
                        descriptionParts.append(before)
                    }
                }
                continue
            }

            // Skip type annotation lines and foreign currency lines
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if skipPatterns.contains(where: { trimmed.hasPrefix($0) }) { continue }

            // Skip lines that are just a foreign amount (e.g., "515.00")
            if trimmed.range(of: #"^\d[\d,]*\.\d{2}$"#, options: .regularExpression) != nil { continue }

            descriptionParts.append(trimmed)
        }

        // Clean up the description
        var description = descriptionParts.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        // Remove trailing location/code patterns that are just noise
        // Clean multiple spaces
        while description.contains("  ") {
            description = description.replacingOccurrences(of: "  ", with: " ")
        }

        guard !description.isEmpty else { return nil }

        // Parse date
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yy"
        guard let date = formatter.date(from: dateStr) else { return nil }

        // Parse amount
        let cleanAmount = amountStr
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard let amount = Decimal(string: cleanAmount) else { return nil }

        // Determine credit: negative amount or in payments/credits section
        let isCredit = amount < 0 || sectionType == .payments || sectionType == .credits
        let absAmount = abs(amount)

        return ParsedTransaction(
            date: date,
            rawDescription: description,
            amount: isCredit ? -absAmount : absAmount,
            isCredit: isCredit
        )
    }

    // MARK: - Metadata Extraction

    private func extractClosingDate(from lines: [String]) -> Date? {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("Closing Date") else { continue }

            let datePattern = #"(\d{2}/\d{2}/\d{2,4})"#
            guard let regex = try? NSRegularExpression(pattern: datePattern),
                  let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                  let range = Range(match.range(at: 1), in: trimmed) else { continue }

            let dateStr = String(trimmed[range])
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = dateStr.count > 8 ? "MM/dd/yyyy" : "MM/dd/yy"
            return formatter.date(from: dateStr)
        }
        return nil
    }

    private func extractCardProduct(from lines: [String]) -> String? {
        let amexProducts = [
            "Platinum Card", "Gold Card", "Green Card", "Blue Cash Preferred",
            "Blue Cash Everyday", "Blue Business Plus", "Blue Business Cash",
            "Business Platinum", "Business Gold", "Business Green",
            "Delta SkyMiles Reserve", "Delta SkyMiles Platinum", "Delta SkyMiles Gold", "Delta SkyMiles Blue",
            "Hilton Honors Aspire", "Hilton Honors Surpass", "Hilton Honors",
            "Marriott Bonvoy Brilliant", "Marriott Bonvoy",
            "EveryDay Preferred", "EveryDay",
        ]

        let searchText = lines.prefix(30).joined(separator: " ")
        for product in amexProducts {
            if searchText.localizedCaseInsensitiveContains(product) {
                // Normalize: remove "Card" suffix for cleaner display
                return product.replacingOccurrences(of: " Card", with: "")
            }
        }
        return nil
    }

    private func extractAccountLastDigits(from lines: [String]) -> String? {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("Account Ending") else { continue }

            // Format: "Account Ending 9-02005"
            let pattern = #"Account Ending\s+(.+)"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                  let range = Range(match.range(at: 1), in: trimmed) else { continue }

            let accountRef = String(trimmed[range]).trimmingCharacters(in: .whitespaces)
            // Extract just the digits
            let digits = accountRef.filter(\.isNumber)
            if digits.count >= 4 {
                return String(digits.suffix(5))
            }
        }
        return nil
    }
}
