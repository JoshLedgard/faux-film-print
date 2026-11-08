import CoreGraphics

/// One card position on a sheet.
public struct Slot: Equatable, Sendable {
    /// The card's footprint on the sheet, in mm (top-left origin, y down).
    public let rect: CGRect
    /// When true the card is turned 90° clockwise to fit more per sheet.
    public let rotated: Bool
}

/// A short crop-mark hairline, in sheet millimetres.
public struct Tick: Equatable, Sendable {
    public let from: CGPoint
    public let to: CGPoint
}

/// How cards of one format sit on a sheet of paper.
public struct SheetLayout: Sendable {
    public let format: FilmFormat
    public let paper: Paper
    public let columns: Int
    public let rows: Int
    /// Row-major.
    public let slots: [Slot]
    public let ticks: [Tick]

    /// Distance between a crop mark and the print it marks.
    public static let tickOffset: Double = 1
    /// Length of crop marks placed in margins.
    public static let tickLength: Double = 3

    public static func make(
        format: FilmFormat,
        paper: Paper = .letter,
        gap: Double = 4,
        margin: Double = 6,
        maxRows: Int? = nil
    ) -> SheetLayout {
        let card = format.spec.cardSize

        func fit(_ size: CGSize) -> (cols: Int, rows: Int) {
            let cols = Int(((paper.width - 2 * margin + gap) / (size.width + gap)).rounded(.down))
            var rows = Int(((paper.height - 2 * margin + gap) / (size.height + gap)).rounded(.down))
            if let maxRows { rows = min(rows, maxRows) }
            return (max(cols, 0), max(rows, 0))
        }

        let upright = fit(card)
        let turnedSize = CGSize(width: card.height, height: card.width)
        let turned = fit(turnedSize)
        let useTurned = turned.cols * turned.rows > upright.cols * upright.rows
        let (cols, rows) = useTurned ? turned : upright
        let size = useTurned ? turnedSize : card

        let gridWidth = Double(cols) * size.width + Double(max(cols - 1, 0)) * gap
        let gridHeight = Double(rows) * size.height + Double(max(rows - 1, 0)) * gap
        let left = (paper.width - gridWidth) / 2
        let top = (paper.height - gridHeight) / 2

        var slots: [Slot] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let rect = CGRect(
                    x: left + Double(c) * (size.width + gap),
                    y: top + Double(r) * (size.height + gap),
                    width: size.width,
                    height: size.height
                )
                slots.append(Slot(rect: rect, rotated: useTurned))
            }
        }

        let ticks = makeTicks(
            cols: cols, rows: rows, size: size, gap: gap, margin: margin,
            left: left, top: top, gridWidth: gridWidth, gridHeight: gridHeight, paper: paper
        )
        return SheetLayout(format: format, paper: paper, columns: cols, rows: rows, slots: slots, ticks: ticks)
    }

    /// Index of the slot containing `point` (sheet mm, y down), if any.
    public func slotIndex(at point: CGPoint) -> Int? {
        slots.firstIndex { $0.rect.contains(point) }
    }

    /// True when every card lies inside the printer's imageable area (mm, y down).
    public func isInside(_ imageable: CGRect) -> Bool {
        slots.allSatisfy { imageable.contains($0.rect) }
    }

    // MARK: - Crop marks

    private static func makeTicks(
        cols: Int, rows: Int, size: CGSize, gap: Double, margin: Double,
        left: Double, top: Double, gridWidth: Double, gridHeight: Double, paper: Paper
    ) -> [Tick] {
        guard cols > 0, rows > 0 else { return [] }
        let o = tickOffset
        let L = tickLength
        let right = left + gridWidth
        let bottom = top + gridHeight

        let columnEdges: [Double] = (0..<cols).flatMap { c -> [Double] in
            let x = left + Double(c) * (size.width + gap)
            return [x, x + size.width]
        }
        let rowEdges: [Double] = (0..<rows).flatMap { r -> [Double] in
            let y = top + Double(r) * (size.height + gap)
            return [y, y + size.height]
        }

        var ticks: [Tick] = []

        // Vertical ticks in each gap between rows, at every column edge.
        for r in 0..<(rows - 1) {
            let gapTop = top + Double(r) * (size.height + gap) + size.height
            for x in columnEdges {
                ticks.append(Tick(from: CGPoint(x: x, y: gapTop + o), to: CGPoint(x: x, y: gapTop + gap - o)))
            }
        }

        // Horizontal ticks in each gap between columns, at every row edge.
        for c in 0..<(cols - 1) {
            let gapLeft = left + Double(c) * (size.width + gap) + size.width
            for y in rowEdges {
                ticks.append(Tick(from: CGPoint(x: gapLeft + o, y: y), to: CGPoint(x: gapLeft + gap - o, y: y)))
            }
        }

        // Horizontal ticks in the side margins, at every row edge.
        for y in rowEdges {
            ticks.append(Tick(from: CGPoint(x: left - o - L, y: y), to: CGPoint(x: left - o, y: y)))
            ticks.append(Tick(from: CGPoint(x: right + o, y: y), to: CGPoint(x: right + o + L, y: y)))
        }

        // Vertical ticks above the top row and below the bottom row, only when there is room.
        if top >= margin + o + L {
            for x in columnEdges {
                ticks.append(Tick(from: CGPoint(x: x, y: top - o - L), to: CGPoint(x: x, y: top - o)))
            }
        }
        if paper.height - bottom >= margin + o + L {
            for x in columnEdges {
                ticks.append(Tick(from: CGPoint(x: x, y: bottom + o), to: CGPoint(x: x, y: bottom + o + L)))
            }
        }

        return ticks
    }
}
