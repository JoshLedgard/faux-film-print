import XCTest
@testable import FauxFilmKit

/// Prints are cut by hand: the border colour must extend a little past the card edge
/// (bleed) so a slightly-outside cut doesn't leave a white sliver.
final class BleedTests: XCTestCase {
    /// Renders page 1 of a PDF at 10 px/mm, top-left origin.
    func rasterize(_ data: Data) throws -> CGImage {
        let doc = try XCTUnwrap(CGPDFDocument(CGDataProvider(data: data as CFData)!))
        let page = try XCTUnwrap(doc.page(at: 1))
        let ppm = 10.0
        let ctx = CGContext(data: nil, width: Int(215.9 * ppm), height: Int(279.4 * ppm), bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
        ctx.scaleBy(x: ppm / MM.pointsPerMM, y: ppm / MM.pointsPerMM)
        ctx.drawPDFPage(page)
        return ctx.makeImage()!
    }

    func samplePDF(cornerGuides: Bool) throws -> (CGImage, CGRect) {
        let item = PrintItem(image: TestImages.solid(width: 200, height: 300, gray: 0.1), format: .instaxMini)
        let pages = Paginator.pages(for: [item])
        let data = PDFComposer.pdf(pages: pages, options: RenderOptions(printBrightness: 0, cornerGuides: cornerGuides))
        return (try rasterize(data), pages[0].layout.slots[0].rect)
    }

    func testBorderBleedsPastCardEdge() throws {
        let (img, slot) = try samplePDF(cornerGuides: true)
        // 0.4 mm outside the left edge, halfway down the card.
        let p = TestImages.pixel(img, x: Int((slot.minX - 0.4) * 10), y: Int(slot.midY * 10))
        XCTAssertEqual(p.r, 0xF6, accuracy: 3)
        XCTAssertEqual(p.b, 0xEE, accuracy: 3)
        // 2 mm outside is bare paper.
        let q = TestImages.pixel(img, x: Int((slot.minX - 2) * 10), y: Int(slot.midY * 10))
        XCTAssertEqual(q.b, 255)
    }

    func testSquareCornersWhenGuidesOff() throws {
        let (img, slot) = try samplePDF(cornerGuides: false)
        // 0.3 mm inside the top-left corner: border colour, not a white rounded-off nick.
        let p = TestImages.pixel(img, x: Int((slot.minX + 0.3) * 10), y: Int((slot.minY + 0.3) * 10))
        XCTAssertEqual(p.b, 0xEE, accuracy: 3)
    }

    func testSizeTestEdgeMarksAre15mmFromEdges() {
        let marks = PDFComposer.sizeTestEdgeMarkCornersMM(paper: .letter)
        XCTAssertEqual(marks.count, 2)
        XCTAssertEqual(marks[0], CGPoint(x: 15, y: 15))
        XCTAssertEqual(marks[1].x, 215.9 - 15, accuracy: 0.001)
        XCTAssertEqual(marks[1].y, 15)
    }
}
