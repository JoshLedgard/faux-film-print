import XCTest
@testable import FauxFilmKit

final class SessionStoreTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testRoundTripKeepsEverythingInOrder() throws {
        let a = PrintItem(image: TestImages.solid(width: 300, height: 200), format: .instaxWide,
                          crop: Crop(zoom: 2.5, center: CGPoint(x: 0.3, y: 0.6), quarterTurns: 1),
                          look: .faded, copies: 3)
        let b = PrintItem(image: TestImages.solid(width: 100, height: 400), format: .polaroidSquare)
        try SessionStore.save([a, b], to: dir)

        let loaded = SessionStore.load(from: dir)
        XCTAssertEqual(loaded.map(\.id), [a.id, b.id])
        XCTAssertEqual(loaded[0].format, .instaxWide)
        XCTAssertEqual(loaded[0].crop, a.crop)
        XCTAssertEqual(loaded[0].look, .faded)
        XCTAssertEqual(loaded[0].copies, 3)
        XCTAssertEqual(loaded[0].image.width, 300)
        XCTAssertEqual(loaded[0].image.height, 200)
        XCTAssertEqual(loaded[1].image.height, 400)
    }

    func testRemovedItemsImageIsDeleted() throws {
        let a = PrintItem(image: TestImages.solid(width: 50, height: 50), format: .instaxMini)
        let b = PrintItem(image: TestImages.solid(width: 50, height: 50), format: .instaxMini)
        try SessionStore.save([a, b], to: dir)
        try SessionStore.save([b], to: dir)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("photos").path)
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].hasPrefix(b.id.uuidString))
        XCTAssertEqual(SessionStore.load(from: dir).map(\.id), [b.id])
    }

    func testMissingOrCorruptStoreLoadsEmpty() throws {
        XCTAssertTrue(SessionStore.load(from: dir).isEmpty)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("session.json"))
        XCTAssertTrue(SessionStore.load(from: dir).isEmpty)
    }

    func testItemWithMissingPhotoIsSkipped() throws {
        let a = PrintItem(image: TestImages.solid(width: 50, height: 50), format: .instaxMini)
        let b = PrintItem(image: TestImages.solid(width: 50, height: 50), format: .instaxMini)
        try SessionStore.save([a, b], to: dir)
        let photos = dir.appendingPathComponent("photos")
        for f in try FileManager.default.contentsOfDirectory(atPath: photos.path) where f.hasPrefix(a.id.uuidString) {
            try FileManager.default.removeItem(at: photos.appendingPathComponent(f))
        }
        XCTAssertEqual(SessionStore.load(from: dir).map(\.id), [b.id])
    }
}
