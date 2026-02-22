import Foundation

/// Supported file types for statement import
enum StatementFileType: String {
    case pdf
    case xlsx
    case csv

    init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "pdf": self = .pdf
        case "xlsx", "xls": self = .xlsx
        case "csv": self = .csv
        default: return nil
        }
    }
}

protocol StatementParser {
    static var parserID: String { get }
    static var displayName: String { get }
    static var bankName: String { get }
    static var supportedFileTypes: [StatementFileType] { get }

    /// Check if this parser can handle the given file
    static func canParse(fileURL: URL) -> Bool

    init()

    /// Parse a statement file into structured data
    func parse(fileURL: URL) throws -> ParsedStatement
}
