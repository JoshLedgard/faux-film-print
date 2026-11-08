import FauxFilmKit
import SwiftUI

/// Shown when several photos are selected: apply a look, strength or format to all of
/// them at once, or click one to open it in the crop editor.
struct BulkEditView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let selected = model.session.selectedItems
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 20)], spacing: 24) {
                    ForEach(selected) { item in
                        Button {
                            model.session.selection = [item.id]
                        } label: {
                            CardView(item: model.previewItem(item), width: item.format.spec.cardWidth > 60 ? 140 : 100)
                                .frame(height: 170)
                        }
                        .buttonStyle(.plain)
                        .help("Edit this photo")
                    }
                }
                .padding(28)
            }

            VStack(spacing: 10) {
                Text("\(selected.count) photos selected. Changes apply to all of them. Click one to crop it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                LookControls()
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }
}
