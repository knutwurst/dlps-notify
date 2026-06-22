import XCTest
@testable import DLPSNotifyCore

final class PlatformTests: XCTestCase {

    func testPlatformsFromCategories() {
        XCTAssertEqual(Platforms.platforms(for: [81, 63019]).map(\.key), ["ps5"])
        XCTAssertEqual(Platforms.platforms(for: [4370]).map(\.key), ["ps4"])
        XCTAssertTrue(Platforms.platforms(for: [81, 55]).isEmpty)   // only genre categories
    }

    func testMatchesFilter() {
        XCTAssertTrue(Platforms.matches(categories: [63019], selectedKeys: ["ps5"]))
        XCTAssertFalse(Platforms.matches(categories: [4370], selectedKeys: ["ps5"]))
        XCTAssertTrue(Platforms.matches(categories: [4370, 81], selectedKeys: ["ps4", "ps5"]))
        // A post with no recognized platform always passes (never silently dropped).
        XCTAssertTrue(Platforms.matches(categories: [81], selectedKeys: ["ps5"]))
    }

    func testDecodingPopulatesCategoriesAndPlatform() throws {
        let json = """
        [{"id":1,"date":"2026-06-22T00:00:00","modified":"2026-06-22T00:00:00",
          "link":"https://dlpsgame.com/x-ps5/","title":{"rendered":"X"},"categories":[81,63019]}]
        """
        let posts = try JSONDecoder().decode([GamePost].self, from: Data(json.utf8))
        XCTAssertEqual(posts[0].categories, [81, 63019])
        XCTAssertEqual(posts[0].platforms.map(\.name), ["PS5"])
    }
}
