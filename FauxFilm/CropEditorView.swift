import FauxFilmKit
import SwiftUI

/// Large framed preview of one photo, with drag to pan, pinch/slider to zoom, and rotate.
struct CropEditorView: View {
    @Environment(AppModel.self) private var model
    let itemID: UUID

    @State private var dragStart: Crop?
    @State private var zoomStart: Crop?

    private var item: PrintItem? { model.session.items.first { $0.id == itemID } }

    var body: some View {
        if let item {
            VStack(spacing: 20) {
                GeometryReader { geo in
                    let spec = item.format.spec
                    let fit = min(geo.size.width / spec.cardWidth, geo.size.height / spec.cardHeight)
                    let width = spec.cardWidth * fit
                    CardView(item: model.previewItem(item), width: width)
                        .gesture(dragGesture(item: item, pointsPerMM: fit))
                        .simultaneousGesture(magnifyGesture(item: item))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(32)

                controls(item: item)
            }
            .padding(.bottom, 20)
        }
    }

    private func controls(item: PrintItem) -> some View {
        HStack(spacing: 24) {
            HStack {
                Image(systemName: "minus.magnifyingglass")
                Slider(value: Binding(
                    get: { item.crop.zoom },
                    set: { setCrop(item, zoom: $0) }
                ), in: Crop.zoomRange)
                .frame(width: 180)
                Image(systemName: "plus.magnifyingglass")
            }
            Button {
                var c = Crop(quarterTurns: (item.crop.quarterTurns + 1) % 4)
                c.zoom = 1
                model.session.updateCrop(c, for: item.id)
            } label: {
                Label("Rotate", systemImage: "rotate.right")
            }
            LookControls()
        }
        .controlSize(.regular)
    }

    // MARK: - Gestures

    private func rotatedSize(_ item: PrintItem) -> CGSize {
        let img = model.previews[item.id] ?? item.image
        let w = CGFloat(img.width), h = CGFloat(img.height)
        return item.crop.quarterTurns % 2 == 0 ? CGSize(width: w, height: h) : CGSize(width: h, height: w)
    }

    private func dragGesture(item: PrintItem, pointsPerMM: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = dragStart ?? item.crop
                if dragStart == nil { dragStart = start }
                let size = rotatedSize(item)
                let aspect = item.format.spec.pictureAspect
                let src = start.sourceRect(imageSize: size, targetAspect: aspect)
                let windowWidthPt = item.format.spec.pictureRect.width * pointsPerMM
                let pixelsPerPoint = src.width / windowWidthPt
                var c = start
                // Dragging right reveals more of the left side: the centre moves left.
                c.center.x = start.center.x - value.translation.width * pixelsPerPoint / size.width
                c.center.y = start.center.y - value.translation.height * pixelsPerPoint / size.height
                model.session.updateCrop(c.clamped(imageSize: size, targetAspect: aspect), for: item.id)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func magnifyGesture(item: PrintItem) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = zoomStart ?? item.crop
                if zoomStart == nil { zoomStart = start }
                setCrop(item, zoom: start.zoom * value.magnification, base: start)
            }
            .onEnded { _ in zoomStart = nil }
    }

    private func setCrop(_ item: PrintItem, zoom: Double, base: Crop? = nil) {
        var c = base ?? item.crop
        c.zoom = min(max(zoom, Crop.zoomRange.lowerBound), Crop.zoomRange.upperBound)
        model.session.updateCrop(
            c.clamped(imageSize: rotatedSize(item), targetAspect: item.format.spec.pictureAspect),
            for: item.id
        )
    }
}
