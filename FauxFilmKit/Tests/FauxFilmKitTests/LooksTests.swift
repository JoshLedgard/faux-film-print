import XCTest
@testable import FauxFilmKit

final class LooksTests: XCTestCase {
    func testNoneLookIsIdentity() {
        let src = TestImages.solid(width: 64, height: 64, gray: 0.5)
        let out = LookProcessor.apply(.none, printBrightness: 0, to: src)
        let a = TestImages.pixel(src, x: 32, y: 32), b = TestImages.pixel(out, x: 32, y: 32)
        XCTAssertLessThanOrEqual(abs(a.r - b.r), 2)
        XCTAssertLessThanOrEqual(abs(a.g - b.g), 2)
        XCTAssertLessThanOrEqual(abs(a.b - b.b), 2)
    }

    func testInstantChangesPixels() {
        let src = TestImages.solid(width: 64, height: 64, gray: 0.5)
        let out = LookProcessor.apply(.instant, printBrightness: 0, to: src)
        let a = TestImages.pixel(src, x: 32, y: 32), b = TestImages.pixel(out, x: 32, y: 32)
        XCTAssertGreaterThan(max(abs(a.r - b.r), abs(a.g - b.g), abs(a.b - b.b)), 3)
    }

    func testBrightnessBrightens() {
        let src = TestImages.solid(width: 64, height: 64, gray: 0.5)
        let out = LookProcessor.apply(.none, printBrightness: 0.25, to: src)
        XCTAssertGreaterThan(TestImages.pixel(out, x: 32, y: 32).g, TestImages.pixel(src, x: 32, y: 32).g + 5)
    }
}
