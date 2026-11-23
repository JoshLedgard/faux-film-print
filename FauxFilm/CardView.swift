import FauxFilmKit
import SwiftUI

/// Renders a framed card off the main thread and shows it at `width` points.
struct CardView: View {
    let item: PrintItem
    let width: CGFloat
    var pixelScale: CGFloat = 2
    /// Skip the film look and render at 1× while the user is dragging or pinching.
    var fastPreview = false

    @AppStorage(Prefs.cornerGuides) private var cornerGuides = true
    @AppStorage(Prefs.paperTexture) private var paperTexture = false
    @State private var image: CGImage?
    @State private var renderer = CardRenderQueue()

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
        .task(id: "\(item.renderKey)|\(width)|\(cornerGuides)|\(paperTexture)|\(fastPreview)") {
            var renderItem = item
            if fastPreview { renderItem.look = .none }
            let item = renderItem
            let ppm = Double(width * (fastPreview ? 1 : pixelScale)) / item.spec.cardWidth
            let options = Prefs.renderOptions(forPrint: false)
            renderer.request {
                PrintRenderer.cardImage(item, options: options, pixelsPerMM: ppm)
            } deliver: { rendered in
                image = rendered
            }
        }
    }
}

/// Runs at most one card render at a time. Requests that arrive while one is
/// running replace each other, so only the newest is rendered next; the view
/// keeps showing the previous image until then.
@MainActor
final class CardRenderQueue {
    private var busy = false
    private var next: (render: @Sendable () -> CGImage, deliver: (CGImage) -> Void)?

    func request(_ render: @escaping @Sendable () -> CGImage, deliver: @escaping (CGImage) -> Void) {
        next = (render, deliver)
        if !busy { pump() }
    }

    private func pump() {
        guard let job = next else { return }
        next = nil
        busy = true
        let render = job.render
        Task {
            let rendered = await Task.detached(priority: .userInitiated) { render() }.value
            job.deliver(rendered)
            busy = false
            pump()
        }
    }
}
