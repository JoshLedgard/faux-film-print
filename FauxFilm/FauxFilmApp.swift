import FauxFilmKit
import SwiftUI

@main
struct FauxFilmApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Faux Film", id: "main") {
            ContentView()
                .environment(model)
                .task { await model.loadSavedSession() }
                .task(id: model.saveKey) {
                    // Debounced autosave.
                    try? await Task.sleep(for: .milliseconds(600))
                    guard !Task.isCancelled else { return }
                    await model.save()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    model.saveNow()
                }
        }
        .defaultSize(width: 1100, height: 760)
        .commands {
            CommandGroup(replacing: .printItem) {
                Button("Print…") { Task { await PrintController.printSheets(model: model) } }
                    .keyboardShortcut("p")
                    .disabled(model.session.items.isEmpty)
                Button("Export PDF…") { Task { await PrintController.exportPDF(model: model) } }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(model.session.items.isEmpty)
                Divider()
                Button("Print Size Test…") { PrintController.printSizeTest() }
            }
        }

        Settings {
            SettingsView()
        }
    }
}

/// Keys for user preferences.
enum Prefs {
    static let printBrightness = "printBrightness"
    static let paperTexture = "paperTexture"
    static let cornerGuides = "cornerGuides"
    static let didShowSizeTestHint = "didShowSizeTestHint"

    static func register() {
        UserDefaults.standard.register(defaults: [
            printBrightness: 0.25,
            paperTexture: false,
            cornerGuides: true,
        ])
    }

    /// Options for printing (`forPrint == true`) or on-screen previews.
    static func renderOptions(forPrint: Bool) -> RenderOptions {
        register()
        let d = UserDefaults.standard
        return RenderOptions(
            printBrightness: forPrint ? d.double(forKey: printBrightness) : 0,
            paperTexture: d.bool(forKey: paperTexture),
            cornerGuides: d.bool(forKey: cornerGuides)
        )
    }
}

struct SettingsView: View {
    @AppStorage(Prefs.printBrightness) private var printBrightness = 0.25
    @AppStorage(Prefs.paperTexture) private var paperTexture = false
    @AppStorage(Prefs.cornerGuides) private var cornerGuides = true

    var body: some View {
        Form {
            Section {
                Slider(value: $printBrightness, in: -1...1, step: 0.05) {
                    Text("Print brightness")
                } minimumValueLabel: {
                    Text("Darker")
                } maximumValueLabel: {
                    Text("Brighter")
                }
                Text(String(format: "%+.2f EV. Inkjet prints usually come out darker than the screen. Raise this if your prints look murky next to real film.", printBrightness))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Corner rounding guides", isOn: $cornerGuides)
                Text("Faint curves at each corner to trim along, or to line up a corner-rounder punch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Paper texture on border", isOn: $paperTexture)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .padding(.vertical)
    }
}
