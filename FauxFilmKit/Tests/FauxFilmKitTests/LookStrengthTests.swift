import XCTest
@testable import FauxFilmKit

final class LookStrengthTests: XCTestCase {
    func centre(_ img: CGImage) -> (r: Int, g: Int, b: Int, a: Int) {
        TestImages.pixel(img, x: img.width / 2, y: img.height / 2)
    }

    func testStrengthZeroIsIdentity() {
        let src = TestImages.solid(width: 64, height: 64, gray: 0.5)
        let out = LookProcessor.apply(.polaroid, strength: 0, printBrightness: 0, to: src)
        XCTAssertEqual(centre(out).r, centre(src).r, accuracy: 2)
        XCTAssertEqual(centre(out).b, centre(src).b, accuracy: 2)
    }

    func testHalfStrengthIsBetween() {
        let src = TestImages.solid(width: 64, height: 64, gray: 0.02)
        let full = centre(LookProcessor.apply(.faded, strength: 1, printBrightness: 0, to: src)).g
        let half = centre(LookProcessor.apply(.faded, strength: 0.5, printBrightness: 0, to: src)).g
        let none = centre(src).g
        XCTAssertGreaterThan(half, none + 3)
        XCTAssertLessThan(half, full - 3)
    }

    func testInstaxShadowsLeanCool() {
        let out = centre(LookProcessor.apply(.instant, strength: 1, printBrightness: 0,
                                             to: TestImages.solid(width: 64, height: 64, gray: 0.15)))
        XCTAssertGreaterThan(out.b, out.r)
    }

    func testPolaroidHighlightsLeanWarm() {
        let out = centre(LookProcessor.apply(.polaroid, strength: 1, printBrightness: 0,
                                             to: TestImages.solid(width: 64, height: 64, gray: 0.85)))
        XCTAssertGreaterThan(out.r, out.b + 4)
    }

    func testFilmNeverPrintsPureWhiteOrBlack() {
        for look in [FilmLook.instant, .polaroid, .faded] {
            let white = centre(LookProcessor.apply(look, strength: 1, printBrightness: 0,
                                                   to: TestImages.solid(width: 64, height: 64, gray: 1)))
            let black = centre(LookProcessor.apply(look, strength: 1, printBrightness: 0,
                                                   to: TestImages.solid(width: 64, height: 64, gray: 0)))
            XCTAssertLessThan(max(white.r, white.g, white.b), 252, "\(look) white")
            XCTAssertGreaterThan(max(black.r, black.g, black.b), 6, "\(look) black")
        }
    }

    func testGrainAddsTexture() {
        let src = TestImages.solid(width: 128, height: 128, gray: 0.5)
        let out = LookProcessor.apply(.polaroid, strength: 1, printBrightness: 0, to: src)
        var values = Set<Int>()
        for x in stride(from: 40, to: 88, by: 3) { values.insert(TestImages.pixel(out, x: x, y: 64).g) }
        XCTAssertGreaterThan(values.count, 3)
    }
}
