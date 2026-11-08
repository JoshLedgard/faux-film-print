import XCTest
@testable import FauxFilmKit

final class PaginationTests: XCTestCase {
    let img = TestImages.solid(width: 50, height: 50)

    func testTenMinisTwoPages() {
        let items = (0..<10).map { _ in PrintItem(image: img, format: .instaxMini) }
        let pages = Paginator.pages(for: items)
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].items.compactMap { $0 }.count, 9)
        XCTAssertEqual(pages[1].items.count, 9)
        XCTAssertEqual(pages[1].items.compactMap { $0 }.count, 1)
        XCTAssertEqual(pages[1].items.filter { $0 == nil }.count, 8)
    }

    func testMixedFormatsGrouped() {
        let a = PrintItem(image: img, format: .instaxMini)
        let b = PrintItem(image: img, format: .instaxSquare)
        let c = PrintItem(image: img, format: .instaxMini)
        let pages = Paginator.pages(for: [a, b, c])
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].layout.format, .instaxMini)
        XCTAssertEqual(pages[0].items.compactMap { $0?.id }, [a.id, c.id])
        XCTAssertEqual(pages[1].layout.format, .instaxSquare)
        XCTAssertEqual(pages[1].items.compactMap { $0?.id }, [b.id])
    }

    func testCopiesExpand() {
        let pages = Paginator.pages(for: [PrintItem(image: img, format: .instaxMini, copies: 3)])
        XCTAssertEqual(pages[0].items.compactMap { $0 }.count, 3)
    }

    func testMaxRowsHonoured() {
        let items = (0..<9).map { _ in PrintItem(image: img, format: .instaxMini) }
        let pages = Paginator.pages(for: items, maxRows: [.instaxMini: 2])
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].items.count, 6)
    }

    func testEmptyInputNoPages() {
        XCTAssertTrue(Paginator.pages(for: []).isEmpty)
    }
}
