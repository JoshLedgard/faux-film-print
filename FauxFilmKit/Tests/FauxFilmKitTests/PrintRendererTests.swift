import XCTest
@testable import FauxFilmKit

final class PrintRendererTests: XCTestCase {
    func item(_ image: CGImage, _ format: FilmFormat = .instaxMini) -> PrintItem {
        PrintItem(image: image, format: format)
    }

    func testPictureSizeMini300dpi() {
        let pic = PrintRenderer.renderPicture(item(TestImages.solid(width: 1200, height: 900)), options: RenderOptions())
        XCTAssertEqual(pic.width, 543)
        XCTAssertEqual(pic.height, 732)
    }

    func testTransparentPNGIsOpaque() {
        let pic = PrintRenderer.renderPicture(item(TestImages.solid(width: 300, height: 300, gray: 0, alpha: 0)),
                                              options: RenderOptions())
        XCTAssertEqual(TestImages.pixel(pic, x: pic.width / 2, y: pic.height / 2).a, 255)
    }

    func testCardBorderColour() {
        let card = PrintRenderer.cardImage(item(TestImages.solid(width: 400, height: 400, gray: 0.1)),
                                           options: RenderOptions(), pixelsPerMM: 10)
        XCTAssertEqual(card.width, 540)
        XCTAssertEqual(card.height, 860)
        let p = TestImages.pixel(card, x: 270, y: 800) // (27 mm, 80 mm): bottom strip
        XCTAssertEqual(p.r, 0xF6, accuracy: 2)
        XCTAssertEqual(p.g, 0xF4, accuracy: 2)
        XCTAssertEqual(p.b, 0xEE, accuracy: 2)
        let pic = TestImages.pixel(card, x: 270, y: 300) // inside the picture window
        XCTAssertLessThan(pic.g, 80)
    }

    func testRotatedCardPutsStripOnLeft() {
        // A rotated (90° clockwise) card drawn into a landscape-shaped context:
        // the thick bottom strip ends up on the left.
        let it = item(TestImages.solid(width: 400, height: 400, gray: 0.1))
        let pic = PrintRenderer.renderPicture(it, options: RenderOptions())
        let s = 10.0
        let ctx = CGContext(data: nil, width: 860, height: 540, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: s / MM.pointsPerMM, y: s / MM.pointsPerMM)
        PrintRenderer.drawCard(it, picture: pic, in: ctx,
                               cardRectPt: CGRect(x: 0, y: 0, width: MM.toPoints(86), height: MM.toPoints(54)),
                               rotated: true, options: RenderOptions())
        let img = ctx.makeImage()!
        XCTAssertGreaterThan(TestImages.pixel(img, x: 80, y: 270).g, 200)   // 8 mm from left: strip
        XCTAssertLessThan(TestImages.pixel(img, x: 600, y: 270).g, 80)      // 60 mm from left: picture
    }
}
