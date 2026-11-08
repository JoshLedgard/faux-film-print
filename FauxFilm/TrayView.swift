import FauxFilmKit
import PhotosUI
import SwiftUI

struct TrayView: View {
    @Environment(AppModel.self) private var model
    @Binding var picks: [PhotosPickerItem]

    var body: some View {
        @Bindable var session = model.session
        List(selection: $session.selection) {
            ForEach(session.items) { item in
                TrayRow(item: model.previewItem(item))
                    .tag(item.id)
                    .contextMenu {
                        Button("Remove", role: .destructive) { model.remove(removalSet(for: item.id)) }
                    }
            }
        }
        .onDeleteCommand { model.remove(session.selection) }
        .safeAreaInset(edge: .bottom) {
            HStack {
                PhotosPicker(selection: $picks, matching: .images) {
                    Label("Add Photos", systemImage: "plus")
                }
                Spacer()
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.bar)
        }
    }

    /// Right-clicking a selected row removes the whole selection; otherwise just that row.
    private func removalSet(for id: UUID) -> Set<UUID> {
        model.session.selection.contains(id) ? model.session.selection : [id]
    }

    private var summary: String {
        let prints = model.session.items.reduce(0) { $0 + $1.copies }
        let sheets = model.session.pages().count
        guard prints > 0 else { return "" }
        return "\(prints) print\(prints == 1 ? "" : "s") · \(sheets) sheet\(sheets == 1 ? "" : "s")"
    }
}

private struct TrayRow: View {
    @Environment(AppModel.self) private var model
    let item: PrintItem

    var body: some View {
        HStack(spacing: 12) {
            CardView(item: item, width: item.format.spec.cardWidth > 60 ? 64 : 44)
                .frame(width: 64, height: 76)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.format.displayName).font(.callout)
                Stepper(value: Binding(
                    get: { item.copies },
                    set: { model.session.setCopies($0, for: item.id) }
                ), in: Paginator.copiesRange) {
                    Text("× \(item.copies)").monospacedDigit().foregroundStyle(.secondary)
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
