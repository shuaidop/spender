import XCTest
@testable import Spender

// MARK: - Chase Parser Tests

final class ChaseParserTests: XCTestCase {

    private func makeParser() -> ChaseStatementParser {
        ChaseStatementParser()
    }

    // MARK: - Basic Transaction Parsing

    func testParsesBasicChaseStatement() throws {
        let text = """
        CARDMEMBER
        Account Number: XXXX XXXX XXXX 2415
        Opening/Closing Date 01/05/26 - 02/04/26

        ACCOUNT ACTIVITY

        PURCHASE
        01/27 Microsoft*Microsoft 365 P 425-6816830 WA 10.65
        01/30 DNH*GODADDY#4006277866 480-5058855 AZ 44.59
        02/01 Amazon web services aws.amazon.co WA .52

        INTEREST CHARGES
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.transactions.count, 3)
        XCTAssertEqual(result.accountLastFour, "2415")
        XCTAssertEqual(result.statementMonth, "2026-02")
    }

    func testParsesChaseAmounts() throws {
        let text = """
        CARDMEMBER
        Opening/Closing Date 01/05/26 - 02/04/26

        ACCOUNT ACTIVITY

        PURCHASE
        01/15 Some Store 1,234.56
        01/16 Small Purchase .52
        01/17 Normal Purchase 10.65

        INTEREST CHARGES
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.transactions.count, 3)
        XCTAssertEqual(result.transactions[0].amount, Decimal(string: "1234.56"))
        XCTAssertEqual(result.transactions[1].amount, Decimal(string: "0.52"))
        XCTAssertEqual(result.transactions[2].amount, Decimal(string: "10.65"))
    }

    // MARK: - Credits and Payments

    func testParsesPaymentsAsCredits() throws {
        let text = """
        CARDMEMBER
        Opening/Closing Date 01/05/26 - 02/04/26

        ACCOUNT ACTIVITY

        PAYMENTS AND OTHER CREDITS
        02/01 AUTOMATIC PAYMENT - THANK YOU -563.34

        PURCHASE
        01/27 Some Purchase 10.65

        INTEREST CHARGES
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        let payment = result.transactions.first { $0.isCredit }
        XCTAssertNotNil(payment, "Payment should be marked as credit")
        XCTAssertTrue(payment!.amount < 0, "Credit amount should be negative")
    }

    // MARK: - Year Boundary Resolution

    func testResolvesYearBoundaryDates() throws {
        let text = """
        CARDMEMBER
        Opening/Closing Date 12/05/25 - 01/04/26

        ACCOUNT ACTIVITY

        PURCHASE
        12/15 December Purchase 25.00
        01/02 January Purchase 30.00

        INTEREST CHARGES
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.transactions.count, 2)

        let cal = Calendar.current
        let decTxn = result.transactions.first { cal.component(.month, from: $0.date) == 12 }
        let janTxn = result.transactions.first { cal.component(.month, from: $0.date) == 1 }

        XCTAssertNotNil(decTxn)
        XCTAssertNotNil(janTxn)
        XCTAssertEqual(cal.component(.year, from: decTxn!.date), 2025, "December transaction should be in 2025")
        XCTAssertEqual(cal.component(.year, from: janTxn!.date), 2026, "January transaction should be in 2026")
    }

    // MARK: - Statement Period Extraction

    func testExtractsStatementPeriod() throws {
        let text = """
        CARDMEMBER
        Opening/Closing Date 01/05/26 - 02/04/26

        ACCOUNT ACTIVITY

        PURCHASE
        01/15 Test Purchase 10.00

        INTEREST CHARGES
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.statementMonth, "2026-02")
    }

    func testExtractsStatementPeriodWith4DigitYear() throws {
        let text = """
        CARDMEMBER
        Opening/Closing Date 01/05/2026 - 02/04/2026

        ACCOUNT ACTIVITY

        PURCHASE
        01/15 Test Purchase 10.00

        INTEREST CHARGES
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.statementMonth, "2026-02")
    }

    // MARK: - Card Product Detection

    func testDetectsSapphireReserve() throws {
        let text = """
        Sapphire Reserve
        CARDMEMBER
        Opening/Closing Date 01/05/26 - 02/04/26

        ACCOUNT ACTIVITY

        PURCHASE
        01/15 Test Purchase 10.00

        INTEREST CHARGES
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.cardProductName, "Sapphire Reserve")
    }

    func testDetectsFreedomUnlimited() throws {
        let text = """
        Freedom Unlimited
        CARDMEMBER
        Opening/Closing Date 01/05/26 - 02/04/26

        ACCOUNT ACTIVITY

        PURCHASE
        01/15 Test 10.00

        INTEREST CHARGES
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.cardProductName, "Freedom Unlimited")
    }

    // MARK: - Account Number Extraction

    func testExtractsAccountLastFour() throws {
        let text = """
        CARDMEMBER
        Account Number: XXXX XXXX XXXX 2415
        Opening/Closing Date 01/05/26 - 02/04/26

        ACCOUNT ACTIVITY

        PURCHASE
        01/15 Test 10.00

        INTEREST CHARGES
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.accountLastFour, "2415")
    }

    // MARK: - Section Tracking

    func testParsesFeesSectionCorrectly() throws {
        let text = """
        CARDMEMBER
        Opening/Closing Date 01/05/26 - 02/04/26

        ACCOUNT ACTIVITY

        FEES CHARGED
        01/20 ANNUAL MEMBERSHIP FEE 550.00

        PURCHASE
        01/15 Some Purchase 10.00

        INTEREST CHARGES
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.transactions.count, 2)
        let fee = result.transactions.first { $0.rawDescription.contains("ANNUAL") }
        XCTAssertNotNil(fee)
        XCTAssertEqual(fee?.amount, 550)
    }

    // MARK: - Empty / No Transactions

    func testThrowsOnNoTransactions() {
        let text = """
        CARDMEMBER
        Opening/Closing Date 01/05/26 - 02/04/26

        ACCOUNT ACTIVITY

        INTEREST CHARGES
        """

        let parser = makeParser()
        XCTAssertThrowsError(try parser.parseText(text)) { error in
            XCTAssertTrue(error is ParserError)
        }
    }
}

// MARK: - Amex PDF Parser Tests

final class AmexPDFParserTests: XCTestCase {

    private func makeParser() -> AmexPDFStatementParser {
        AmexPDFStatementParser()
    }

    // MARK: - Basic Parsing

    func testParsesBasicAmexPDFStatement() throws {
        let text = """
        Platinum Card
        Account Ending 9-02005
        Closing Date 01/29/26

        New Charges Details
        Card Member Since '15
        Date Description Type Foreign Spend Amount
        01/05/26 UBER EATS $15.99
        01/10/26 WHOLE FOODS MARKET $85.42
        01/15/26 AMAZON.COM*2K7HJ1LA0 $29.99

        Total New Charges $131.40
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.transactions.count, 3)
        XCTAssertEqual(result.statementMonth, "2026-01")
        XCTAssertEqual(result.accountLastFour, "02005")
        XCTAssertEqual(result.cardProductName, "Platinum")
    }

    // MARK: - Payments/Credits Section

    func testParsesPaymentsAsCredits() throws {
        let text = """
        Platinum Card
        Closing Date 01/29/26

        Payments Details
        Date Description Type Foreign Spend Amount
        01/15/26 ONLINE PAYMENT - THANK YOU -$2,500.00

        New Charges Details
        Date Description Type Foreign Spend Amount
        01/20/26 SOME MERCHANT $50.00

        Total New Charges
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        let payment = result.transactions.first { $0.isCredit }
        XCTAssertNotNil(payment, "Payment should be parsed as credit")
        XCTAssertTrue(payment!.amount < 0, "Credit amount should be negative")
    }

    func testParsesCreditsSection() throws {
        let text = """
        Platinum Card
        Closing Date 01/29/26

        Credits Details
        Date Description Type Foreign Spend Amount
        01/12/26 MERCHANT REFUND -$45.00

        New Charges Details
        Date Description Type Foreign Spend Amount
        01/20/26 SOME MERCHANT $50.00

        Total New Charges
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        let credit = result.transactions.first { $0.isCredit }
        XCTAssertNotNil(credit)
        XCTAssertTrue(credit!.amount < 0)
    }

    // MARK: - Amount Parsing

    func testParsesAmountsWithCommas() throws {
        let text = """
        Platinum Card
        Closing Date 01/29/26

        New Charges Details
        Date Description Type Foreign Spend Amount
        01/05/26 BIG PURCHASE $1,234.56

        Total New Charges
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.transactions.count, 1)
        XCTAssertEqual(result.transactions.first?.amount, Decimal(string: "1234.56"))
    }

    // MARK: - Metadata Extraction

    func testExtractsClosingDate() throws {
        let text = """
        Platinum Card
        Closing Date 02/28/26

        New Charges Details
        Date Description Type Foreign Spend Amount
        02/15/26 SOME MERCHANT $10.00

        Total New Charges
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.statementMonth, "2026-02")
    }

    func testExtractsAccountDigits() throws {
        let text = """
        Platinum Card
        Account Ending 9-02005
        Closing Date 01/29/26

        New Charges Details
        Date Description Type Foreign Spend Amount
        01/15/26 TEST $10.00

        Total New Charges
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.accountLastFour, "02005")
    }

    func testDetectsGoldCard() throws {
        let text = """
        Gold Card
        Closing Date 01/29/26

        New Charges Details
        Date Description Type Foreign Spend Amount
        01/15/26 TEST $10.00

        Total New Charges
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.cardProductName, "Gold")
    }

    // MARK: - Multi-line Description

    func testParsesMultiLineDescription() throws {
        let text = """
        Platinum Card
        Closing Date 01/29/26

        New Charges Details
        Date Description Type Foreign Spend Amount
        01/05/26 HILTON HOTELS
        SAN FRANCISCO CA $350.00

        Total New Charges
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.transactions.count, 1)
        XCTAssertTrue(result.transactions.first!.rawDescription.contains("HILTON"))
    }

    // MARK: - No Transactions

    func testThrowsOnNoTransactions() {
        let text = """
        Platinum Card
        Closing Date 01/29/26

        Fees
        Annual Fee $695.00
        """

        let parser = makeParser()
        XCTAssertThrowsError(try parser.parseText(text)) { error in
            XCTAssertTrue(error is ParserError)
        }
    }

    // MARK: - Section End Markers

    func testStopsAtFeesSection() throws {
        let text = """
        Platinum Card
        Closing Date 01/29/26

        New Charges Details
        Date Description Type Foreign Spend Amount
        01/15/26 VALID PURCHASE $10.00

        Fees
        Annual Fee $695.00
        """

        let parser = makeParser()
        let result = try parser.parseText(text)

        XCTAssertEqual(result.transactions.count, 1)
        XCTAssertTrue(result.transactions.first!.rawDescription.contains("VALID"))
    }
}

// MARK: - Parser Registry Tests

final class ParserRegistryTests: XCTestCase {

    func testRegistryContainsAllParsers() {
        let registry = ParserRegistry.shared
        let parserTypes = registry.availableParsers

        XCTAssertTrue(parserTypes.count >= 3, "Registry should have at least Chase, Amex XLSX, and Amex PDF parsers")

        let parserIDs = parserTypes.map { $0.parserID }
        XCTAssertTrue(parserIDs.contains("chase_credit"))
        XCTAssertTrue(parserIDs.contains("amex_credit"))
        XCTAssertTrue(parserIDs.contains("amex_pdf"))
    }

    func testParserByBankName() {
        let registry = ParserRegistry.shared

        let chase = registry.parser(forBank: "Chase")
        XCTAssertNotNil(chase)

        let amex = registry.parser(forBank: "Amex")
        XCTAssertNotNil(amex)
    }

    func testParserByBankNameCaseInsensitive() {
        let registry = ParserRegistry.shared

        XCTAssertNotNil(registry.parser(forBank: "chase"))
        XCTAssertNotNil(registry.parser(forBank: "CHASE"))
        XCTAssertNotNil(registry.parser(forBank: "amex"))
    }

    func testParserByUnknownBank() {
        let registry = ParserRegistry.shared
        XCTAssertNil(registry.parser(forBank: "UnknownBank"))
    }
}

// MARK: - ParserError Tests

final class ParserErrorTests: XCTestCase {

    func testParserErrorDescriptions() {
        XCTAssertNotNil(ParserError.noTransactionsFound.errorDescription)
        XCTAssertNotNil(ParserError.unsupportedFormat("test").errorDescription)
        XCTAssertNotNil(ParserError.extractionFailed("test").errorDescription)
        XCTAssertNotNil(ParserError.dateParsingFailed("test").errorDescription)
        XCTAssertNotNil(ParserError.amountParsingFailed("test").errorDescription)
    }
}

// MARK: - ParsedTransaction Tests

final class ParsedTransactionTests: XCTestCase {

    func testParsedTransactionInitialization() {
        let date = Date()
        let txn = ParsedTransaction(
            date: date,
            rawDescription: "TEST MERCHANT",
            amount: Decimal(string: "42.50")!,
            isCredit: false
        )

        XCTAssertEqual(txn.rawDescription, "TEST MERCHANT")
        XCTAssertEqual(txn.amount, Decimal(string: "42.50"))
        XCTAssertFalse(txn.isCredit)
        XCTAssertNil(txn.sourceCategory)
        XCTAssertNil(txn.cardMember)
    }

    func testParsedTransactionWithOptionalFields() {
        let date = Date()
        let txn = ParsedTransaction(
            date: date,
            postDate: date,
            rawDescription: "AMEX MERCHANT",
            amount: 100,
            isCredit: false,
            sourceCategory: "Travel-Airline",
            cardMember: "JOHN DOE"
        )

        XCTAssertEqual(txn.sourceCategory, "Travel-Airline")
        XCTAssertEqual(txn.cardMember, "JOHN DOE")
        XCTAssertNotNil(txn.postDate)
    }
}
