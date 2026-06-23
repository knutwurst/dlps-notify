import XCTest
@testable import DLPSNotifyCore

final class UpdateDetailsTests: XCTestCase {

    func testExtractEntries() {
        let html = """
        <p>NAME Foo</p>
        PPSA01474 – EUR (@DUPLEX) <a>Link Download</a>
        PPSA01473 – USA (@Naoeluiscoms) (exFAT) <a>Link Download</a>
        CUSA12345 – USA <a>Link</a>
        """
        XCTAssertEqual(UpdateDetails.entries(fromHTML: html),
                       ["EUR (@DUPLEX)", "USA (@Naoeluiscoms) (exFAT)", "USA"])
    }

    func testNoEntriesWhenNoCodes() {
        XCTAssertTrue(UpdateDetails.entries(fromHTML: "<p>Just a description, no codes.</p>").isEmpty)
    }

    func testSummarizeAdded() {
        XCTAssertEqual(UpdateDetails.summarize(old: ["USA"], new: ["USA", "EUR (exFAT)"]),
                       "+ EUR (exFAT)")
    }

    func testSummarizeNilWhenNothingAdded() {
        XCTAssertNil(UpdateDetails.summarize(old: ["USA", "EUR"], new: ["USA", "EUR"]))
        XCTAssertNil(UpdateDetails.summarize(old: ["USA", "EUR"], new: ["USA"]))  // only removed
    }

    func testSummarizeCapsAtThree() {
        XCTAssertEqual(UpdateDetails.summarize(old: [], new: ["A", "B", "C", "D", "E"]),
                       "+ A, B, C +2")
    }
}
