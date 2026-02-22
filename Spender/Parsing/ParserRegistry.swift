import Foundation

final class ParserRegistry: @unchecked Sendable {
    static let shared = ParserRegistry()

    private var parsers: [any StatementParser.Type] = []

    private init() {
        register(ChaseStatementParser.self)
        register(AmexStatementParser.self)
        register(AmexPDFStatementParser.self)
    }

    func register(_ parserType: any StatementParser.Type) {
        parsers.append(parserType)
    }

    /// Auto-detect which parser to use based on file content/type
    func detectParser(for fileURL: URL) -> (any StatementParser)? {
        for parserType in parsers {
            if parserType.canParse(fileURL: fileURL) {
                return parserType.init()
            }
        }
        return nil
    }

    func parser(forBank bankName: String) -> (any StatementParser)? {
        for parserType in parsers {
            if parserType.bankName.lowercased() == bankName.lowercased() {
                return parserType.init()
            }
        }
        return nil
    }

    var availableParsers: [any StatementParser.Type] { parsers }
}
