import CoreGraphics

/// Millimetre helpers. All physical geometry in FauxFilmKit is in millimetres,
/// top-left origin, y down. Convert to PDF points only at draw time.
public enum MM {
    public static let pointsPerMM: Double = 72.0 / 25.4

    public static func toPoints(_ mm: Double) -> Double { mm * pointsPerMM }
}

/// Physical description of one instant-film card, in millimetres.
public struct FrameSpec: Sendable, Equatable {
    public let cardWidth: Double
    public let cardHeight: Double
    public let side: Double
    public let top: Double
    public let bottom: Double
    /// Outer corner radius of the card.
    public let cornerRadius: Double
    /// Corner radius of the picture window.
    public let windowCornerRadius: Double

    public var cardSize: CGSize { CGSize(width: cardWidth, height: cardHeight) }

    /// Picture window in card millimetres (origin top-left of the card, y down).
    public var pictureRect: CGRect {
        CGRect(x: side, y: top, width: cardWidth - 2 * side, height: cardHeight - top - bottom)
    }

    /// Width / height of the picture window.
    public var pictureAspect: Double { pictureRect.width / pictureRect.height }
}

public enum FilmFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case instaxMini
    case instaxSquare
    case instaxWide
    case polaroidSquare

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .instaxMini: "Instax Mini"
        case .instaxSquare: "Instax Square"
        case .instaxWide: "Instax Wide"
        case .polaroidSquare: "Polaroid Square"
        }
    }

    /// Border measurements. Instax Mini matters most; tweak here after a test print.
    public var spec: FrameSpec {
        switch self {
        case .instaxMini:
            FrameSpec(cardWidth: 54, cardHeight: 86, side: 4, top: 6, bottom: 18, cornerRadius: 3, windowCornerRadius: 0.5)
        case .instaxSquare:
            FrameSpec(cardWidth: 72, cardHeight: 86, side: 5, top: 7, bottom: 17, cornerRadius: 3, windowCornerRadius: 0.5)
        case .instaxWide:
            FrameSpec(cardWidth: 108, cardHeight: 86, side: 4.5, top: 6, bottom: 18, cornerRadius: 3, windowCornerRadius: 0.5)
        case .polaroidSquare:
            FrameSpec(cardWidth: 88, cardHeight: 107, side: 4.5, top: 6, bottom: 22, cornerRadius: 1, windowCornerRadius: 0.5)
        }
    }
}

/// A sheet of paper, in millimetres.
public struct Paper: Sendable, Equatable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    /// US Letter, 8.5 × 11 in, portrait.
    public static let letter = Paper(width: 215.9, height: 279.4)
}
