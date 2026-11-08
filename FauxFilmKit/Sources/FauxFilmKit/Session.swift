import CoreGraphics
import Foundation
import Observation

/// Everything the user has added in this run of the app.
@MainActor
@Observable
public final class Session {
    public var items: [PrintItem] = []
    public var selection: Set<UUID> = []
    /// Format given to newly added photos; follows the last format picked.
    public var defaultFormat: FilmFormat = .instaxMini

    public init() {}

    public var selectedItems: [PrintItem] { items.filter { selection.contains($0.id) } }

    /// Replaces everything with a previously saved session.
    public func restore(_ saved: [PrintItem]) {
        items = saved
        selection = []
        if let last = saved.last { defaultFormat = last.format }
    }

    public func add(_ images: [CGImage]) {
        let new = images.map { PrintItem(image: $0, format: defaultFormat) }
        items.append(contentsOf: new)
        if let last = new.last { selection = [last.id] }
    }

    /// Applies a format to the selected photos. Their crops reset to centred/fill
    /// (crops don't carry across aspect ratios); rotation is kept.
    public func setFormat(_ format: FilmFormat) {
        defaultFormat = format
        mutateSelected { item in
            guard item.format != format else { return }
            item.format = format
            item.crop = Crop(quarterTurns: item.crop.quarterTurns)
        }
    }

    public func setLook(_ look: FilmLook) {
        mutateSelected { $0.look = look }
    }

    /// Strength of the look (0…1) for every selected photo.
    public func setLookStrength(_ strength: Double) {
        let s = min(1, max(0, strength))
        mutateSelected { $0.lookStrength = s }
    }

    public func setCopies(_ n: Int, for id: UUID) {
        mutate(id) { $0.copies = min(max(n, Paginator.copiesRange.lowerBound), Paginator.copiesRange.upperBound) }
    }

    public func updateCrop(_ crop: Crop, for id: UUID) {
        mutate(id) { $0.crop = crop }
    }

    public func remove(_ ids: Set<UUID>) {
        items.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
    }

    public func pages(maxRows: [FilmFormat: Int] = [:]) -> [Page] {
        Paginator.pages(for: items, maxRows: maxRows)
    }

    private func mutate(_ id: UUID, _ change: (inout PrintItem) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
    }

    private func mutateSelected(_ change: (inout PrintItem) -> Void) {
        for i in items.indices where selection.contains(items[i].id) {
            change(&items[i])
        }
    }
}
