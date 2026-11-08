import CoreGraphics
import FauxFilmKit
import Foundation
import Observation
import PhotosUI
import SwiftUI

/// App state: the session plus small preview copies of each photo for fast on-screen rendering.
@MainActor
@Observable
final class AppModel {
    let session = Session()
    private(set) var previews: [UUID: CGImage] = [:]
    var isImporting = false
    var importFailures = 0

    nonisolated static let previewMaxPixel = 1400

    /// The item with its photo swapped for the preview copy (crop is resolution-independent).
    func previewItem(_ item: PrintItem) -> PrintItem {
        var copy = item
        if let p = previews[item.id] { copy.image = p }
        return copy
    }

    func importPhotos(_ picks: [PhotosPickerItem]) async {
        isImporting = true
        defer { isImporting = false }
        var decoded: [(CGImage, CGImage)] = []
        for pick in picks {
            guard let data = try? await pick.loadTransferable(type: Data.self) else {
                importFailures += 1
                continue
            }
            if let pair = await Self.decode(data: data) { decoded.append(pair) } else { importFailures += 1 }
        }
        add(decoded)
    }

    func importFiles(_ urls: [URL]) async {
        isImporting = true
        defer { isImporting = false }
        var decoded: [(CGImage, CGImage)] = []
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let pair = await Self.decode(data: data) {
                decoded.append(pair)
            } else {
                importFailures += 1
            }
        }
        add(decoded)
    }

    private func add(_ decoded: [(full: CGImage, preview: CGImage)]) {
        guard !decoded.isEmpty else { return }
        session.add(decoded.map(\.full))
        for (item, pair) in zip(session.items.suffix(decoded.count), decoded) {
            previews[item.id] = pair.preview
        }
    }

    func remove(_ ids: Set<UUID>) {
        session.remove(ids)
        for id in ids { previews[id] = nil }
    }

    private nonisolated static func decode(data: Data) async -> (CGImage, CGImage)? {
        await Task.detached(priority: .userInitiated) {
            guard let full = ImageDecoder.decode(data: data),
                  let preview = ImageDecoder.decode(data: data, maxPixel: previewMaxPixel)
            else { return nil }
            return (full, preview)
        }.value
    }
}

/// A stable value that changes whenever anything that affects rendering changes.
extension PrintItem {
    var renderKey: String {
        "\(id)|\(format.rawValue)|\(crop.zoom)|\(crop.center.x)|\(crop.center.y)|\(crop.quarterTurns)|\(look.rawValue)"
    }
}
