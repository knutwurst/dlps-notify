import XCTest
@testable import DLPSNotifyCore

final class DecodingTests: XCTestCase {

    /// A trimmed but realistic slice of an actual `/wp-json/wp/v2/posts` response.
    private let sampleJSON = """
    [
      {"id":214493,"date":"2026-06-22T00:59:08","modified":"2026-06-22T01:10:22","link":"https://dlpsgame.com/eriksholm-the-stolen-dream-ps5/","title":{"rendered":"Eriksholm The Stolen Dream"}},
      {"id":214491,"date":"2026-06-22T00:56:36","modified":"2026-06-22T00:56:36","link":"https://dlpsgame.com/dredge-ps5/","title":{"rendered":"DREDGE"}}
    ]
    """

    func testDecodesPostsArray() throws {
        let posts = try JSONDecoder().decode([GamePost].self, from: Data(sampleJSON.utf8))
        XCTAssertEqual(posts.count, 2)
        XCTAssertEqual(posts[0].id, 214493)
        XCTAssertEqual(posts[0].name, "Eriksholm The Stolen Dream")
        XCTAssertEqual(posts[0].modified, "2026-06-22T01:10:22")
        XCTAssertEqual(posts[1].name, "DREDGE")
        XCTAssertEqual(posts[1].url, URL(string: "https://dlpsgame.com/dredge-ps5/"))
    }

    func testHTMLEntityDecoding() {
        XCTAssertEqual("Tom &amp; Jerry".decodingHTMLEntities(), "Tom & Jerry")
        XCTAssertEqual("A &#038; B".decodingHTMLEntities(), "A & B")
        XCTAssertEqual("Don&#8217;t Starve".decodingHTMLEntities(), "Don\u{2019}t Starve")
        XCTAssertEqual("No entities here".decodingHTMLEntities(), "No entities here")
    }

    func testClassifyUsesParsedTimestamps() {
        let newGame = GamePost(id: 1, date: "2026-06-22T00:00:00", modified: "2026-06-22T00:05:00",
                               link: "x", title: "New")
        let updated = GamePost(id: 2, date: "2026-01-01T00:00:00", modified: "2026-06-22T00:00:00",
                               link: "x", title: "Updated")
        XCTAssertTrue(ChangeDetector.classifyFirstSeen(newGame).isNew)
        XCTAssertFalse(ChangeDetector.classifyFirstSeen(updated).isNew)
    }
}
