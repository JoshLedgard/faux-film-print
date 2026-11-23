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

    /// True for standard photo prints: the picture runs to the card edge.
    public var isFrameless: Bool { side == 0 && top == 0 && bottom == 0 }

    /// How far (mm) the crop reaches past the picture edge on every side. Frameless prints
    /// bleed the picture itself past the cut line, so the crop covers that bleed too and the
    /// trimmed print shows exactly what the crop editor shows.
    public var pictureBleed: Double { isFrameless ? RenderOptions.printBleed : 0 }

    /// Width / height of the image area the crop covers, bleed included.
    public var cropAspect: Double {
        (pictureRect.width + 2 * pictureBleed) / (pictureRect.height + 2 * pictureBleed)
    }

    /// The same card turned a quarter (width and height swapped). Only meaningful for
    /// frameless prints, whose borders are all zero.
    public var turned: FrameSpec {
        FrameSpec(cardWidth: cardHeight, cardHeight: cardWidth, side: side, top: bottom, bottom: top,
                  cornerRadius: cornerRadius, windowCornerRadius: windowCornerRadius)
    }

    /// A standard print with no border and square corners.
    static func frameless(width: Double, height: Double) -> FrameSpec {
        FrameSpec(cardWidth: width, cardHeight: height, side: 0, top: 0, bottom: 0, cornerRadius: 0, windowCornerRadius: 0)
    }
}

/// Instant film with a printed frame, or a standard frameless photo print.
public enum FormatFamily: String, CaseIterable, Sendable {
    case instantFilm
    case photoPrint

    public var displayName: String {
        switch self {
        case .instantFilm: "Instant Film"
        case .photoPrint: "Photo Prints"
        }
    }
}

public enum FilmFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case instaxMini
    case instaxSquare
    case instaxWide
    case polaroidSquare
    // Standard photo prints (frameless). New cases go at the end: saved sessions store the raw value.
    case photoWallet
    case photo3x5
    case photo4x6
    case photo5x7
    case photo8x10
    case photo4x4

    public var id: String { rawValue }

    public var family: FormatFamily {
        switch self {
        case .instaxMini, .instaxSquare, .instaxWide, .polaroidSquare: .instantFilm
        case .photoWallet, .photo3x5, .photo4x6, .photo5x7, .photo8x10, .photo4x4: .photoPrint
        }
    }

    public var isPhotoPrint: Bool { family == .photoPrint }

    /// True for photo prints that can be printed portrait or landscape (all but square).
    public var hasOrientation: Bool { isPhotoPrint && spec.cardWidth != spec.cardHeight }

    /// Formats in one family, in menu order.
    public static func formats(in family: FormatFamily) -> [FilmFormat] {
        allCases.filter { $0.family == family }
    }

    public var displayName: String {
        switch self {
        case .instaxMini: "Instax Mini"
        case .instaxSquare: "Instax Square"
        case .instaxWide: "Instax Wide"
        case .polaroidSquare: "Polaroid Square"
        case .photoWallet: "Wallet 2.5 × 3.5 in"
        case .photo3x5: "3.5 × 5 in"
        case .photo4x6: "4 × 6 in"
        case .photo5x7: "5 × 7 in"
        case .photo8x10: "8 × 10 in"
        case .photo4x4: "Square 4 × 4 in"
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
        // Photo prints are stored portrait; a landscape print is the same card turned.
        case .photoWallet: .frameless(width: 63.5, height: 88.9)
        case .photo3x5: .frameless(width: 88.9, height: 127)
        case .photo4x6: .frameless(width: 101.6, height: 152.4)
        case .photo5x7: .frameless(width: 127, height: 177.8)
        case .photo8x10: .frameless(width: 203.2, height: 254)
        case .photo4x4: .frameless(width: 101.6, height: 101.6)
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

    /// ISO A4, 210 × 297 mm, portrait.
    public static let a4 = Paper(width: 210, height: 297)
}

/// The sheet sizes the user can print on.
public enum PaperSize: String, CaseIterable, Sendable, Identifiable {
    case letter
    case a4

    public var id: String { rawValue }

    public var paper: Paper {
        switch self {
        case .letter: .letter
        case .a4: .a4
        }
    }

    public var displayName: String {
        switch self {
        case .letter: "US Letter"
        case .a4: "A4"
        }
    }
}
