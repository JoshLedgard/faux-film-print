import XCTest
@testable import FauxFilmKit

final class SheetLayoutTests: XCTestCase {
    func testCounts() {
        let mini = SheetLayout.make(format: .instaxMini)
        XCTAssertEqual(mini.slots.count, 9)
        XCTAssertEqual(mini.columns, 3)
        XCTAssertEqual(mini.rows, 3)
        XCTAssertFalse(mini.slots[0].rotated)

        let square = SheetLayout.make(format: .instaxSquare)
        XCTAssertEqual(square.slots.count, 6)
        XCTAssertEqual(square.columns, 2)
        XCTAssertEqual(square.rows, 3)
        XCTAssertFalse(square.slots[0].rotated)

        let wide = SheetLayout.make(format: .instaxWide)
        XCTAssertEqual(wide.slots.count, 4)
        XCTAssertTrue(wide.slots[0].rotated)
        XCTAssertEqual(wide.slots[0].rect.size, CGSize(width: 86, height: 108))

        let polaroid = SheetLayout.make(format: .polaroidSquare)
        XCTAssertEqual(polaroid.slots.count, 4)
        XCTAssertFalse(polaroid.slots[0].rotated)
    }

    func testMiniGridCentred() {
        let mini = SheetLayout.make(format: .instaxMini)
        XCTAssertEqual(mini.slots[0].rect.minX, 22.95, accuracy: 0.001)
        XCTAssertEqual(mini.slots[0].rect.minY, 6.7, accuracy: 0.001)
        XCTAssertEqual(mini.slots[8].rect.maxY, 272.7, accuracy: 0.001)
        XCTAssertEqual(mini.slots[1].rect.minX - mini.slots[0].rect.maxX, 4, accuracy: 0.001)
    }

    func testTicksNeverTouchPrints() {
        for format in FilmFormat.allCases {
            let layout = SheetLayout.make(format: format)
            XCTAssertFalse(layout.ticks.isEmpty, "\(format)")
            for tick in layout.ticks {
                let tickRect = CGRect(x: min(tick.from.x, tick.to.x), y: min(tick.from.y, tick.to.y),
                                      width: abs(tick.to.x - tick.from.x), height: abs(tick.to.y - tick.from.y))
                for slot in layout.slots {
                    XCTAssertFalse(slot.rect.insetBy(dx: -0.5, dy: -0.5).intersects(tickRect),
                                   "\(format) tick \(tick) touches \(slot.rect)")
                }
                XCTAssertTrue(CGRect(x: 0, y: 0, width: 215.9, height: 279.4).contains(tickRect), "\(format) off paper")
            }
        }
    }

    func testMiniHasNoTicksAboveOrBelowGrid() {
        let mini = SheetLayout.make(format: .instaxMini)
        for tick in mini.ticks {
            for y in [tick.from.y, tick.to.y] {
                XCTAssertGreaterThanOrEqual(y, 6.7 - 0.001)
                XCTAssertLessThanOrEqual(y, 272.7 + 0.001)
            }
        }
    }

    func testPolaroidHasOuterTicks() {
        let polaroid = SheetLayout.make(format: .polaroidSquare)
        let gridTop = polaroid.slots[0].rect.minY
        XCTAssertTrue(polaroid.ticks.contains { max($0.from.y, $0.to.y) < gridTop })
    }

    func testSideMarginTicks() {
        let mini = SheetLayout.make(format: .instaxMini)
        let expected = Tick(from: CGPoint(x: 18.95, y: 6.7), to: CGPoint(x: 21.95, y: 6.7))
        XCTAssertTrue(mini.ticks.contains { t in
            abs(t.from.x - expected.from.x) < 0.001 && abs(t.to.x - expected.to.x) < 0.001
                && abs(t.from.y - 6.7) < 0.001 && abs(t.to.y - 6.7) < 0.001
        })
    }

    func testMaxRows() {
        XCTAssertEqual(SheetLayout.make(format: .instaxMini, maxRows: 2).slots.count, 6)
    }

    func testIsInside() {
        let mini = SheetLayout.make(format: .instaxMini)
        XCTAssertTrue(mini.isInside(CGRect(x: 3.2, y: 3.2, width: 209.5, height: 273)))
        XCTAssertFalse(mini.isInside(CGRect(x: 3.2, y: 3.2, width: 209.5, height: 279.4 - 3.2 - 12.7)))
    }
}
