import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

public enum FilmLook: String, CaseIterable, Codable, Sendable, Identifiable {
    case none
    /// Instax-style: punchy colour, cool shadows, soft highlight roll-off, fine grain.
    case instant
    /// Polaroid 600 / i-Type-style: soft contrast, warm pink highlights, green-teal shadows.
    case polaroid
    /// Old or expired film: low contrast, lifted blacks, sepia warmth.
    case faded

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: "None"
        case .instant: "Instax"
        case .polaroid: "Polaroid"
        case .faded: "Faded"
        }
    }
}

/// The ingredients of one film look. Values were tuned from published descriptions of the
/// films and emulation presets; they are a starting point to adjust against real prints.
struct LookRecipe {
    /// Amount of S-curve: 0 = linear, positive = more contrast, negative = flatter.
    var contrast: Double
    /// Darkest and brightest values the film reaches (instant film never prints pure black/white).
    var black: Double
    var white: Double
    /// Per-channel tint added in the shadows and highlights (r, g, b).
    var shadowTint: (Double, Double, Double)
    var highlightTint: (Double, Double, Double)
    /// Flat tint across all tones (r, g, b).
    var overallTint: (Double, Double, Double) = (0, 0, 0)
    var saturation: Double
    var vignette: Double
    /// Grain amplitude (0…1 of full scale).
    var grain: Double
    /// Lens softness, as a blur radius per 1000 px of image width.
    var softness: Double

    static func `for`(_ look: FilmLook) -> LookRecipe? {
        switch look {
        case .none:
            return nil
        case .instant:
            return LookRecipe(contrast: 0.35, black: 0.035, white: 0.965,
                              shadowTint: (-0.02, 0.006, 0.035), highlightTint: (0.015, 0.006, -0.02),
                              saturation: 1.12, vignette: 0.22, grain: 0.035, softness: 0.9)
        case .polaroid:
            return LookRecipe(contrast: 0.08, black: 0.08, white: 0.94,
                              shadowTint: (-0.01, 0.025, 0.02), highlightTint: (0.035, -0.005, -0.03),
                              saturation: 0.88, vignette: 0.38, grain: 0.05, softness: 1.4)
        case .faded:
            return LookRecipe(contrast: -0.12, black: 0.15, white: 0.9,
                              shadowTint: (0.0, 0.01, 0.01), highlightTint: (0.02, 0.005, -0.03),
                              overallTint: (0.03, 0.01, -0.04),
                              saturation: 0.7, vignette: 0.45, grain: 0.06, softness: 1.4)
        }
    }

    /// Per-channel output for input `x` (0…1).
    func curve(_ x: Double) -> (Double, Double, Double) {
        let smooth = x * x * (3 - 2 * x)
        let s = x + contrast * (smooth - x)
        let base = black + (white - black) * s
        let sh = (1 - x) * (1 - x), hi = x * x
        func ch(_ i: KeyPath<(Double, Double, Double), Double>) -> Double {
            min(1, max(0, base + shadowTint[keyPath: i] * sh + highlightTint[keyPath: i] * hi + overallTint[keyPath: i]))
        }
        return (ch(\.0), ch(\.1), ch(\.2))
    }
}

/// Applies film looks and the print-brightness correction to the picture only.
public enum LookProcessor {
    private static let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    ])

    /// - Parameters:
    ///   - strength: 0 = no look, 1 = full look. Print brightness applies either way.
    ///   - printBrightness: exposure correction in EV (−1...1); 0 leaves the image alone.
    public static func apply(_ look: FilmLook, strength: Double = 1, printBrightness: Double, to image: CGImage) -> CGImage {
        let recipe = LookRecipe.for(look)
        let amount = min(1, max(0, strength))
        if (recipe == nil || amount == 0) && printBrightness == 0 { return image }

        let input = CIImage(cgImage: image)
        let extent = input.extent
        var exposed = input
        if printBrightness != 0 {
            let f = CIFilter.exposureAdjust()
            f.inputImage = input
            f.ev = Float(max(-1, min(1, printBrightness)))
            exposed = f.outputImage ?? input
        }

        var output = exposed
        if let recipe, amount > 0 {
            var looked = curves(exposed, recipe)
            looked = colorControls(looked, saturation: recipe.saturation)
            looked = soften(looked, recipe.softness * Double(extent.width) / 1000, extent: extent)
            looked = vignette(looked, intensity: Float(recipe.vignette), extent: extent)
            looked = grain(looked, amount: recipe.grain, extent: extent)
            output = amount >= 1 ? looked : dissolve(from: exposed, to: looked, amount: amount)
        }

        return context.createCGImage(
            output.cropped(to: extent), from: extent,
            format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ) ?? image
    }

    private static func curves(_ image: CIImage, _ recipe: LookRecipe) -> CIImage {
        let n = 64
        var table: [Float] = []
        table.reserveCapacity(n * 3)
        for i in 0..<n {
            let (r, g, b) = recipe.curve(Double(i) / Double(n - 1))
            table += [Float(r), Float(g), Float(b)]
        }
        let f = CIFilter.colorCurves()
        f.inputImage = image
        f.curvesData = table.withUnsafeBufferPointer { Data(buffer: $0) }
        f.curvesDomain = CIVector(x: 0, y: 1)
        f.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        return f.outputImage ?? image
    }

    private static func colorControls(_ image: CIImage, saturation: Double) -> CIImage {
        let f = CIFilter.colorControls()
        f.inputImage = image
        f.saturation = Float(saturation)
        return f.outputImage ?? image
    }

    /// Instant cameras have small plastic lenses: a hint of softness reads as authentic.
    private static func soften(_ image: CIImage, _ radius: Double, extent: CGRect) -> CIImage {
        guard radius > 0.05 else { return image }
        let f = CIFilter.gaussianBlur()
        f.inputImage = image.clampedToExtent()
        f.radius = Float(radius)
        return (f.outputImage ?? image).cropped(to: extent)
    }

    private static func vignette(_ image: CIImage, intensity: Float, extent: CGRect) -> CIImage {
        guard intensity > 0 else { return image }
        let f = CIFilter.vignetteEffect()
        f.inputImage = image
        f.center = CGPoint(x: extent.midX, y: extent.midY)
        f.radius = Float(hypot(extent.width, extent.height) / 2)
        f.intensity = intensity
        f.falloff = 0.6
        return (f.outputImage ?? image).cropped(to: extent)
    }

    /// Fine monochrome grain: a neutral-grey noise layer soft-light blended over the picture,
    /// so overall brightness doesn't shift.
    private static func grain(_ image: CIImage, amount: Double, extent: CGRect) -> CIImage {
        guard amount > 0, let noise = CIFilter.randomGenerator().outputImage else { return image }
        let a = CGFloat(amount) * 1.4
        let mono = CIFilter.colorMatrix()
        mono.inputImage = noise.transformed(by: CGAffineTransform(scaleX: 1.5, y: 1.5))
        mono.rVector = CIVector(x: a, y: 0, z: 0, w: 0)
        mono.gVector = CIVector(x: a, y: 0, z: 0, w: 0)
        mono.bVector = CIVector(x: a, y: 0, z: 0, w: 0)
        mono.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        mono.biasVector = CIVector(x: 0.5 - a / 2, y: 0.5 - a / 2, z: 0.5 - a / 2, w: 1)
        // A touch of blur turns per-pixel sparkle into clumpy, film-like grain.
        let smooth = CIFilter.gaussianBlur()
        smooth.inputImage = mono.outputImage
        smooth.radius = 0.6
        guard let grainImage = smooth.outputImage?.cropped(to: extent) else { return image }
        let blend = CIFilter.softLightBlendMode()
        blend.inputImage = grainImage
        blend.backgroundImage = image
        return (blend.outputImage ?? image).cropped(to: extent)
    }

    private static func dissolve(from a: CIImage, to b: CIImage, amount: Double) -> CIImage {
        let f = CIFilter.dissolveTransition()
        f.inputImage = a
        f.targetImage = b
        f.time = Float(amount)
        return f.outputImage ?? b
    }
}
