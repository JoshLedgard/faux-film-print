import CoreGraphics
import Foundation

public struct RenderOptions: Sendable, Equatable {
    /// Exposure correction for the printer, in EV. Use 0 for on-screen previews.
    public var printBrightness: Double
    public var paperTexture: Bool
    public var cornerGuides: Bool
    public var dpi: Double

    public init(printBrightness: Double = 0.25, paperTexture: Bool = false, cornerGuides: Bool = true, dpi: Double = 300) {
        self.printBrightness = printBrightness
        self.paperTexture = paperTexture
        self.cornerGuides = cornerGuides
        self.dpi = dpi
    }
}

public enum FrameStyle {
    /// Warm off-white of real instant film borders (#F6F4EE).
    public static var borderColor: CGColor { CGColor(srgbRed: 0xF6 / 255, green: 0xF4 / 255, blue: 0xEE / 255, alpha: 1) }
    /// Corner rounding guides.
    public static var guideColor: CGColor { CGColor(srgbRed: 0.78, green: 0.78, blue: 0.78, alpha: 1) }
    /// Crop marks.
    public static var tickColor: CGColor { CGColor(srgbRed: 0.35, green: 0.35, blue: 0.35, alpha: 1) }
    /// Hairline width in points.
    public static let hairline: CGFloat = 0.25
}

/// One photo as it will be printed.
public struct PrintItem: Identifiable, Sendable {
    public let id: UUID
    /// Upright, decoded photo.
    public var image: CGImage
    public var format: FilmFormat
    public var crop: Crop
    public var look: FilmLook
    public var copies: Int

    public init(id: UUID = UUID(), image: CGImage, format: FilmFormat, crop: Crop = Crop(), look: FilmLook = .none, copies: Int = 1) {
        self.id = id
        self.image = image
        self.format = format
        self.crop = crop
        self.look = look
        self.copies = copies
    }
}

public enum PrintRenderer {
    /// The cropped, looked picture at `options.dpi` for the format's picture window.
    public static func renderPicture(_ item: PrintItem, options: RenderOptions) -> CGImage {
        let spec = item.format.spec
        let pxW = max(1, Int((spec.pictureRect.width / 25.4 * options.dpi).rounded()))
        let pxH = max(1, Int((spec.pictureRect.height / 25.4 * options.dpi).rounded()))

        let rotated = ImageOps.rotated(item.image, quarterTurns: item.crop.quarterTurns)
        let size = CGSize(width: rotated.width, height: rotated.height)
        let src = item.crop.sourceRect(imageSize: size, targetAspect: spec.pictureAspect).integral
            .intersection(CGRect(origin: .zero, size: size))
        let cropped = rotated.cropping(to: src) ?? rotated

        let ctx = CGContext(
            data: nil, width: pxW, height: pxH, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        let full = CGRect(x: 0, y: 0, width: pxW, height: pxH)
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(full)
        ctx.interpolationQuality = .high
        ctx.draw(cropped, in: full)
        let opaque = ctx.makeImage()!

        return LookProcessor.apply(item.look, printBrightness: options.printBrightness, to: opaque)
    }

    /// Draws one card. `ctx` uses PDF-style points with y up; `cardRectPt` is the card's
    /// footprint (already swapped when `rotated`). A rotated card is turned 90° clockwise,
    /// which puts the thick bottom strip on the left.
    public static func drawCard(
        _ item: PrintItem, picture: CGImage, in ctx: CGContext,
        cardRectPt: CGRect, rotated: Bool, options: RenderOptions
    ) {
        let spec = item.format.spec
        let w = MM.toPoints(spec.cardWidth), h = MM.toPoints(spec.cardHeight)

        ctx.saveGState()
        ctx.translateBy(x: cardRectPt.midX, y: cardRectPt.midY)
        if rotated { ctx.rotate(by: -.pi / 2) }

        // Local coords: upright card centred on the origin, y up.
        let card = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
        let pr = spec.pictureRect
        let window = CGRect(
            x: card.minX + MM.toPoints(pr.minX),
            y: card.maxY - MM.toPoints(pr.maxY),
            width: MM.toPoints(pr.width),
            height: MM.toPoints(pr.height)
        )
        let r = MM.toPoints(spec.cornerRadius)
        let cardPath = CGPath(roundedRect: card, cornerWidth: r, cornerHeight: r, transform: nil)
        let wr = MM.toPoints(spec.windowCornerRadius)
        let windowPath = CGPath(roundedRect: window, cornerWidth: wr, cornerHeight: wr, transform: nil)

        // Border.
        ctx.addPath(cardPath)
        ctx.setFillColor(FrameStyle.borderColor)
        ctx.fillPath()

        if options.paperTexture {
            ctx.saveGState()
            ctx.addPath(cardPath)
            ctx.addPath(windowPath)
            ctx.clip(using: .evenOdd)
            ctx.setAlpha(0.05)
            ctx.draw(noiseTile, in: CGRect(x: card.minX, y: card.minY, width: 36, height: 36), byTiling: true)
            ctx.restoreGState()
        }

        // Picture.
        ctx.saveGState()
        ctx.addPath(windowPath)
        ctx.clip()
        ctx.interpolationQuality = .high
        ctx.draw(picture, in: window)
        ctx.restoreGState()

        if options.cornerGuides {
            ctx.setStrokeColor(FrameStyle.guideColor)
            ctx.setLineWidth(FrameStyle.hairline)
            let corners: [(CGPoint, CGFloat)] = [
                (CGPoint(x: card.minX + r, y: card.maxY - r), .pi / 2),        // top-left
                (CGPoint(x: card.maxX - r, y: card.maxY - r), 0),              // top-right
                (CGPoint(x: card.maxX - r, y: card.minY + r), -.pi / 2),       // bottom-right
                (CGPoint(x: card.minX + r, y: card.minY + r), .pi),            // bottom-left
            ]
            for (center, start) in corners {
                ctx.addArc(center: center, radius: r, startAngle: start, endAngle: start + .pi / 2, clockwise: false)
                ctx.strokePath()
            }
        }

        ctx.restoreGState()
    }

    /// The whole card as a bitmap, for on-screen previews.
    public static func cardImage(_ item: PrintItem, options: RenderOptions, pixelsPerMM: Double) -> CGImage {
        let spec = item.format.spec
        let pxW = max(1, Int((spec.cardWidth * pixelsPerMM).rounded()))
        let pxH = max(1, Int((spec.cardHeight * pixelsPerMM).rounded()))
        var pictureOptions = options
        pictureOptions.dpi = pixelsPerMM * 25.4
        let picture = renderPicture(item, options: pictureOptions)

        let ctx = CGContext(
            data: nil, width: pxW, height: pxH, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let scale = pixelsPerMM / MM.pointsPerMM
        ctx.scaleBy(x: scale, y: scale)
        drawCard(item, picture: picture, in: ctx,
                 cardRectPt: CGRect(x: 0, y: 0, width: MM.toPoints(spec.cardWidth), height: MM.toPoints(spec.cardHeight)),
                 rotated: false, options: options)
        return ctx.makeImage()!
    }

    /// Faint grain for the paper texture option.
    nonisolated(unsafe) private static let noiseTile: CGImage = {
        let size = 128
        var pixels = [UInt8](repeating: 0, count: size * size)
        var seed: UInt32 = 0x9E37_79B9
        for i in pixels.indices {
            seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
            pixels[i] = UInt8(truncatingIfNeeded: seed)
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(
            width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }()
}
