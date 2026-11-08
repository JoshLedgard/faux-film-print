import FauxFilmKit
import SwiftUI

/// Film look picker and strength slider. Changes apply to every selected photo.
struct LookControls: View {
    @Environment(AppModel.self) private var model

    private var current: PrintItem? { model.session.selectedItems.first }

    var body: some View {
        HStack(spacing: 14) {
            Picker("Look", selection: Binding(
                get: { current?.look ?? .none },
                set: { model.session.setLook($0) }
            )) {
                ForEach(FilmLook.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            HStack(spacing: 6) {
                Text("Strength").foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { current?.lookStrength ?? PrintItem.defaultLookStrength },
                    set: { model.session.setLookStrength($0) }
                ), in: 0...1)
                .frame(width: 120)
                Text("\(Int(((current?.lookStrength ?? PrintItem.defaultLookStrength) * 100).rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }
            .disabled((current?.look ?? .none) == .none)
        }
    }
}
