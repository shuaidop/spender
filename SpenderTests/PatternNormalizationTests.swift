import XCTest
@testable import Spender

@MainActor
final class PatternNormalizationTests: XCTestCase {

    // MARK: - Prefix Stripping

    func testStripsTSTPrefix() {
        XCTAssertEqual(
            ClassificationEngine.normalizePattern("TST* CHIPOTLE ONLINE"),
            "chipotle online"
        )
    }

    func testStripsSQPrefixWithSpace() {
        XCTAssertEqual(
            ClassificationEngine.normalizePattern("SQ *BLUE BOTTLE COFFEE"),
            "blue bottle coffee"
        )
    }

    func testStripsSQPrefixNoSpace() {
        XCTAssertEqual(
            ClassificationEngine.normalizePattern("SQ*BLUE BOTTLE"),
            "blue bottle"
        )
    }

    func testStripsPPPrefix() {
        XCTAssertEqual(
            ClassificationEngine.normalizePattern("PP*PAYPAL TRANSFER"),
            "paypal transfer"
        )
    }

    func testStripsSPPrefixWithSpace() {
        XCTAssertEqual(
            ClassificationEngine.normalizePattern("SP * SOME MERCHANT"),
            "some merchant"
        )
    }

    func testStripsSPPrefixNoSpace() {
        XCTAssertEqual(
            ClassificationEngine.normalizePattern("SP*SOME MERCHANT"),
            "some merchant"
        )
    }

    func testStripsCKOPrefix() {
        let result = ClassificationEngine.normalizePattern("CKO*checkout.com")
        XCTAssertTrue(result.contains("checkout"))
        XCTAssertFalse(result.hasPrefix("cko"))
    }

    func testStripsFSPrefix() {
        let result = ClassificationEngine.normalizePattern("FS*MERCHANT NAME")
        XCTAssertEqual(result, "merchant name")
    }

    // MARK: - Reference ID Stripping

    func testStripsAmazonReferenceID() {
        let result = ClassificationEngine.normalizePattern("AMAZON.COM*2K7HJ1LA0")
        XCTAssertEqual(result, "amazon.com")
    }

    func testAmazonVariantsNormalizeToSameKey() {
        let key1 = ClassificationEngine.normalizePattern("AMAZON.COM*2K7HJ1LA0")
        let key2 = ClassificationEngine.normalizePattern("AMAZON.COM*3X9YZ2MB1")
        let key3 = ClassificationEngine.normalizePattern("AMAZON.COM*ABC12345Z")
        XCTAssertEqual(key1, key2, "Different Amazon ref IDs should normalize to same key")
        XCTAssertEqual(key2, key3)
    }

    func testShortRefIdNotStripped() {
        // Reference IDs shorter than 4 chars should NOT be stripped
        let result = ClassificationEngine.normalizePattern("MERCHANT*AB")
        XCTAssertTrue(result.contains("ab"), "Short ref IDs (<4 chars) should be preserved")
    }

    func testExactlyFourCharRefIdStripped() {
        let result = ClassificationEngine.normalizePattern("STORE*ABCD")
        XCTAssertEqual(result, "store", "4-char ref ID should be stripped")
    }

    // MARK: - Location / City / State / Zip Stripping

    func testStripsTrailingStateAndZip() {
        let result = ClassificationEngine.normalizePattern("COFFEE SHOP SAN FRANCISCO CA 94105")
        XCTAssertFalse(result.contains("94105"), "Zip code should be stripped")
    }

    func testStripsTrailingZipCode() {
        let result = ClassificationEngine.normalizePattern("SOME STORE 10001")
        XCTAssertFalse(result.contains("10001"))
    }

    func testStripsExtendedZipCode() {
        let result = ClassificationEngine.normalizePattern("SOME STORE 10001-1234")
        XCTAssertFalse(result.contains("10001"))
    }

    // MARK: - Store Number Stripping

    func testStripsStoreNumber() {
        let result = ClassificationEngine.normalizePattern("WHOLE FOODS #1234")
        XCTAssertEqual(result, "whole foods")
    }

    func testStripsStoreNumberLargeDigits() {
        let result = ClassificationEngine.normalizePattern("TRADER JOES #56789")
        XCTAssertEqual(result, "trader joes")
    }

    // MARK: - URL Suffix Stripping

    func testStripsURLSuffix() {
        let result = ClassificationEngine.normalizePattern("AMAZON.COM AMZN.COM/BILL")
        XCTAssertFalse(result.contains("amzn.com"))
    }

    // MARK: - Whitespace Normalization

    func testNormalizesMultipleSpaces() {
        let result = ClassificationEngine.normalizePattern("UBER   EATS")
        XCTAssertEqual(result, "uber eats")
    }

    func testTrimsLeadingTrailingWhitespace() {
        let result = ClassificationEngine.normalizePattern("  STARBUCKS  ")
        XCTAssertEqual(result, "starbucks")
    }

    func testTrimsTrailingPunctuation() {
        let result = ClassificationEngine.normalizePattern("MERCHANT NAME.")
        XCTAssertEqual(result, "merchant name")
    }

    // MARK: - Case Normalization

    func testLowercasesEverything() {
        let result = ClassificationEngine.normalizePattern("STARBUCKS COFFEE")
        XCTAssertEqual(result, "starbucks coffee")
    }

    func testMixedCaseNormalized() {
        let result = ClassificationEngine.normalizePattern("McDonald's")
        XCTAssertEqual(result, "mcdonald's")
    }

    // MARK: - Combined Transformations

    func testSQWithLocation() {
        let result = ClassificationEngine.normalizePattern("SQ *BLUE BOTTLE COFFEE SAN FRANCISCO CA 94105")
        XCTAssertTrue(result.contains("blue bottle coffee"))
        XCTAssertFalse(result.hasPrefix("sq"))
        XCTAssertFalse(result.contains("94105"))
    }

    // MARK: - Similar Merchants Normalize to Same Key

    func testDifferentStarbucksLocations() {
        let key1 = ClassificationEngine.normalizePattern("STARBUCKS STORE #12345")
        let key2 = ClassificationEngine.normalizePattern("STARBUCKS STORE #67890")
        XCTAssertEqual(key1, key2, "Different Starbucks store numbers should normalize to same key")
    }

    func testSQVariants() {
        let key1 = ClassificationEngine.normalizePattern("SQ *JOE COFFEE")
        let key2 = ClassificationEngine.normalizePattern("SQ*JOE COFFEE")
        XCTAssertEqual(key1, key2)
    }

    // MARK: - Edge Cases

    func testEmptyString() {
        let result = ClassificationEngine.normalizePattern("")
        XCTAssertEqual(result, "")
    }

    func testSimpleMerchantName() {
        let result = ClassificationEngine.normalizePattern("Netflix")
        XCTAssertEqual(result, "netflix")
    }

    func testOnlyWhitespace() {
        let result = ClassificationEngine.normalizePattern("   ")
        XCTAssertEqual(result, "")
    }

    func testOnlyPunctuation() {
        let result = ClassificationEngine.normalizePattern("***")
        XCTAssertEqual(result, "")
    }
}
