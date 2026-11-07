import XCTest
@testable import FauxFilmKit

final class CropTests: XCTestCase {
    let pano = CGSize(width: 4000, height: 1000)
    let mini = 46.0 / 62.0

    func testPanoramaFills() {
        let r = Crop().sourceRect(imageSize: pano, targetAspect: mini)
        XCTAssertEqual(r.height, 1000, accuracy: 0.001)
        XCTAssertEqual(r.width, 741.935, accuracy: 0.01)
        XCTAssertTrue(CGRect(origin: .zero, size: pano).contains(r))
    }

    func testCenterClamps() {
        var c = Crop()
        c.center = CGPoint(x: 0, y: 0)
        XCTAssertEqual(c.sourceRect(imageSize: pano, targetAspect: mini).origin, .zero)
        c.center = CGPoint(x: 1, y: 1)
        XCTAssertEqual(c.sourceRect(imageSize: pano, targetAspect: mini).maxX, 4000, accuracy: 0.001)
        let clamped = c.clamped(imageSize: pano, targetAspect: mini)
        XCTAssertEqual(clamped.center.x, (4000 - 741.935 / 2) / 4000, accuracy: 0.0001)
        XCTAssertEqual(clamped.center.y, 0.5, accuracy: 0.0001)
    }

    func testZoomHalves() {
        let base = Crop().sourceRect(imageSize: pano, targetAspect: mini)
        var c = Crop()
        c.zoom = 2
        let z = c.sourceRect(imageSize: pano, targetAspect: mini)
        XCTAssertEqual(z.width, base.width / 2, accuracy: 0.001)
        XCTAssertEqual(z.height, base.height / 2, accuracy: 0.001)
    }

    func testZoomClamped() {
        var c = Crop()
        c.zoom = 0.2
        XCTAssertEqual(c.sourceRect(imageSize: pano, targetAspect: mini), Crop().sourceRect(imageSize: pano, targetAspect: mini))
    }
}
