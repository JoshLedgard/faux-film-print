import XCTest
@testable import FauxFilmKit

final class PDFComposerTests: XCTestCase {
    func document(_ data: Data) throws -> CGPDFDocument {
        try XCTUnwrap(CGPDFDocument(CGDataProvider(data: data as CFData)!))
    }

    func testPDFPageSize() throws {
        let img = TestImages.solid(width: 300, height: 400)
        let items = (0..<10).map { _ in PrintItem(image: img, format: .instaxMini) }
        let doc = try document(PDFComposer.pdf(pages: Paginator.pages(for: items), options: RenderOptions()))
        XCTAssertEqual(doc.numberOfPages, 2)
        for i in 1...2 {
            let box = try XCTUnwrap(doc.page(at: i)).getBoxRect(.mediaBox)
            XCTAssertEqual(box.width, 612, accuracy: 0.01)
            XCTAssertEqual(box.height, 792, accuracy: 0.01)
        }
    }

    func testSizeTestPDF() throws {
        let doc = try document(PDFComposer.sizeTestPDF())
        XCTAssertEqual(doc.numberOfPages, 1)
        let box = try XCTUnwrap(doc.page(at: 1)).getBoxRect(.mediaBox)
        XCTAssertEqual(box.width, 612, accuracy: 0.01)
        XCTAssertEqual(box.height, 792, accuracy: 0.01)
    }
}

final class SizeTestRulerTests: XCTestCase {
    func testSizeTestRulerIs50mm() {
        let (a, b) = PDFComposer.rulerSegmentPt()
        XCTAssertEqual(hypot(b.x - a.x, b.y - a.y), MM.toPoints(50), accuracy: 0.001)
        XCTAssertEqual(a.y, b.y)
    }

    func testImageableRectConversion() {
        // A printer imageable area of 0.25 in all round, in points (y up) → mm (y down).
        let mm = PDFComposer.imageableMM(fromPoints: CGRect(x: 18, y: 18, width: 576, height: 756), paper: .letter)
        XCTAssertEqual(mm.minX, 6.35, accuracy: 0.001)
        XCTAssertEqual(mm.minY, 6.35, accuracy: 0.001)
        XCTAssertEqual(mm.width, 203.2, accuracy: 0.001)
    }

    /// Writes sample output for a visual check: FAUXFILM_SAMPLE_DIR=/path swift test
    func testWriteSampleSheet() throws {
        guard let dir = ProcessInfo.processInfo.environment["FAUXFILM_SAMPLE_DIR"] else { throw XCTSkip("no sample dir") }
        let url = URL(fileURLWithPath: "/System/Library/Desktop Pictures/.thumbnails/Big Sur Coastline.heic")
        let photo = try XCTUnwrap(ImageDecoder.decode(url: url))
        // One sheet: None, then each film at 50 % / 80 % / 100 %.
        let looks: [(FilmLook, Double)] = [(.none, 1), (.instant, 0.5), (.instant, 0.8), (.instant, 1),
                                           (.polaroid, 0.5), (.polaroid, 0.8), (.polaroid, 1), (.faded, 0.8), (.faded, 1)]
        let items = looks.map { look, strength -> PrintItem in
            var item = PrintItem(image: photo, format: .instaxMini, look: look)
            item.lookStrength = strength
            return item
        }
        let data = PDFComposer.pdf(pages: Paginator.pages(for: items), options: RenderOptions())
        try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("sample-sheets.pdf"))
        try PDFComposer.sizeTestPDF().write(to: URL(fileURLWithPath: dir).appendingPathComponent("size-test.pdf"))
    }
}
