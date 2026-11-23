import CoreGraphics
import Foundation

public struct RenderOptions: Sendable, Equatable {
    /// Exposure correction for the printer, in EV. Use 0 for on-screen previews.
    public var printBrightness: Double
    public var paperTexture: Bool
    public var cornerGuides: Bool
    public var dpi: Double
    /// How far (mm) the border colour extends past the card edge, so a hand cut slightly
    /// outside the edge doesn't leave a white sliver. 0 for on-screen cards.
    public var bleed: Double

    /// Bleed used on printed sheets. Stays clear of crop marks (1 mm from the card).
    public static let printBleed: Double = 0.75

    public init(printBrightness: Double = 0.25, paperTexture: Bool = false, cornerGuides: Bool = true,
                dpi: Double = 300, bleed: Double = 0) {
        self.printBrightness = printBrightness
        self.paperTexture = paperTexture
        self.cornerGuides = cornerGuides
        self.dpi = dpi
        self.bleed = bleed
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
    /// How strongly the look is applied, 0…1.
    public var lookStrength: Double = PrintItem.defaultLookStrength
    public var copies: Int
    /// Photo prints only: print landscape instead of portrait. Ignored for instant film,
    /// whose orientation is fixed.
    public var landscape: Bool

    public static let defaultLookStrength: Double = 0.8

    public init(id: UUID = UUID(), image: CGImage, format: FilmFormat, crop: Crop = Crop(), look: FilmLook = .none,
                copies: Int = 1, landscape: Bool = false) {
        self.id = id
        self.image = image
        self.format = format
        self.crop = crop
        self.look = look
        self.copies = copies
        self.landscape = landscape
    }

    /// True when this prints as a landscape photo print. Never for instant film or square prints.
    public var isLandscape: Bool { format.hasOrientation && landscape }

    /// The card as it is printed: the format's spec, turned for landscape photo prints.
    public var spec: FrameSpec { isLandscape ? format.spec.turned : format.spec }

    /// True when the photo, after its quarter turns, is wider than tall.
    public var photoIsLandscape: Bool {
        let w = image.width, h = image.height
        return crop.quarterTurns % 2 == 0 ? w > h : h > w
    }
}

public enum PrintRenderer {
    /// The cropped, looked picture at `options.dpi` for the format's picture window.
    /// For frameless prints the picture also covers `pictureBleed(for:options:)` on every side.
    public static func renderPicture(_ item: PrintItem, options: RenderOptions) -> CGImage {
        let spec = item.spec
        let bleed = pictureBleed(for: spec, options: options)
        let pxW = max(1, Int(((spec.pictureRect.width + 2 * bleed) / 25.4 * options.dpi).rounded()))
        let pxH = max(1, Int(((spec.pictureRect.height + 2 * bleed) / 25.4 * options.dpi).rounded()))

        let rotated = ImageOps.rotated(item.image, quarterTurns: item.crop.quarterTurns)
        let size = CGSize(width: rotated.width, height: rotated.height)
        let src = sourceRect(crop: item.crop, imageSize: size, spec: spec, bleed: bleed).integral
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

        return LookProcessor.apply(item.look, strength: item.lookStrength, printBrightness: options.printBrightness, to: opaque)
    }

    /// How far (mm) the picture itself extends past the card edge: the print bleed for
    /// frameless prints (never more than the crop allows for), 0 for framed cards.
    public static func pictureBleed(for spec: FrameSpec, options: RenderOptions) -> Double {
        min(max(options.bleed, 0), spec.pictureBleed)
    }

    /// The pixel rect of the (rotated) photo shown in the picture window plus `bleed` mm on
    /// every side. The crop always covers the full `spec.pictureBleed`, so the area inside the
    /// cut line is the same whether or not bleed is drawn.
    public static func sourceRect(crop: Crop, imageSize: CGSize, spec: FrameSpec, bleed: Double) -> CGRect {
        let outer = crop.sourceRect(imageSize: imageSize, targetAspect: spec.cropAspect)
        let full = spec.pictureBleed
        guard full > 0, outer.width > 0 else { return outer }
        let pixelsPerMM = Double(outer.width) / (spec.pictureRect.width + 2 * full)
        let inset = (full - min(max(bleed, 0), full)) * pixelsPerMM
        return outer.insetBy(dx: inset, dy: inset)
    }

    /// Draws one card. `ctx` uses PDF-style points with y up; `cardRectPt` is the card's
    /// footprint (already swapped when `rotated`). A rotated card is turned 90° clockwise,
    /// which puts the thick bottom strip on the left.
    public static func drawCard(
        _ item: PrintItem, picture: CGImage, in ctx: CGContext,
        cardRectPt: CGRect, rotated: Bool, options: RenderOptions
    ) {
        let spec = item.spec
        let w = MM.toPoints(spec.cardWidth), h = MM.toPoints(spec.cardHeight)

        ctx.saveGState()
        ctx.translateBy(x: cardRectPt.midX, y: cardRectPt.midY)
        if rotated { ctx.rotate(by: -.pi / 2) }

        // Local coords: upright card centred on the origin, y up.
        let card = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)

        if spec.isFrameless {
            // Standard photo print: the picture is the whole card, plus its bleed. Square corners.
            let b = MM.toPoints(pictureBleed(for: spec, options: options))
            let area = card.insetBy(dx: -b, dy: -b)
            ctx.saveGState()
            ctx.clip(to: area)
            ctx.interpolationQuality = .high
            ctx.draw(picture, in: area)
            ctx.restoreGState()
            ctx.restoreGState()
            return
        }

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

        // Border, extended by the bleed. With rounding guides off the card is cut square,
        // so the fill is square too (no white nicks at the corners).
        let b = MM.toPoints(options.bleed)
        let fillRect = card.insetBy(dx: -b, dy: -b)
        if options.cornerGuides {
            ctx.addPath(CGPath(roundedRect: fillRect, cornerWidth: r + b, cornerHeight: r + b, transform: nil))
        } else {
            ctx.addRect(fillRect)
        }
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
        let spec = item.spec
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
