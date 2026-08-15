import XCTest
@testable import DLPSNotifyCore

final class LibraryTests: XCTestCase {

    func testParseLines() {
        let games = LibraryParser.parse("""
        Alan Wake II Deluxe Edition [PPSA02572] [v01.200.007] [PS5]
        Alien Isolation [BLES01697] [PS3]
        Armored Core 6 Fires of Rubicon [CUSA32600] [v01.05] [PS4]
        """)
        XCTAssertEqual(games.count, 3)
        XCTAssertEqual(games[0].code, "PPSA02572")
        XCTAssertEqual(games[0].name, "Alan Wake II Deluxe Edition")
        XCTAssertEqual(games[0].version, "01.200.007")
        XCTAssertEqual(games[0].platform, "PS5")
        XCTAssertEqual(games[1].code, "BLES01697")
        XCTAssertNil(games[1].version)   // PS3 entry without a version
    }

    func testIndexByCodeAndName() {
        let index = LibraryIndex(games: LibraryParser.parse("Alan Wake Remastered [CUSA24653] [v01.03] [PS4]"))
        XCTAssertEqual(index.game(forCode: "cusa24653")?.version, "01.03")          // case-insensitive
        XCTAssertEqual(index.game(forName: "Alan  Wake  Remastered!")?.code, "CUSA24653")  // normalized
        XCTAssertNil(index.game(forCode: "PPSA00000"))
    }

    func testDuplicateNameKeepsHigherVersion() {
        let index = LibraryIndex(games: LibraryParser.parse("""
        Assassins Creed Valhalla Ultimate Edition [CUSA18522] [v07.00] [PS4]
        Assassins Creed Valhalla Ultimate Edition [CUSA18534] [v08.00] [PS4]
        """))
        XCTAssertEqual(index.game(forName: "Assassins Creed Valhalla Ultimate Edition")?.version, "08.00")
    }

    func testVersionCompare() {
        XCTAssertEqual(VersionCompare.isNewer("01.08", than: "01.06"), true)
        XCTAssertEqual(VersionCompare.isNewer("01.010.002", than: "01.009.000"), true)
        XCTAssertEqual(VersionCompare.isNewer("01.05", than: "01.05"), false)
        XCTAssertNil(VersionCompare.isNewer("n/a", than: "01.00"))
    }

    func testIgnoresJunkLines() {
        XCTAssertTrue(LibraryParser.parse("Just a heading\n\nno brackets here").isEmpty)
    }

    func testExtractsCodesAndVersionsFromContent() {
        XCTAssertEqual(UpdateDetails.codes(fromHTML: "PPSA01474 – EUR (@DUPLEX) CUSA32600 – USA"),
                       ["PPSA01474", "CUSA32600"])
        XCTAssertEqual(UpdateDetails.versionStrings(fromHTML: "EUR (v01.010.002) (exFAT)"),
                       ["01.010.002"])
    }
}
