import CoreGraphics
import CoreText
import Foundation

/// Builds print-ready PDFs at exact physical size.
public enum PDFComposer {
    public static func pdf(pages: [Page], options: RenderOptions) -> Data {
        var options = options
        options.bleed = RenderOptions.printBleed
        let paper = pages.first?.layout.paper ?? .letter
        return makePDF(paper: paper) { ctx in
            var pictures: [UUID: CGImage] = [:]
            for page in pages {
                ctx.beginPDFPage(nil)
                for (slot, item) in zip(page.layout.slots, page.items) {
                    guard let item else { continue }
                    let picture = pictures[item.id] ?? PrintRenderer.renderPicture(item, options: options)
                    pictures[item.id] = picture
                    PrintRenderer.drawCard(item, picture: picture, in: ctx,
                                           cardRectPt: pointRect(slot.rect, paper: page.layout.paper),
                                           rotated: slot.rotated, options: options)
                }
                drawTicks(page.layout.ticks, in: ctx, paper: page.layout.paper)
                ctx.endPDFPage()
            }
        }
    }

    /// One page with an empty Instax Mini frame and a 50 mm ruler, for checking that the
    /// printer prints at true size.
    public static func sizeTestPDF(paper: Paper = .letter) -> Data {
        makePDF(paper: paper) { ctx in
            ctx.beginPDFPage(nil)
            let layout = SheetLayout.make(format: .instaxMini, paper: paper)
            let slot = layout.slots[0]
            let blank = TestPattern.lightGrey
            let item = PrintItem(image: blank, format: .instaxMini)
            PrintRenderer.drawCard(item, picture: blank, in: ctx,
                                   cardRectPt: pointRect(slot.rect, paper: paper),
                                   rotated: false, options: RenderOptions(printBrightness: 0))
            // Crop marks belonging to the first card only.
            let near = slot.rect.insetBy(dx: -(SheetLayout.tickOffset + SheetLayout.tickLength + 0.5),
                                         dy: -(SheetLayout.tickOffset + SheetLayout.tickLength + 0.5))
            drawTicks(layout.ticks.filter { near.contains($0.from) && near.contains($0.to) }, in: ctx, paper: paper)

            // Ruler.
            let (a, b) = rulerSegmentPt(paper: paper)
            ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
            ctx.setLineWidth(0.5)
            ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
            for i in 0...5 {
                let x = a.x + MM.toPoints(Double(i) * 10)
                let len = MM.toPoints(i % 5 == 0 ? 4 : 2.5)
                ctx.move(to: CGPoint(x: x, y: a.y)); ctx.addLine(to: CGPoint(x: x, y: a.y + len)); ctx.strokePath()
            }

            // L-shaped placement marks a fixed distance from the paper's top corners.
            let marks = sizeTestEdgeMarkCornersMM(paper: paper)
            let arm = 6.0
            ctx.setLineWidth(0.5)
            for (i, corner) in marks.enumerated() {
                let dx = i == 0 ? arm : -arm
                ctx.move(to: point(CGPoint(x: corner.x + dx, y: corner.y), paper: paper))
                ctx.addLine(to: point(corner, paper: paper))
                ctx.addLine(to: point(CGPoint(x: corner.x, y: corner.y + arm), paper: paper))
                ctx.strokePath()
            }

            let textOrigin = CGPoint(x: a.x, y: a.y - MM.toPoints(8))
            drawText("Instax Mini: 54 × 86 mm — lay a real print on top.", at: textOrigin, in: ctx)
            drawText("The ruler above should measure exactly 50 mm.",
                     at: CGPoint(x: textOrigin.x, y: textOrigin.y - 14), in: ctx)
            drawText("The two corner marks at the top of the page should each sit 15 mm from the paper's top and side edges.",
                     at: CGPoint(x: textOrigin.x, y: textOrigin.y - 28), in: ctx)
            drawText("If they don't, your printer is shifting or scaling the page — print at 100% scale.",
                     at: CGPoint(x: textOrigin.x, y: textOrigin.y - 42), in: ctx)
            ctx.endPDFPage()
        }
    }

    /// End points of the size-test ruler in PDF points (y up). Exactly 50 mm long.
    public static func rulerSegmentPt(paper: Paper = .letter) -> (CGPoint, CGPoint) {
        let slot = SheetLayout.make(format: .instaxMini, paper: paper).slots[0].rect
        let yMM = slot.maxY + 15
        let y = MM.toPoints(paper.height - yMM)
        let x = MM.toPoints(slot.minX)
        return (CGPoint(x: x, y: y), CGPoint(x: x + MM.toPoints(50), y: y))
    }

    /// Corners of the L-shaped placement marks on the size test page (sheet mm, y down).
    public static func sizeTestEdgeMarkCornersMM(paper: Paper) -> [CGPoint] {
        [CGPoint(x: edgeMarkInset, y: edgeMarkInset), CGPoint(x: paper.width - edgeMarkInset, y: edgeMarkInset)]
    }

    static let edgeMarkInset: Double = 15

    /// Converts a printer's imageable area (points, y up, as `NSPrintInfo.imageablePageBounds`
    /// reports it) into sheet millimetres (y down) for `SheetLayout.isInside`.
    public static func imageableMM(fromPoints r: CGRect, paper: Paper) -> CGRect {
        let k = 1 / MM.pointsPerMM
        return CGRect(x: r.minX * k, y: paper.height - r.maxY * k, width: r.width * k, height: r.height * k)
    }

    // MARK: - Helpers

    /// Converts a sheet rect (mm, y down) into PDF points (y up).
    static func pointRect(_ r: CGRect, paper: Paper) -> CGRect {
        CGRect(x: MM.toPoints(r.minX), y: MM.toPoints(paper.height - r.maxY),
               width: MM.toPoints(r.width), height: MM.toPoints(r.height))
    }

    static func point(_ p: CGPoint, paper: Paper) -> CGPoint {
        CGPoint(x: MM.toPoints(p.x), y: MM.toPoints(paper.height - p.y))
    }

    private static func drawTicks(_ ticks: [Tick], in ctx: CGContext, paper: Paper) {
        ctx.saveGState()
        ctx.setStrokeColor(FrameStyle.tickColor)
        ctx.setLineWidth(FrameStyle.hairline)
        for t in ticks {
            ctx.move(to: point(t.from, paper: paper))
            ctx.addLine(to: point(t.to, paper: paper))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawText(_ text: String, at origin: CGPoint, in ctx: CGContext) {
        let font = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.2, alpha: 1),
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        ctx.saveGState()
        ctx.textPosition = origin
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    private static func makePDF(paper: Paper, draw: (CGContext) -> Void) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: MM.toPoints(paper.width), height: MM.toPoints(paper.height))
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, [
                  kCGPDFContextCreator: "Faux Film",
              ] as CFDictionary)
        else { return Data() }
        draw(ctx)
        ctx.closePDF()
        return data as Data
    }
}

private enum TestPattern {
    static var lightGrey: CGImage {
        let ctx = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(srgbRed: 0.85, green: 0.85, blue: 0.85, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        return ctx.makeImage()!
    }
}
