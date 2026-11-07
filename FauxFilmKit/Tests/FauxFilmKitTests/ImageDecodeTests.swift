import XCTest
@testable import FauxFilmKit

final class ImageDecodeTests: XCTestCase {
    func testExifOrientation() throws {
        let image = try XCTUnwrap(ImageDecoder.decode(data: TestImages.jpeg(width: 200, height: 100, orientation: 6)))
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 200)
    }

    func testDownsample() throws {
        let image = try XCTUnwrap(ImageDecoder.decode(data: TestImages.jpeg(width: 8000, height: 6000)))
        XCTAssertLessThanOrEqual(max(image.width, image.height), 4096)
        XCTAssertGreaterThan(max(image.width, image.height), 4000)
    }

    func testRotate() {
        let r = ImageOps.rotated(TestImages.solid(width: 200, height: 100), quarterTurns: 1)
        XCTAssertEqual(r.width, 100)
        XCTAssertEqual(r.height, 200)
        XCTAssertEqual(ImageOps.rotated(TestImages.solid(width: 200, height: 100), quarterTurns: 2).width, 200)
    }
}
