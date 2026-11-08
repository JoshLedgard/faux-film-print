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

    /// False until the saved session has been loaded; saving is blocked until then so a
    /// slow load can never overwrite the saved session with an empty one.
    private(set) var hasLoaded = false
    private let storeDirectory = SessionStore.defaultDirectory

    // MARK: - Persistence

    func loadSavedSession() async {
        guard !hasLoaded else { return }
        let dir = storeDirectory
        let loaded: [(PrintItem, CGImage)] = await Task.detached(priority: .userInitiated) {
            SessionStore.load(from: dir).map { ($0, Self.downscale($0.image, maxPixel: Self.previewMaxPixel)) }
        }.value
        // Keep anything added while loading (e.g. a quick drop) after the restored photos.
        let addedMeanwhile = session.items
        session.restore(loaded.map(\.0) + addedMeanwhile)
        for (item, preview) in loaded { previews[item.id] = preview }
        hasLoaded = true
    }

    /// A value that changes whenever something worth saving changes.
    var saveKey: String {
        session.items.map { "\($0.renderKey)x\($0.copies)" }.joined(separator: ",")
    }

    func save() async {
        guard hasLoaded else { return }
        let items = session.items
        let dir = storeDirectory
        await Task.detached(priority: .utility) {
            try? SessionStore.save(items, to: dir)
        }.value
    }

    /// Synchronous save for app quit.
    func saveNow() {
        guard hasLoaded else { return }
        try? SessionStore.save(session.items, to: storeDirectory)
    }

    nonisolated static func downscale(_ image: CGImage, maxPixel: Int) -> CGImage {
        let longEdge = max(image.width, image.height)
        guard longEdge > maxPixel else { return image }
        let scale = Double(maxPixel) / Double(longEdge)
        let w = max(1, Int(Double(image.width) * scale)), h = max(1, Int(Double(image.height) * scale))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }

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
        "\(id)|\(format.rawValue)|\(crop.zoom)|\(crop.center.x)|\(crop.center.y)|\(crop.quarterTurns)|\(look.rawValue)|\(lookStrength)"
    }
}
