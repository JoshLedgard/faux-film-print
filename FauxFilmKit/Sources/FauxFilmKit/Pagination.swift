import Foundation

/// One printed sheet.
public struct Page: Sendable {
    public let layout: SheetLayout
    /// One entry per slot; `nil` slots are left blank.
    public let items: [PrintItem?]
}

public enum Paginator {
    public static let copiesRange: ClosedRange<Int> = 1...99

    /// Expands copies, groups by format (in order of first appearance, tray order within
    /// a format) and fills sheets. Each format starts on a fresh sheet.
    public static func pages(
        for items: [PrintItem],
        paper: Paper = .letter,
        maxRows: [FilmFormat: Int] = [:]
    ) -> [Page] {
        var order: [FilmFormat] = []
        var groups: [FilmFormat: [PrintItem]] = [:]
        for item in items {
            if groups[item.format] == nil { order.append(item.format) }
            let n = min(max(item.copies, copiesRange.lowerBound), copiesRange.upperBound)
            groups[item.format, default: []].append(contentsOf: Array(repeating: item, count: n))
        }

        var pages: [Page] = []
        for format in order {
            let layout = SheetLayout.make(format: format, paper: paper, maxRows: maxRows[format])
            let perPage = layout.slots.count
            guard perPage > 0, let all = groups[format] else { continue }
            for start in stride(from: 0, to: all.count, by: perPage) {
                var chunk: [PrintItem?] = Array(all[start..<min(start + perPage, all.count)])
                chunk.append(contentsOf: Array(repeating: nil, count: perPage - chunk.count))
                pages.append(Page(layout: layout, items: chunk))
            }
        }
        return pages
    }
}
