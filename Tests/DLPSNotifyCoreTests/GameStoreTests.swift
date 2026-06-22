import XCTest
@testable import DLPSNotifyCore

final class GameStoreTests: XCTestCase {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("dlps-test-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    func testFreshStoreIsNotSeeded() {
        let store = GameStore(fileURL: tempURL())
        XCTAssertFalse(store.isSeeded)
        XCTAssertEqual(store.state, DetectorState())
    }

    func testSaveAndReloadRoundTrips() {
        let url = tempURL()
        let store = GameStore(fileURL: url)
        store.update(DetectorState(lastModified: "2026-06-22T09:00:00",
                                   seen: ["1": "2026-06-22T09:00:00", "2": "2026-06-21T00:00:00"]))

        let reloaded = GameStore(fileURL: url)
        XCTAssertTrue(reloaded.isSeeded)
        XCTAssertEqual(reloaded.state.lastModified, "2026-06-22T09:00:00")
        XCTAssertEqual(reloaded.state.seen["1"], "2026-06-22T09:00:00")
        XCTAssertEqual(reloaded.state.seen.count, 2)

        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
