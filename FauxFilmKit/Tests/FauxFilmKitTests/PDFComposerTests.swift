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
