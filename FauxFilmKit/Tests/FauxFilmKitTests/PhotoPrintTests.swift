import XCTest
@testable import FauxFilmKit

/// Standard frameless photo prints (4 × 6 and friends) on Letter and A4.
final class PhotoPrintTests: XCTestCase {
    let photoFormats: [FilmFormat] = [.photoWallet, .photo3x5, .photo4x6, .photo5x7, .photo8x10, .photo4x4]

    func testFamilies() {
        XCTAssertEqual(FilmFormat.formats(in: .instantFilm), [.instaxMini, .instaxSquare, .instaxWide, .polaroidSquare])
        XCTAssertEqual(FilmFormat.formats(in: .photoPrint), photoFormats)
        XCTAssertTrue(photoFormats.allSatisfy(\.isPhotoPrint))
        XCTAssertFalse(FilmFormat.instaxMini.isPhotoPrint)
    }

    func testSavedRawValuesUnchanged() {
        // Saved sessions store these; renaming one would drop people's photos.
        XCTAssertEqual(FilmFormat(rawValue: "instaxMini"), .instaxMini)
        XCTAssertEqual(FilmFormat(rawValue: "polaroidSquare"), .polaroidSquare)
        XCTAssertEqual(FilmFormat.photo4x6.rawValue, "photo4x6")
    }

    func testTrueSizesInMillimetres() {
        let expected: [FilmFormat: (Double, Double)] = [
            .photoWallet: (63.5, 88.9), .photo3x5: (88.9, 127), .photo4x6: (101.6, 152.4),
            .photo5x7: (127, 177.8), .photo8x10: (203.2, 254), .photo4x4: (101.6, 101.6),
        ]
        for (format, (w, h)) in expected {
            let spec = format.spec
            XCTAssertEqual(spec.cardWidth, w, accuracy: 0.001, "\(format)")
            XCTAssertEqual(spec.cardHeight, h, accuracy: 0.001, "\(format)")
            XCTAssertTrue(spec.isFrameless, "\(format)")
            XCTAssertEqual(spec.pictureRect, CGRect(x: 0, y: 0, width: w, height: h))
            XCTAssertEqual(spec.cornerRadius, 0)
        }
        for format in FilmFormat.formats(in: .instantFilm) {
            XCTAssertFalse(format.spec.isFrameless)
            XCTAssertEqual(format.spec.pictureBleed, 0)
            XCTAssertEqual(format.spec.cropAspect, format.spec.pictureAspect)
        }
    }

    func testPrintsPerSheet() {
        let expected: [FilmFormat: Int] = [
            .photoWallet: 8, .photo3x5: 4, .photo4x6: 2, .photo5x7: 2, .photo8x10: 1, .photo4x4: 2,
        ]
        for paper in [Paper.letter, Paper.a4] {
            for (format, n) in expected {
                let layout = SheetLayout.make(format: format, paper: paper)
                XCTAssertEqual(layout.slots.count, n, "\(format) on \(paper)")
                for slot in layout.slots {
                    // Never scaled: every slot is the true print size.
                    let size = slot.rotated ? CGSize(width: format.spec.cardHeight, height: format.spec.cardWidth)
                                            : format.spec.cardSize
                    XCTAssertEqual(slot.rect.size, size, "\(format) on \(paper)")
                    XCTAssertTrue(CGRect(x: 0, y: 0, width: paper.width, height: paper.height).contains(slot.rect))
                }
            }
        }
    }

    func test8x10OnA4UsesTightMarginAndKeepsMarksOnPaper() {
        let layout = SheetLayout.make(format: .photo8x10, paper: .a4)
        XCTAssertEqual(layout.slots.count, 1)
        XCTAssertEqual(layout.slots[0].rect.minX, 3.4, accuracy: 0.001)
        XCTAssertFalse(layout.ticks.isEmpty)
        let sheet = CGRect(x: 0, y: 0, width: 210, height: 297)
        for tick in layout.ticks {
            XCTAssertTrue(sheet.contains(tick.from) && sheet.contains(tick.to), "\(tick) off paper")
            let r = CGRect(x: min(tick.from.x, tick.to.x), y: min(tick.from.y, tick.to.y),
                           width: abs(tick.to.x - tick.from.x), height: abs(tick.to.y - tick.from.y))
            XCTAssertFalse(layout.slots[0].rect.insetBy(dx: -0.5, dy: -0.5).intersects(r))
        }
    }

    func testPaginatorUsesChosenPaper() {
        let item = PrintItem(image: TestImages.solid(width: 300, height: 200), format: .photo4x6)
        let pages = Paginator.pages(for: [item], paper: .a4)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].layout.paper, .a4)
        XCTAssertEqual(PaperSize.a4.paper, .a4)
        XCTAssertEqual(PaperSize(rawValue: "letter")?.paper, .letter)
    }

    func testLandscapeTurnsTheCard() {
        var item = PrintItem(image: TestImages.solid(width: 300, height: 200), format: .photo4x6)
        XCTAssertEqual(item.spec.cardSize, CGSize(width: 101.6, height: 152.4))
        item.landscape = true
        XCTAssertEqual(item.spec.cardSize, CGSize(width: 152.4, height: 101.6))
        XCTAssertGreaterThan(item.spec.pictureAspect, 1)

        // Instant film ignores the flag.
        item.format = .instaxMini
        XCTAssertFalse(item.isLandscape)
        XCTAssertEqual(item.spec, FilmFormat.instaxMini.spec)
    }

    func testLandscapeDrawingInSlots() {
        var item = PrintItem(image: TestImages.solid(width: 300, height: 200), format: .photo4x6)
        let turnedSlot = Slot(rect: .zero, rotated: true)
        let uprightSlot = Slot(rect: .zero, rotated: false)
        XCTAssertTrue(turnedSlot.drawsRotated(item))
        XCTAssertFalse(uprightSlot.drawsRotated(item))
        item.landscape = true
        XCTAssertFalse(turnedSlot.drawsRotated(item))
        XCTAssertTrue(uprightSlot.drawsRotated(item))
    }

    func testPhotoIsLandscapeFollowsQuarterTurns() {
        var item = PrintItem(image: TestImages.solid(width: 300, height: 200), format: .photo4x6)
        XCTAssertTrue(item.photoIsLandscape)
        item.crop.quarterTurns = 1
        XCTAssertFalse(item.photoIsLandscape)
    }

    func testSourceRectInsideCutLineIsTheSameWithOrWithoutBleed() {
        let spec = FilmFormat.photo4x6.spec
        let size = CGSize(width: 4000, height: 3000)
        let crop = Crop(zoom: 1.5, center: CGPoint(x: 0.4, y: 0.5))
        let full = PrintRenderer.sourceRect(crop: crop, imageSize: size, spec: spec, bleed: spec.pictureBleed)
        let trim = PrintRenderer.sourceRect(crop: crop, imageSize: size, spec: spec, bleed: 0)
        XCTAssertEqual(Double(full.width / full.height), spec.cropAspect, accuracy: 1e-9)
        XCTAssertEqual(Double(trim.width / trim.height), spec.pictureAspect, accuracy: 1e-6)
        XCTAssertEqual(trim.midX, full.midX, accuracy: 1e-9)
        XCTAssertEqual(trim.midY, full.midY, accuracy: 1e-9)
        // Same scale: the bleed band is the bleed width in image pixels.
        let pxPerMM = Double(trim.width / spec.pictureRect.width)
        XCTAssertEqual(Double(full.width - trim.width) / 2, spec.pictureBleed * pxPerMM, accuracy: 1e-6)
        XCTAssertTrue(CGRect(origin: .zero, size: size).contains(full))
    }

    func testRenderPictureIncludesBleedOnlyWhenAsked() {
        let item = PrintItem(image: TestImages.solid(width: 1200, height: 800), format: .photo4x6)
        let screen = PrintRenderer.renderPicture(item, options: RenderOptions(printBrightness: 0, dpi: 100))
        XCTAssertEqual(screen.width, 400)
        XCTAssertEqual(screen.height, 600)
        let print = PrintRenderer.renderPicture(item, options: RenderOptions(printBrightness: 0, dpi: 100,
                                                                             bleed: RenderOptions.printBleed))
        XCTAssertEqual(print.width, 406)
        XCTAssertEqual(print.height, 606)
    }

    func testPictureBleedsPastCutLineOnPrintedSheet() throws {
        let item = PrintItem(image: TestImages.solid(width: 600, height: 400, gray: 0.1), format: .photo4x6)
        let pages = Paginator.pages(for: [item])
        let data = PDFComposer.pdf(pages: pages, options: RenderOptions(printBrightness: 0))
        let img = try rasterize(data, paper: .letter)
        let slot = pages[0].layout.slots[0].rect
        // 0.4 mm outside the left edge: picture, not paper.
        let p = TestImages.pixel(img, x: Int((slot.minX - 0.4) * 10), y: Int(slot.midY * 10))
        XCTAssertLessThan(p.r, 80)
        // Just inside the top-left corner: square corner, no border.
        let c = TestImages.pixel(img, x: Int((slot.minX + 0.2) * 10), y: Int((slot.minY + 0.2) * 10))
        XCTAssertLessThan(c.r, 80)
        // 2 mm outside is bare paper.
        let q = TestImages.pixel(img, x: Int((slot.minX - 2) * 10), y: Int(slot.midY * 10))
        XCTAssertEqual(q.b, 255)
    }

    func testA4SheetIsA4() throws {
        let item = PrintItem(image: TestImages.solid(width: 600, height: 400), format: .photo5x7)
        let data = PDFComposer.pdf(pages: Paginator.pages(for: [item], paper: .a4), options: RenderOptions())
        let doc = try XCTUnwrap(CGPDFDocument(CGDataProvider(data: data as CFData)!))
        let box = try XCTUnwrap(doc.page(at: 1)).getBoxRect(.mediaBox)
        XCTAssertEqual(box.width, MM.toPoints(210), accuracy: 0.01)
        XCTAssertEqual(box.height, MM.toPoints(297), accuracy: 0.01)
    }

    /// Page 1 of a PDF at 10 px/mm, top-left origin.
    private func rasterize(_ data: Data, paper: Paper) throws -> CGImage {
        let doc = try XCTUnwrap(CGPDFDocument(CGDataProvider(data: data as CFData)!))
        let page = try XCTUnwrap(doc.page(at: 1))
        let ppm = 10.0
        let ctx = CGContext(data: nil, width: Int(paper.width * ppm), height: Int(paper.height * ppm), bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
        ctx.scaleBy(x: ppm / MM.pointsPerMM, y: ppm / MM.pointsPerMM)
        ctx.drawPDFPage(page)
        return ctx.makeImage()!
    }
}

@MainActor
final class PhotoPrintSessionTests: XCTestCase {
    let wide = TestImages.solid(width: 40, height: 30)
    let tall = TestImages.solid(width: 30, height: 40)

    func testAddPicksOrientationFromPhoto() {
        let s = Session()
        s.defaultFormat = .photo4x6
        s.add([wide, tall])
        XCTAssertTrue(s.items[0].isLandscape)
        XCTAssertFalse(s.items[1].isLandscape)
    }

    func testSetFormatToPhotoPrintMatchesPhoto() {
        let s = Session()
        s.add([wide])
        s.updateCrop(Crop(zoom: 2), for: s.items[0].id)
        s.setFormat(.photo5x7)
        XCTAssertTrue(s.items[0].isLandscape)
        XCTAssertEqual(s.items[0].crop, Crop())
    }

    func testSetLandscapeResetsCropKeepsTurns() {
        let s = Session()
        s.defaultFormat = .photo4x6
        s.add([wide])
        s.updateCrop(Crop(zoom: 2, quarterTurns: 2), for: s.items[0].id)
        s.setLandscape(false)
        XCTAssertFalse(s.items[0].isLandscape)
        XCTAssertEqual(s.items[0].crop, Crop(quarterTurns: 2))
    }

    func testRotateFollowsPhotoShape() {
        let s = Session()
        s.defaultFormat = .photo4x6
        s.add([wide])
        let id = s.items[0].id
        s.updateCrop(Crop(zoom: 3), for: id)
        s.rotate(id)
        XCTAssertEqual(s.items[0].crop, Crop(quarterTurns: 1))
        XCTAssertFalse(s.items[0].isLandscape)
        s.rotate(id)
        XCTAssertTrue(s.items[0].isLandscape)
    }

    func testMatchOrientationToPhotos() {
        let s = Session()
        s.defaultFormat = .photo4x6
        s.add([wide, tall])
        s.selection = Set(s.items.map(\.id))
        s.setLandscape(true)
        XCTAssertTrue(s.items[1].isLandscape)
        s.matchOrientationToPhotos()
        XCTAssertTrue(s.items[0].isLandscape)
        XCTAssertFalse(s.items[1].isLandscape)
    }

    func testOrientationIsSaved() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let item = PrintItem(image: TestImages.solid(width: 300, height: 200), format: .photo4x6, landscape: true)
        try SessionStore.save([item], to: dir)
        let loaded = SessionStore.load(from: dir)
        XCTAssertEqual(loaded.first?.format, .photo4x6)
        XCTAssertEqual(loaded.first?.landscape, true)
    }
}
