import FauxFilmKit
import PhotosUI
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var picks: [PhotosPickerItem] = []
    @State private var showSheets = false

    private var session: Session { model.session }

    /// Format shown in the toolbar: the selected photo's, or the default for new photos.
    private var formatBinding: Binding<FilmFormat> {
        Binding(
            get: { session.selectedItems.first?.format ?? session.defaultFormat },
            set: { session.setFormat($0) }
        )
    }

    var body: some View {
        NavigationSplitView {
            TrayView(picks: $picks)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } detail: {
            Group {
                if showSheets {
                    SheetPreviewView { id in
                        session.selection = [id]
                        showSheets = false
                    }
                } else if let item = session.selectedItems.first, session.selection.count == 1 {
                    CropEditorView(itemID: item.id)
                } else if session.selection.count > 1 {
                    BulkEditView()
                } else if session.items.isEmpty {
                    ContentUnavailableView {
                        Label("No Photos Yet", systemImage: "photo.on.rectangle.angled")
                    } description: {
                        Text("Add photos from your Photos library, or drag image files here.")
                    } actions: {
                        PhotosPicker("Add Photos", selection: $picks, matching: .images)
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ContentUnavailableView {
                        Label("Select a Photo", systemImage: "hand.point.left")
                    } description: {
                        Text("Pick one photo to crop it, or select several (⌘A for all) to change their look together.")
                    } actions: {
                        Button("Select All") { session.selection = Set(session.items.map(\.id)) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Format", selection: formatBinding) {
                    ForEach(FilmFormat.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .help("Film format for the selected photos and for new ones")
            }
            ToolbarItem {
                Toggle(isOn: $showSheets) {
                    Label("Sheets", systemImage: "rectangle.grid.3x2")
                }
                .help("Preview the printed sheets")
            }
            ToolbarItem {
                Button {
                    Task { await PrintController.exportPDF(model: model) }
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
                .help("Save the sheets as a PDF")
                .disabled(session.items.isEmpty)
            }
            ToolbarItem {
                Button {
                    Task { await PrintController.printSheets(model: model) }
                } label: {
                    Label("Print", systemImage: "printer")
                }
                .help("Print the sheets at true size")
                .disabled(session.items.isEmpty)
            }
        }
        .onChange(of: picks) { _, newPicks in
            guard !newPicks.isEmpty else { return }
            Task {
                await model.importPhotos(newPicks)
                picks = []
            }
        }
        #if DEBUG
        .task {
            // Debug aid for screenshots: `-FFDemoFiles "/path/a.heic|/path/b.jpg"`.
            while !model.hasLoaded { try? await Task.sleep(for: .milliseconds(100)) }
            if let list = UserDefaults.standard.string(forKey: "FFDemoFiles"), model.session.items.isEmpty {
                await model.importFiles(list.split(separator: "|").map { URL(fileURLWithPath: String($0)) })
            }
        }
        #endif
        .dropDestination(for: URL.self) { urls, _ in
            Task { await model.importFiles(urls) }
            return true
        }
        .overlay(alignment: .bottom) {
            if model.isImporting {
                ProgressView("Adding photos…")
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
    }
}
