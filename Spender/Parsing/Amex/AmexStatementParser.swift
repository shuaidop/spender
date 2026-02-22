import Foundation
import CoreXLSX

final class AmexStatementParser: StatementParser {
    static let parserID = "amex_credit"
    static let displayName = "American Express"
    static let bankName = "Amex"
    static let supportedFileTypes: [StatementFileType] = [.xlsx]

    static func canParse(fileURL: URL) -> Bool {
        guard StatementFileType(url: fileURL) == .xlsx else { return false }
        guard let xlsxFile = XLSXFile(filepath: fileURL.path) else { return false }
        do {
            guard let sharedStrings = try xlsxFile.parseSharedStrings() else { return false }
            let texts = sharedStrings.items.compactMap { $0.text }
            // Amex XLSX exports contain "Transaction Details" and card references
            return texts.contains("Transaction Details")
                || texts.contains(where: { $0.contains("Platinum Card") || $0.contains("Gold Card") || $0.contains("American Express") })
        } catch {
            return false
        }
    }

    required init() {}

    func parse(fileURL: URL) throws -> ParsedStatement {
        guard let xlsxFile = XLSXFile(filepath: fileURL.path) else {
            throw ParserError.extractionFailed("Could not open XLSX file at \(fileURL.path)")
        }

        guard let sharedStrings = try xlsxFile.parseSharedStrings() else {
            throw ParserError.extractionFailed("Could not parse shared strings in XLSX.")
        }

        // Find the "Transaction Details" worksheet
        var transactionWorksheet: Worksheet?
        for wbk in try xlsxFile.parseWorkbooks() {
            for (name, path) in try xlsxFile.parseWorksheetPathsAndNames(workbook: wbk) {
                if name == "Transaction Details" {
                    transactionWorksheet = try xlsxFile.parseWorksheet(at: path)
                    break
                }
            }
        }

        guard let worksheet = transactionWorksheet else {
            throw ParserError.extractionFailed("Could not find 'Transaction Details' sheet in XLSX.")
        }

        guard let rows = worksheet.data?.rows, !rows.isEmpty else {
            throw ParserError.noTransactionsFound
        }

        // Extract metadata from header rows
        let statementMonth = extractStatementMonth(from: rows, sharedStrings: sharedStrings)
        let accountLastFour = extractAccountLastFour(from: rows, sharedStrings: sharedStrings)

        // Find the header row (contains "Date", "Description", "Amount")
        var headerRowIndex: Int?
        var columnMap: [String: Int] = [:]

        for (idx, row) in rows.enumerated() {
            let cellValues = row.cells.map { cellStringValue($0, sharedStrings: sharedStrings) }
            if cellValues.contains("Date") && cellValues.contains("Amount") {
                headerRowIndex = idx
                for (colIdx, value) in cellValues.enumerated() {
                    if !value.isEmpty {
                        columnMap[value] = colIdx
                    }
                }
                break
            }
        }

        guard let headerIdx = headerRowIndex else {
            throw ParserError.extractionFailed("Could not find column headers in XLSX.")
        }

        // Parse data rows
        var transactions: [ParsedTransaction] = []
        var warnings: [String] = []

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "MM/dd/yyyy"

        let dataRows = rows.dropFirst(headerIdx + 1)

        for row in dataRows {
            let values = row.cells.map { cellStringValue($0, sharedStrings: sharedStrings) }

            let dateCol = columnMap["Date"] ?? 0
            let descCol = columnMap["Description"] ?? 1
            let amountCol = columnMap["Amount"] ?? 4
            let categoryCol = columnMap["Category"] ?? 12
            let cardMemberCol = columnMap["Card Member"] ?? 2

            guard dateCol < values.count, !values[dateCol].isEmpty else { continue }

            let dateStr = values[dateCol]
            let description = descCol < values.count ? values[descCol] : ""
            let amexCategory = categoryCol < values.count ? values[categoryCol] : ""
            let cardMember = cardMemberCol < values.count ? values[cardMemberCol] : ""

            guard !description.isEmpty else { continue }

            // Parse date
            guard let date = dateFormatter.date(from: dateStr) else {
                warnings.append("Bad date '\(dateStr)' for: \(description)")
                continue
            }

            // Parse amount from numeric cell
            let amount: Decimal
            if let numericValue = numericCellValue(row: row, columnMap: columnMap, column: "Amount") {
                amount = numericValue
            } else {
                let amountStr = amountCol < values.count ? values[amountCol] : ""
                guard let parsed = Decimal(string: amountStr.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: "")) else {
                    warnings.append("Bad amount for: \(description)")
                    continue
                }
                amount = parsed
            }

            let isCredit = amount < 0
            let mappedCategory = mapAmexCategory(amexCategory)

            transactions.append(ParsedTransaction(
                date: date,
                rawDescription: description.trimmingCharacters(in: CharacterSet.whitespaces),
                amount: amount,
                isCredit: isCredit,
                sourceCategory: mappedCategory,
                cardMember: cardMember
            ))
        }

        guard !transactions.isEmpty else {
            throw ParserError.noTransactionsFound
        }

        return ParsedStatement(
            transactions: transactions,
            statementMonth: statementMonth ?? "unknown",
            accountLastFour: accountLastFour,
            cardProductName: nil,  // XLSX doesn't contain card product info
            openingBalance: nil,
            closingBalance: nil,
            warnings: warnings
        )
    }

    // MARK: - Cell Helpers

    private func cellStringValue(_ cell: Cell, sharedStrings: SharedStrings) -> String {
        if cell.type == .sharedString, let idx = cell.value.flatMap({ Int($0) }) {
            guard idx < sharedStrings.items.count else { return "" }
            return sharedStrings.items[idx].text ?? ""
        }
        return cell.value ?? ""
    }

    private func numericCellValue(row: Row, columnMap: [String: Int], column: String) -> Decimal? {
        guard let colIdx = columnMap[column] else { return nil }
        let colLetter = columnIndexToLetter(colIdx)
        guard let colRef = ColumnReference(colLetter) else { return nil }

        for cell in row.cells {
            if cell.reference.column == colRef, cell.type != .sharedString, let value = cell.value {
                return Decimal(string: value)
            }
        }
        return nil
    }

    private func columnIndexToLetter(_ index: Int) -> String {
        var result = ""
        var idx = index
        repeat {
            result = String(Character(UnicodeScalar(65 + idx % 26)!)) + result
            idx = idx / 26 - 1
        } while idx >= 0
        return result
    }

    // MARK: - Metadata Extraction

    private func extractStatementMonth(from rows: [Row], sharedStrings: SharedStrings) -> String? {
        // Row 1: "Transaction Details" | "Platinum Card® / Dec 30, 2025 to Jan 29, 2026"
        guard !rows.isEmpty else { return nil }

        for cell in rows[0].cells {
            let value = cellStringValue(cell, sharedStrings: sharedStrings)
            if value.contains(" to ") {
                let parts = value.components(separatedBy: " to ")
                if let endDateStr = parts.last?.trimmingCharacters(in: .whitespaces) {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.dateFormat = "MMM dd, yyyy"
                    if let date = formatter.date(from: endDateStr) {
                        return DateFormatters.monthKey.string(from: date)
                    }
                }
            }
        }
        return nil
    }

    private func extractAccountLastFour(from rows: [Row], sharedStrings: SharedStrings) -> String? {
        // Rows 4-5: "XXXX-XXXXXX-02005"
        for row in rows.prefix(6) {
            for cell in row.cells {
                let value = cellStringValue(cell, sharedStrings: sharedStrings)
                if value.contains("XXXX") && value.contains("-") {
                    let digits = value.filter(\.isNumber)
                    if digits.count >= 4 {
                        return String(digits.suffix(5))
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Category Mapping

    private func mapAmexCategory(_ amexCategory: String) -> String? {
        guard !amexCategory.isEmpty else { return nil }

        let exactMap: [String: String] = [
            "Travel-Airline": "Flights",
            "Travel-Hotel": "Hotels",
            "Travel-Travel Agencies": "Hotels",
            "Travel-Other Travel": "Activities & Tours",
            "Transportation-Taxis & Coach": "Rideshare",
            "Transportation-Fuel": "Gas",
            "Transportation-Parking": "Parking",
            "Transportation-Parking Charges": "Parking",
            "Restaurant-Restaurant": "Dining Out",
            "Restaurant-Bar & Café": "Dining Out",
            "Merchandise & Supplies-Internet Purchase": "Online Shopping",
            "Merchandise & Supplies-Department Stores": "In Store Shopping",
            "Merchandise & Supplies-Clothing Stores": "In Store Shopping",
            "Merchandise & Supplies-Sporting Goods Stores": "In Store Shopping",
            "Merchandise & Supplies-General Retail": "In Store Shopping",
            "Merchandise & Supplies-Groceries": "Groceries",
            "Merchandise & Supplies-Wholesale Stores": "Groceries",
            "Merchandise & Supplies-Pharmacies": "Healthcare",
            "Merchandise & Supplies-Electronics Stores": "Electronics",
            "Merchandise & Supplies-Mail Order": "Online Shopping",
            "Entertainment-General Attractions": "Activities & Tours",
            "Entertainment-Associations": "Entertainment",
            "Entertainment-Movie Theatres": "Entertainment",
            "Fees & Adjustments-Fees & Adjustments": "Fees & Interest",
            "Communications-Cable & Internet Communications": "App Subscriptions",
            "Communications-Online Services": "Software",
            "Other-Charitable & Social": "Gifts & Donations",
            "Other-Education": "Education",
            "Other-Medical": "Healthcare",
            "Other-Insurance": "Insurance",
            "Other-Personal Services": "Salon & Spa",
            "Other-Miscellaneous": "Online Shopping",
        ]

        if let mapped = exactMap[amexCategory] { return mapped }

        let prefixMap: [String: String] = [
            "Travel": "Flights",
            "Transportation": "Rideshare",
            "Restaurant": "Dining Out",
            "Merchandise & Supplies": "Online Shopping",
            "Entertainment": "Entertainment",
            "Fees & Adjustments": "Fees & Interest",
            "Communications": "App Subscriptions",
        ]

        for (prefix, category) in prefixMap {
            if amexCategory.hasPrefix(prefix) { return category }
        }

        return nil
    }
}
