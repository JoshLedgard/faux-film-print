import FauxFilmKit
import PDFKit
import SwiftUI

/// Shows every sheet as it will print, rebuilt (debounced) whenever the photos change.
struct SheetPreviewView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Prefs.cornerGuides) private var cornerGuides = true
    @AppStorage(Prefs.paperTexture) private var paperTexture = false
    @State private var document: PDFDocument?

    private var key: String {
        model.session.items.map { "\($0.renderKey)x\($0.copies)" }.joined(separator: ",")
            + "|\(cornerGuides)|\(paperTexture)"
    }

    var body: some View {
        Group {
            if model.session.items.isEmpty {
                ContentUnavailableView("Nothing to Print", systemImage: "printer",
                                       description: Text("Add photos to see the sheets."))
            } else {
                PDFPreview(document: document)
            }
        }
        .task(id: key) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            // Low-resolution previews keep this fast; printing uses the full photos.
            let items = model.session.items.map(model.previewItem)
            var options = Prefs.renderOptions(forPrint: false)
            options.dpi = 120
            let data = await Task.detached(priority: .userInitiated) {
                PDFComposer.pdf(pages: Paginator.pages(for: items), options: options)
            }.value
            if !Task.isCancelled { document = PDFDocument(data: data) }
        }
    }
}

private struct PDFPreview: NSViewRepresentable {
    let document: PDFDocument?

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .underPageBackgroundColor
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
    }
}
