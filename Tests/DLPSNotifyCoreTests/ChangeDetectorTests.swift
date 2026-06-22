import XCTest
@testable import DLPSNotifyCore

final class ChangeDetectorTests: XCTestCase {

    private func post(_ id: Int, date: String, modified: String, title: String = "Game") -> GamePost {
        GamePost(id: id, date: date, modified: modified,
                 link: "https://dlpsgame.com/game-\(id)/", title: title)
    }

    func testBrandNewGameWhenDateEqualsModified() {
        let p = post(1, date: "2026-06-22T00:56:36", modified: "2026-06-22T00:56:36")
        let (events, state) = ChangeDetector.detect(state: DetectorState(), fetched: [p])

        XCTAssertEqual(events, [.new(p)])
        XCTAssertEqual(state.seen["1"], "2026-06-22T00:56:36")
        XCTAssertEqual(state.lastModified, "2026-06-22T00:56:36")
    }

    func testNewGameWithQuickPostPublishEditStaysNew() {
        // Published 00:59, tidied up 11 minutes later — still a new game.
        let p = post(2, date: "2026-06-22T00:59:08", modified: "2026-06-22T01:10:22")
        let (events, _) = ChangeDetector.detect(state: DetectorState(), fetched: [p])
        XCTAssertEqual(events, [.new(p)])
    }

    func testOldPostSeenForFirstTimeIsAnUpdate() {
        // Old game (published months ago) bubbling up because it was just patched.
        let p = post(3, date: "2025-12-28T08:36:00", modified: "2026-06-22T07:16:00")
        let (events, _) = ChangeDetector.detect(state: DetectorState(), fetched: [p])
        XCTAssertEqual(events, [.updated(p)])
    }

    func testKnownPostWithNewerModifiedIsAnUpdate() {
        let state = DetectorState(lastModified: "2026-06-20T00:00:00",
                                  seen: ["4": "2026-06-20T00:00:00"])
        let p = post(4, date: "2026-06-19T00:00:00", modified: "2026-06-22T09:00:00")
        let (events, newState) = ChangeDetector.detect(state: state, fetched: [p])

        XCTAssertEqual(events, [.updated(p)])
        XCTAssertEqual(newState.seen["4"], "2026-06-22T09:00:00")
    }

    func testKnownPostWithSameModifiedIsDeduped() {
        let state = DetectorState(lastModified: "2026-06-22T09:00:00",
                                  seen: ["5": "2026-06-22T09:00:00"])
        let p = post(5, date: "2026-06-19T00:00:00", modified: "2026-06-22T09:00:00")
        let (events, _) = ChangeDetector.detect(state: state, fetched: [p])
        XCTAssertTrue(events.isEmpty)
    }

    func testSeedingEmitsNoEventsButPrimesState() {
        let posts = [
            post(10, date: "2026-06-22T00:56:36", modified: "2026-06-22T00:56:36"),
            post(11, date: "2026-06-22T01:00:00", modified: "2026-06-22T01:30:00"),
        ]
        let (events, state) = ChangeDetector.detect(state: DetectorState(), fetched: posts, seeding: true)

        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(state.seen.count, 2)
        XCTAssertEqual(state.lastModified, "2026-06-22T01:30:00")
    }

    func testEventsAreChronologicalOldestFirst() {
        let newer = post(20, date: "2026-06-22T05:00:00", modified: "2026-06-22T05:00:00", title: "Newer")
        let older = post(21, date: "2026-06-22T01:00:00", modified: "2026-06-22T01:00:00", title: "Older")
        // Fed newest-first; detector should reorder to oldest-first.
        let (events, _) = ChangeDetector.detect(state: DetectorState(), fetched: [newer, older])

        XCTAssertEqual(events.map(\.post.id), [21, 20])
    }

    func testWatermarkAdvancesToMaximumModified() {
        let posts = [
            post(30, date: "2026-06-22T01:00:00", modified: "2026-06-22T01:00:00"),
            post(31, date: "2026-06-22T03:00:00", modified: "2026-06-22T03:00:00"),
            post(32, date: "2026-06-22T02:00:00", modified: "2026-06-22T02:00:00"),
        ]
        let (_, state) = ChangeDetector.detect(state: DetectorState(), fetched: posts)
        XCTAssertEqual(state.lastModified, "2026-06-22T03:00:00")
    }

    func testNewThenUpdateAcrossTwoPolls() {
        // First poll: brand new game.
        let first = post(40, date: "2026-06-22T01:00:00", modified: "2026-06-22T01:00:00")
        let (e1, s1) = ChangeDetector.detect(state: DetectorState(), fetched: [first])
        XCTAssertEqual(e1, [.new(first)])

        // Second poll: same id, later modification -> update, not a new game.
        let second = post(40, date: "2026-06-22T01:00:00", modified: "2026-06-22T08:00:00")
        let (e2, _) = ChangeDetector.detect(state: s1, fetched: [second])
        XCTAssertEqual(e2, [.updated(second)])
    }
}
