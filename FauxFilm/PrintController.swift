import AppKit
import FauxFilmKit
import PDFKit
import UniformTypeIdentifiers

/// Printing and PDF export. Everything prints at 100% scale: if the printer can't reach
/// far enough toward the paper edge, we print fewer rows, never smaller prints.
@MainActor
enum PrintController {
    private static let letterPoints = NSSize(width: 612, height: 792)

    static func printSheets(model: AppModel) async {
        guard !model.session.items.isEmpty else { return }
        let window = NSApp.keyWindow

        if !UserDefaults.standard.bool(forKey: Prefs.didShowSizeTestHint) {
            UserDefaults.standard.set(true, forKey: Prefs.didShowSizeTestHint)
            let alert = NSAlert()
            alert.messageText = "Check the size first?"
            alert.informativeText = "Print the size test on plain paper and lay a real Instax Mini on it before you use glossy paper. It's always in File ▸ Print Size Test."
            alert.addButton(withTitle: "Print Size Test")
            alert.addButton(withTitle: "Print Sheets")
            if alert.runModal() == .alertFirstButtonReturn {
                printSizeTest()
                return
            }
        }

        let info = printInfo()
        guard let maxRows = rowsThatFit(model: model, info: info) else { return }

        let items = model.session.items
        let options = Prefs.renderOptions(forPrint: true)
        let data = await Task.detached(priority: .userInitiated) {
            PDFComposer.pdf(pages: Paginator.pages(for: items, maxRows: maxRows), options: options)
        }.value
        run(data: data, info: info, window: window)
    }

    static func printSizeTest() {
        run(data: PDFComposer.sizeTestPDF(), info: printInfo(), window: NSApp.keyWindow)
    }

    static func exportPDF(model: AppModel) async {
        guard !model.session.items.isEmpty else { return }
        // Same printable-area check as printing (against the default printer), so the
        // PDF is safe to print from Preview too.
        guard let maxRows = rowsThatFit(model: model, info: printInfo()) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Faux Film Print Sheets.pdf"
        panel.message = "When you print this PDF, choose Scale 100% — not “Scale to Fit” — so prints stay true size."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let items = model.session.items
        let options = Prefs.renderOptions(forPrint: true)
        let data = await Task.detached(priority: .userInitiated) {
            PDFComposer.pdf(pages: Paginator.pages(for: items, maxRows: maxRows), options: options)
        }.value
        do {
            try data.write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // MARK: - Helpers

    private static func printInfo() -> NSPrintInfo {
        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        info.paperSize = letterPoints
        info.orientation = .portrait
        info.topMargin = 0
        info.bottomMargin = 0
        info.leftMargin = 0
        info.rightMargin = 0
        info.horizontalPagination = .clip
        info.verticalPagination = .clip
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        info.scalingFactor = 1
        return info
    }

    /// Checks each format's grid against the printer's imageable area. Returns the row
    /// limits to use, or nil if the user cancelled.
    private static func rowsThatFit(model: AppModel, info: NSPrintInfo) -> [FilmFormat: Int]? {
        let imageable = PDFComposer.imageableMM(fromPoints: info.imageablePageBounds, paper: .letter)
        var maxRows: [FilmFormat: Int] = [:]
        let formats = Set(model.session.items.map(\.format))
        for format in FilmFormat.allCases where formats.contains(format) {
            let full = SheetLayout.make(format: format)
            guard !full.isInside(imageable) else { continue }
            var rows = full.rows - 1
            while rows > 0, !SheetLayout.make(format: format, maxRows: rows).isInside(imageable) { rows -= 1 }

            let alert = NSAlert()
            alert.messageText = "Your printer can't print this close to the edge"
            if rows > 0 {
                let fits = SheetLayout.make(format: format, maxRows: rows).slots.count
                alert.informativeText = "To keep \(format.displayName) prints at true size, Faux Film Print can fit \(fits) per sheet instead of \(full.slots.count). If your printer has a borderless paper option, choosing it as the default paper may let all \(full.slots.count) fit."
                alert.addButton(withTitle: "Print \(fits) per Sheet")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return nil }
                maxRows[format] = rows
            } else {
                alert.informativeText = "\(format.displayName) prints won't fit inside this printer's printable area at true size."
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return nil
            }
        }
        return maxRows
    }

    private static func run(data: Data, info: NSPrintInfo, window: NSWindow?) {
        guard let document = PDFDocument(data: data),
              let operation = document.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: false)
        else {
            let alert = NSAlert()
            alert.messageText = "Couldn't prepare the sheets for printing."
            alert.runModal()
            return
        }
        operation.jobTitle = "Faux Film Print"
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        // Never let the panel scale the page: prints must stay true size.
        operation.printPanel.options.remove(.showsScaling)
        if let window {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }
}
