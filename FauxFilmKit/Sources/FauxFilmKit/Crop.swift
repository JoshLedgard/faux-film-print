import CoreGraphics

/// How a photo sits inside a picture window.
public struct Crop: Equatable, Sendable, Codable {
    public static let zoomRange: ClosedRange<Double> = 1...8

    /// 1 = the largest crop that fills the window; higher zooms in.
    public var zoom: Double = 1
    /// Centre of the crop, in unit coordinates of the (rotated) image, y down.
    public var center = CGPoint(x: 0.5, y: 0.5)
    /// Clockwise quarter turns applied to the photo before cropping (0...3).
    public var quarterTurns = 0

    public init(zoom: Double = 1, center: CGPoint = CGPoint(x: 0.5, y: 0.5), quarterTurns: Int = 0) {
        self.zoom = zoom
        self.center = center
        self.quarterTurns = quarterTurns
    }

    /// The pixel rect (y down) of an image of `imageSize` (already rotated) that fills a
    /// window of `targetAspect` (width / height). Never extends past the image.
    public func sourceRect(imageSize: CGSize, targetAspect: Double) -> CGRect {
        let W = Double(imageSize.width), H = Double(imageSize.height)
        guard W > 0, H > 0, targetAspect > 0 else { return .zero }
        var w: Double, h: Double
        if W / H > targetAspect {
            h = H
            w = H * targetAspect
        } else {
            w = W
            h = W / targetAspect
        }
        let z = min(max(zoom, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        w /= z
        h /= z
        let x = min(max(Double(center.x) * W - w / 2, 0), W - w)
        let y = min(max(Double(center.y) * H - h / 2, 0), H - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// The same crop with `center` moved to where the clamped rect actually sits.
    public func clamped(imageSize: CGSize, targetAspect: Double) -> Crop {
        let r = sourceRect(imageSize: imageSize, targetAspect: targetAspect)
        guard imageSize.width > 0, imageSize.height > 0 else { return self }
        var copy = self
        copy.zoom = min(max(zoom, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        copy.center = CGPoint(x: r.midX / imageSize.width, y: r.midY / imageSize.height)
        return copy
    }
}
