import XCTest
@testable import FauxFilmKit

@MainActor
final class SessionTests: XCTestCase {
    let img = TestImages.solid(width: 40, height: 30)

    func testAddUsesDefaultFormat() {
        let s = Session()
        s.defaultFormat = .instaxWide
        s.add([img, img])
        XCTAssertEqual(s.items.count, 2)
        XCTAssertTrue(s.items.allSatisfy { $0.format == .instaxWide && $0.copies == 1 && $0.look == .none && $0.crop == Crop() })
        XCTAssertEqual(s.selection, [s.items[1].id])
    }

    func testSetFormatResetsCropAndUpdatesDefault() {
        let s = Session()
        s.add([img, img])
        let first = s.items[0].id
        s.updateCrop(Crop(zoom: 3), for: first)
        s.updateCrop(Crop(zoom: 2), for: s.items[1].id)
        s.selection = [first]
        s.setFormat(.polaroidSquare)
        XCTAssertEqual(s.items[0].format, .polaroidSquare)
        XCTAssertEqual(s.items[0].crop, Crop())
        XCTAssertEqual(s.items[1].format, .instaxMini)
        XCTAssertEqual(s.items[1].crop.zoom, 2)
        XCTAssertEqual(s.defaultFormat, .polaroidSquare)
    }

    func testSetFormatKeepsQuarterTurns() {
        let s = Session()
        s.add([img])
        s.updateCrop(Crop(zoom: 3, quarterTurns: 1), for: s.items[0].id)
        s.setFormat(.instaxSquare)
        XCTAssertEqual(s.items[0].crop, Crop(quarterTurns: 1))
    }

    func testRemoveClearsSelection() {
        let s = Session()
        s.add([img, img])
        let id = s.items[1].id
        s.remove([id])
        XCTAssertEqual(s.items.count, 1)
        XCTAssertFalse(s.selection.contains(id))
    }

    func testSetLookAndCopies() {
        let s = Session()
        s.add([img])
        s.setLook(.faded)
        s.setCopies(500, for: s.items[0].id)
        XCTAssertEqual(s.items[0].look, .faded)
        XCTAssertEqual(s.items[0].copies, 99)
    }

    func testPagesDelegatesToPaginator() {
        let s = Session()
        s.add([img, img])
        XCTAssertEqual(s.pages().count, 1)
        XCTAssertEqual(s.pages()[0].items.compactMap { $0 }.count, 2)
    }
}
