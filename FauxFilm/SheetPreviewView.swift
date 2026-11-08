import FauxFilmKit
import PDFKit
import SwiftUI

/// Shows every sheet as it will print, rebuilt (debounced) whenever the photos change.
/// Clicking a print opens that photo in the crop editor.
struct SheetPreviewView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Prefs.cornerGuides) private var cornerGuides = true
    @AppStorage(Prefs.paperTexture) private var paperTexture = false
    @State private var document: PDFDocument?
    @State private var pages: [Page] = []

    /// Called with the id of the photo whose print was clicked.
    var onOpen: (UUID) -> Void

    private var key: String {
        model.saveKey + "|\(cornerGuides)|\(paperTexture)"
    }

    var body: some View {
        Group {
            if model.session.items.isEmpty {
                ContentUnavailableView("Nothing to Print", systemImage: "printer",
                                       description: Text("Add photos to see the sheets."))
            } else {
                PDFPreview(document: document) { pageIndex, pointMM in
                    guard pages.indices.contains(pageIndex) else { return false }
                    let page = pages[pageIndex]
                    guard let slot = page.layout.slotIndex(at: pointMM), let item = page.items[slot] else { return false }
                    onOpen(item.id)
                    return true
                }
                .overlay(alignment: .bottom) {
                    Text("Click a print to edit it")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                        .padding(10)
                }
            }
        }
        .task(id: key) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            // Low-resolution previews keep this fast; printing uses the full photos.
            let items = model.session.items.map(model.previewItem)
            let newPages = Paginator.pages(for: items)
            var options = Prefs.renderOptions(forPrint: false)
            options.dpi = 120
            let data = await Task.detached(priority: .userInitiated) {
                PDFComposer.pdf(pages: newPages, options: options)
            }.value
            if !Task.isCancelled {
                pages = newPages
                document = PDFDocument(data: data)
            }
        }
    }
}

private struct PDFPreview: NSViewRepresentable {
    let document: PDFDocument?
    /// (page index, point on the sheet in mm, y down) → true if the click was handled.
    let onClick: (Int, CGPoint) -> Bool

    func makeNSView(context: Context) -> ClickablePDFView {
        let view = ClickablePDFView()
        view.autoScales = false
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .underPageBackgroundColor
        return view
    }

    func updateNSView(_ view: ClickablePDFView, context: Context) {
        view.onClick = onClick
        guard view.document !== document else { return }
        let firstLoad = view.document == nil
        view.document = document
        // Show a whole sheet at a time; keep the user's zoom once they've seen the preview.
        DispatchQueue.main.async {
            if firstLoad, let page = document?.page(at: 0) {
                let box = page.bounds(for: .mediaBox)
                let fit = min(view.bounds.width / box.width, view.bounds.height / box.height) * 0.92
                if fit > 0 { view.scaleFactor = fit }
            }
            if let first = document?.page(at: 0), firstLoad { view.go(to: first) }
        }
    }
}

final class ClickablePDFView: PDFView {
    var onClick: ((Int, CGPoint) -> Bool)?

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let page = page(for: p, nearest: false), let document, let onClick {
            let index = document.index(for: page)
            let pt = convert(p, to: page) // PDF points, y up
            let height = page.bounds(for: .mediaBox).height
            let mm = CGPoint(x: pt.x / MM.pointsPerMM, y: (height - pt.y) / MM.pointsPerMM)
            if onClick(index, mm) { return }
        }
        super.mouseDown(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
