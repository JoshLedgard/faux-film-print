import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Saves and restores the session: a JSON manifest plus the app's own copy of each photo.
/// Originals (Photos library, dropped files) are never written to.
public enum SessionStore {
    private struct Manifest: Codable {
        var version = 1
        var items: [StoredItem]
    }

    private struct StoredItem: Codable {
        var id: UUID
        var format: FilmFormat
        var crop: Crop
        var look: FilmLook
        /// Optional so sessions saved before strength existed still load.
        var lookStrength: Double?
        var copies: Int
        var photo: String
    }

    /// Default location: Application Support/Faux Film (inside the app's sandbox container).
    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Faux Film", isDirectory: true)
    }

    public static func save(_ items: [PrintItem], to dir: URL) throws {
        let fm = FileManager.default
        let photos = dir.appendingPathComponent("photos", isDirectory: true)
        try fm.createDirectory(at: photos, withIntermediateDirectories: true)

        var stored: [StoredItem] = []
        for item in items {
            let name = "\(item.id.uuidString).heic"
            let url = photos.appendingPathComponent(name)
            if !fm.fileExists(atPath: url.path) {
                try writePhoto(item.image, to: url)
            }
            stored.append(StoredItem(id: item.id, format: item.format, crop: item.crop,
                                     look: item.look, lookStrength: item.lookStrength,
                                     copies: item.copies, photo: name))
        }

        let data = try JSONEncoder().encode(Manifest(items: stored))
        try data.write(to: dir.appendingPathComponent("session.json"), options: .atomic)

        // Remove photos that no longer belong to any item.
        let keep = Set(stored.map(\.photo))
        for file in (try? fm.contentsOfDirectory(atPath: photos.path)) ?? [] where !keep.contains(file) {
            try? fm.removeItem(at: photos.appendingPathComponent(file))
        }
    }

    public static func load(from dir: URL) -> [PrintItem] {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent("session.json")),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        else { return [] }
        let photos = dir.appendingPathComponent("photos", isDirectory: true)
        return manifest.items.compactMap { s in
            guard let image = ImageDecoder.decode(url: photos.appendingPathComponent(s.photo)) else { return nil }
            var item = PrintItem(id: s.id, image: image, format: s.format, crop: s.crop, look: s.look, copies: s.copies)
            item.lookStrength = s.lookStrength ?? PrintItem.defaultLookStrength
            return item
        }
    }

    private static func writePhoto(_ image: CGImage, to url: URL) throws {
        let props = [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary
        if let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.heic.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, image, props)
            if CGImageDestinationFinalize(dest) { return }
        }
        // HEIC encoding unavailable: fall back to JPEG data under the same name (ImageIO sniffs content).
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(dest, image, props)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
    }
}
