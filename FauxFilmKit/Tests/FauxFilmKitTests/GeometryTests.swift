import XCTest
@testable import FauxFilmKit

final class GeometryTests: XCTestCase {
    func testPictureRects() {
        XCTAssertEqual(FilmFormat.instaxMini.spec.pictureRect, CGRect(x: 4, y: 6, width: 46, height: 62))
        XCTAssertEqual(FilmFormat.instaxSquare.spec.pictureRect, CGRect(x: 5, y: 7, width: 62, height: 62))
        XCTAssertEqual(FilmFormat.instaxWide.spec.pictureRect, CGRect(x: 4.5, y: 6, width: 99, height: 62))
        XCTAssertEqual(FilmFormat.polaroidSquare.spec.pictureRect, CGRect(x: 4.5, y: 6, width: 79, height: 79))
        XCTAssertEqual(FilmFormat.instaxMini.spec.cardSize, CGSize(width: 54, height: 86))
    }

    func testPointsConversion() {
        XCTAssertEqual(MM.toPoints(25.4), 72, accuracy: 0.0001)
        XCTAssertEqual(MM.toPoints(Paper.letter.width), 612, accuracy: 0.01)
        XCTAssertEqual(MM.toPoints(Paper.letter.height), 792, accuracy: 0.01)
    }
}
