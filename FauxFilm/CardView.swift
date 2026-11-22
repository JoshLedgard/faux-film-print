import FauxFilmKit
import SwiftUI

/// Renders a framed card off the main thread and shows it at `width` points.
struct CardView: View {
    let item: PrintItem
    let width: CGFloat
    var pixelScale: CGFloat = 2

    @AppStorage(Prefs.cornerGuides) private var cornerGuides = true
    @AppStorage(Prefs.paperTexture) private var paperTexture = false
    @State private var image: CGImage?

    private var height: CGFloat {
        width * item.spec.cardSize.height / item.spec.cardSize.width
    }

    /// The largest width at which `item`'s card fits inside `box`.
    static func width(for item: PrintItem, fitting box: CGSize) -> CGFloat {
        min(box.width, box.height * item.spec.cardWidth / item.spec.cardHeight)
    }

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: 2).fill(Color(cgColor: FrameStyle.borderColor))
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        .task(id: "\(item.renderKey)|\(width)|\(cornerGuides)|\(paperTexture)") {
            let item = item
            let ppm = Double(width * pixelScale) / item.spec.cardWidth
            let options = Prefs.renderOptions(forPrint: false)
            let rendered = await Task.detached(priority: .userInitiated) {
                PrintRenderer.cardImage(item, options: options, pixelsPerMM: ppm)
            }.value
            if !Task.isCancelled { image = rendered }
        }
    }
}
