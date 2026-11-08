import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

public enum FilmLook: String, CaseIterable, Codable, Sendable, Identifiable {
    case none
    case instant
    case faded

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: "None"
        case .instant: "Instant"
        case .faded: "Faded"
        }
    }
}

/// Applies film looks and the print-brightness correction to the picture only.
public enum LookProcessor {
    private static let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    ])

    /// - Parameter printBrightness: exposure correction in EV (−1...1); 0 leaves the image alone.
    public static func apply(_ look: FilmLook, printBrightness: Double, to image: CGImage) -> CGImage {
        if look == .none && printBrightness == 0 { return image }

        let input = CIImage(cgImage: image)
        let extent = input.extent
        var output = input

        if printBrightness != 0 {
            let f = CIFilter.exposureAdjust()
            f.inputImage = output
            f.ev = Float(max(-1, min(1, printBrightness)))
            output = f.outputImage ?? output
        }

        switch look {
        case .none:
            break
        case .instant:
            output = toneCurve(output, [(0, 0.06), (0.25, 0.27), (0.5, 0.52), (0.75, 0.76), (1, 0.97)])
            output = colorControls(output, saturation: 1.04, contrast: 0.97)
            output = warmth(output, target: 6000)
            output = vignette(output, intensity: 0.35, extent: extent)
        case .faded:
            output = toneCurve(output, [(0, 0.13), (0.25, 0.31), (0.5, 0.52), (0.75, 0.73), (1, 0.93)])
            output = colorControls(output, saturation: 0.85, contrast: 0.92)
            output = warmth(output, target: 5600)
            output = vignette(output, intensity: 0.45, extent: extent)
        }

        return context.createCGImage(
            output.cropped(to: extent), from: extent,
            format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ) ?? image
    }

    private static func toneCurve(_ image: CIImage, _ p: [(CGFloat, CGFloat)]) -> CIImage {
        let f = CIFilter.toneCurve()
        f.inputImage = image
        f.point0 = CGPoint(x: p[0].0, y: p[0].1)
        f.point1 = CGPoint(x: p[1].0, y: p[1].1)
        f.point2 = CGPoint(x: p[2].0, y: p[2].1)
        f.point3 = CGPoint(x: p[3].0, y: p[3].1)
        f.point4 = CGPoint(x: p[4].0, y: p[4].1)
        return f.outputImage ?? image
    }

    private static func colorControls(_ image: CIImage, saturation: Float, contrast: Float) -> CIImage {
        let f = CIFilter.colorControls()
        f.inputImage = image
        f.saturation = saturation
        f.contrast = contrast
        return f.outputImage ?? image
    }

    /// Warms the image by pretending the scene was lit at 6500 K and re-targeting it.
    private static func warmth(_ image: CIImage, target: CGFloat) -> CIImage {
        let f = CIFilter.temperatureAndTint()
        f.inputImage = image
        f.neutral = CIVector(x: 6500, y: 0)
        f.targetNeutral = CIVector(x: target, y: 0)
        return f.outputImage ?? image
    }

    private static func vignette(_ image: CIImage, intensity: Float, extent: CGRect) -> CIImage {
        let f = CIFilter.vignetteEffect()
        f.inputImage = image
        f.center = CGPoint(x: extent.midX, y: extent.midY)
        f.radius = Float(hypot(extent.width, extent.height) / 2)
        f.intensity = intensity
        f.falloff = 0.6
        return (f.outputImage ?? image).cropped(to: extent)
    }
}
