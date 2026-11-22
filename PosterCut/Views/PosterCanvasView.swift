import SwiftUI

/// Interactive studio preview canvas with Poster-First dynamic scale reference
/// (sculpted 180 cm person -> 210 cm doorway+sofa -> 6 m house), pinch-to-zoom,
/// sheet grid exclusion on tap, and tactile interactive crop handles.
struct PosterCanvasView: View {
    @ObservedObject var viewModel: PosterStudioViewModel
    @ObservedObject private var themeManager = PosterThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero

    @State private var activeCropHandle: String? = nil
    @State private var dragStartCrop: NormalizedCropRect = .full

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if viewModel.isCropMode, let cropImg = viewModel.cropSourceImage {
                    cropCanvas(in: geo.size, sourceImage: cropImg)
                } else {
                    posterPreviewCanvas(in: geo.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }

    // MARK: - Main Poster Preview + Dynamic Scale Reference

    private func posterPreviewCanvas(in size: CGSize) -> some View {
        let layout = computeCanvasLayout(in: size)

        return ZStack {
            // Subtle architectural blueprint dot grid
            Canvas { ctx, canvasSize in
                let dotColor = colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
                let step: CGFloat = 20
                var y: CGFloat = 10
                while y < canvasSize.height {
                    var x: CGFloat = 10
                    while x < canvasSize.width {
                        ctx.fill(Path(CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(dotColor))
                        x += step
                    }
                    y += step
                }

                // Dynamic real-world scale reference behind/beside poster left edge
                if viewModel.config.showSilhouette, let geom = viewModel.geometry {
                    let silColor = colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.13)
                    let posterHCM = max(geom.posterHMM, geom.gridHMM) / 10.0
                    let pxPerCM = layout.pxPerMM * 10.0

                    if posterHCM > 420.0 {
                        drawHouseFacade(
                            ctx: &ctx,
                            anchorRightX: Double(layout.posterRect.minX),
                            floorY: Double(layout.posterRect.maxY),
                            pxPerCM: pxPerCM,
                            color: silColor
                        )
                    } else if posterHCM > 220.0 {
                        drawRoomWall(
                            ctx: &ctx,
                            anchorRightX: Double(layout.posterRect.minX),
                            floorY: Double(layout.posterRect.maxY),
                            pxPerCM: pxPerCM,
                            color: silColor
                        )
                    } else {
                        let silHCM = viewModel.config.silhouetteHeightCM
                        let silHPx = silHCM * pxPerCM
                        let blend = max(0.0, min(1.0, (posterHCM - 40.0) / 115.0))
                        let pMinX = Double(layout.posterRect.minX)
                        let pMinY = Double(layout.posterRect.minY)
                        let pMaxY = Double(layout.posterRect.maxY)
                        let pH = Double(layout.posterRect.height)
                        let eyeFeetY = pMinY + pH * 0.22 + 152.0 * pxPerCM
                        let minHeadTop = max(48.0, pMinY - min(42.0, pH * 0.14))
                        let clampedEyeFeet = max(eyeFeetY, minHeadTop + silHPx)
                        let floorFeetY = pMaxY
                        let feetY = clampedEyeFeet * (1.0 - blend) + floorFeetY * blend

                        let overlapCM = 14.0 * (1.0 - blend) - 10.0 * blend
                        let silCX = pMinX - (20.0 - overlapCM) * pxPerCM

                        drawHumanSilhouette(
                            ctx: &ctx,
                            feetX: silCX,
                            feetY: feetY,
                            heightPx: silHPx,
                            color: silColor,
                            showRuler: silHPx <= Double(size.height) * 0.96
                        )
                    }
                }
            }

            // Poster paper sheet + artwork + cut grid overlay
            if let geom = viewModel.geometry, let img = viewModel.previewImage {
                let pRect = layout.posterRect
                let artW = geom.posterWMM * layout.pxPerMM
                let artH = geom.posterHMM * layout.pxPerMM

                ZStack(alignment: .topLeading) {
                    // Crisp paper backing with Apple elevation shadow
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: pRect.width, height: pRect.height)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.50 : 0.22), radius: 14, y: 7)

                    // WYSIWYG artwork image
                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: artW, height: artH)
                        .clipped()

                    // Interactive Sheet Cut Grid Overlay
                    if viewModel.config.showGrid {
                        sheetGridOverlay(geom: geom, pxPerMM: layout.pxPerMM, totalRect: pRect)
                    }
                }
                .frame(width: pRect.width, height: pRect.height)
                .overlay(
                    Rectangle()
                        .strokeBorder(Color.black.opacity(0.18), lineWidth: 0.8)
                )
                .position(x: pRect.midX, y: pRect.midY)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            MagnificationGesture()
                .onChanged { val in
                    zoom = max(0.5, min(5.0, lastZoom * val))
                }
                .onEnded { _ in
                    lastZoom = zoom
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { val in
                    pan = CGSize(
                        width: lastPan.width + val.translation.width,
                        height: lastPan.height + val.translation.height
                    )
                }
                .onEnded { _ in
                    lastPan = pan
                }
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                zoom = 1.0
                lastZoom = 1.0
                pan = .zero
                lastPan = .zero
            }
        }
        .onTapGesture(count: 1, coordinateSpace: .local) { location in
            guard viewModel.config.showGrid, let geom = viewModel.geometry else { return }
            let pRect = layout.posterRect
            guard pRect.contains(location) else { return }
            let mmX = Double(location.x - pRect.minX) / max(1e-6, layout.pxPerMM)
            let mmY = Double(location.y - pRect.minY) / max(1e-6, layout.pxPerMM)
            let c = max(0, min(geom.cols - 1, Int(mmX / max(1e-6, geom.stepWMM))))
            let r = max(0, min(geom.rows - 1, Int(mmY / max(1e-6, geom.stepHMM))))
            viewModel.toggleTile(TileCoord(col: c, row: r))
        }
    }

    private func sheetGridOverlay(geom: PosterGeometry, pxPerMM: Double, totalRect: CGRect) -> some View {
        let stepW = geom.stepWMM * pxPerMM
        let stepH = geom.stepHMM * pxPerMM
        let sheetW = geom.printableWMM * pxPerMM
        let sheetH = geom.printableHMM * pxPerMM
        let ovPx = geom.overlapMM * pxPerMM
        let accent = themeManager.primaryAccent

        return Canvas { ctx, _ in
            // Overlap glue strips
            if ovPx >= 1.2 {
                for c in 1..<geom.cols {
                    let ox = Double(c) * stepW
                    ctx.fill(Path(CGRect(x: ox, y: 0, width: ovPx, height: totalRect.height)), with: .color(accent.opacity(0.18)))
                }
                for r in 1..<geom.rows {
                    let oy = Double(r) * stepH
                    ctx.fill(Path(CGRect(x: 0, y: oy, width: totalRect.width, height: ovPx)), with: .color(accent.opacity(0.18)))
                }
            }

            // Excluded tiles hatching + coordinate badges
            for r in 0..<geom.rows {
                for c in 0..<geom.cols {
                    let tx = Double(c) * stepW
                    let ty = Double(r) * stepH
                    let tw = (c == geom.cols - 1) ? sheetW : stepW
                    let th = (r == geom.rows - 1) ? sheetH : stepH
                    let tileRect = CGRect(x: tx, y: ty, width: tw, height: th)
                    let isExcluded = viewModel.config.excludedTiles.contains(TileCoord(col: c, row: r))

                    if isExcluded {
                        ctx.fill(Path(tileRect), with: .color(Color.black.opacity(0.55)))
                        var hatch = Path()
                        var d: CGFloat = -tileRect.height
                        while d < tileRect.width + tileRect.height {
                            hatch.move(to: CGPoint(x: tileRect.minX + d, y: tileRect.minY))
                            hatch.addLine(to: CGPoint(x: tileRect.minX + d + tileRect.height, y: tileRect.maxY))
                            d += 12
                        }
                        ctx.drawLayer { layer in
                            layer.clip(to: Path(tileRect))
                            layer.stroke(hatch, with: .color(.white.opacity(0.35)), lineWidth: 1.1)
                        }
                    }

                    if min(tw, th) >= 42 {
                        let badge = L10n.rowCol(r + 1, c + 1)
                        let text = Text(badge)
                            .font(.system(size: min(10, max(8, min(tw, th) * 0.12)), weight: .bold))
                            .foregroundColor(.white.opacity(isExcluded ? 0.55 : 0.94))
                        let resolved = ctx.resolve(text)
                        let ts = resolved.measure(in: CGSize(width: 80, height: 20))
                        let pill = CGRect(x: tx + 5, y: ty + 5, width: ts.width + 8, height: ts.height + 4)
                        ctx.fill(Path(roundedRect: pill, cornerRadius: 4), with: .color(Color.black.opacity(0.56)))
                        ctx.draw(resolved, at: CGPoint(x: pill.midX, y: pill.midY), anchor: .center)
                    }
                }
            }

            // Dual-contrast interior cut lines (visible on both dark and white photos)
            var gridPath = Path()
            for c in 1..<geom.cols {
                let lx = Double(c) * stepW
                gridPath.move(to: CGPoint(x: lx, y: 0))
                gridPath.addLine(to: CGPoint(x: lx, y: totalRect.height))
            }
            for r in 1..<geom.rows {
                let ly = Double(r) * stepH
                gridPath.move(to: CGPoint(x: 0, y: ly))
                gridPath.addLine(to: CGPoint(x: totalRect.width, y: ly))
            }
            ctx.stroke(gridPath, with: .color(.white.opacity(0.68)), lineWidth: 1.6)
            ctx.stroke(gridPath, with: .color(.black.opacity(0.72)), lineWidth: 0.8)
        }
        .frame(width: totalRect.width, height: totalRect.height)
    }

    private struct CanvasLayout {
        let posterRect: CGRect
        let pxPerMM: Double
    }

    private func computeCanvasLayout(in size: CGSize) -> CanvasLayout {
        guard let geom = viewModel.geometry else {
            return CanvasLayout(posterRect: .zero, pxPerMM: 1.0)
        }
        let padTop: CGFloat = 56
        let padBot: CGFloat = 18
        let padSide: CGFloat = 20
        let availW = max(80.0, Double(size.width - padSide * 2))
        let availH = max(80.0, Double(size.height - padTop - padBot))

        let totalW = max(geom.posterWMM, geom.gridWMM)
        let totalH = max(geom.posterHMM, geom.gridHMM)

        let targetW = availW * (viewModel.config.showSilhouette ? 0.64 : 0.90)
        let targetH = availH * 0.80
        let baseScale = min(targetW / max(1.0, totalW), targetH / max(1.0, totalH))
        let pxPerMM = baseScale * Double(zoom)

        let gw = totalW * pxPerMM
        let gh = totalH * pxPerMM

        let shiftRight = viewModel.config.showSilhouette ? min(availW * 0.14, max(16.0, (availW - gw) * 0.28)) : 0.0
        let px = (Double(size.width) - gw) * 0.5 + shiftRight + Double(pan.width)
        let py = Double(padTop) + (availH - gh) * 0.5 + Double(pan.height)
        return CanvasLayout(posterRect: CGRect(x: px, y: py, width: gw, height: gh), pxPerMM: pxPerMM)
    }

    // MARK: - Interactive Touch Crop Overlay

    private func cropCanvas(in size: CGSize, sourceImage: UIImage) -> some View {
        let padTop: CGFloat = 54
        let padSide: CGFloat = 24
        let availW = max(80, size.width - padSide * 2)
        let availH = max(80, size.height - padTop - 24)
        let aspect = sourceImage.size.width / max(1, sourceImage.size.height)
        let drawW = min(availW, availH * aspect)
        let drawH = drawW / max(0.01, aspect)
        let imgRect = CGRect(
            x: (size.width - drawW) * 0.5,
            y: padTop + (availH - drawH) * 0.5,
            width: drawW,
            height: drawH
        )
        let crop = viewModel.config.crop
        let cx0 = imgRect.minX + crop.x0 * imgRect.width
        let cy0 = imgRect.minY + crop.y0 * imgRect.height
        let cx1 = imgRect.minX + crop.x1 * imgRect.width
        let cy1 = imgRect.minY + crop.y1 * imgRect.height
        let cropRect = CGRect(x: cx0, y: cy0, width: cx1 - cx0, height: cy1 - cy0)
        let accent = themeManager.primaryAccent

        return ZStack {
            Image(uiImage: sourceImage)
                .resizable()
                .frame(width: imgRect.width, height: imgRect.height)
                .position(x: imgRect.midX, y: imgRect.midY)

            // Mask exterior cleanly
            Canvas { ctx, canvasSize in
                var full = Path(CGRect(origin: .zero, size: canvasSize))
                full.addRect(cropRect)
                ctx.fill(full, with: .color(Color.black.opacity(0.55)), style: FillStyle(eoFill: true))

                // Rule of thirds hairlines
                var thirds = Path()
                for f in [1.0 / 3.0, 2.0 / 3.0] {
                    thirds.move(to: CGPoint(x: cropRect.minX + cropRect.width * f, y: cropRect.minY))
                    thirds.addLine(to: CGPoint(x: cropRect.minX + cropRect.width * f, y: cropRect.maxY))
                    thirds.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + cropRect.height * f))
                    thirds.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + cropRect.height * f))
                }
                ctx.stroke(thirds, with: .color(.white.opacity(0.45)), lineWidth: 0.8)
                ctx.stroke(Path(cropRect), with: .color(accent), lineWidth: 2.2)
            }
            .allowsHitTesting(false)

            // 4 tactile corner handles
            ForEach([("tl", CGPoint(x: cx0, y: cy0)), ("tr", CGPoint(x: cx1, y: cy0)), ("bl", CGPoint(x: cx0, y: cy1)), ("br", CGPoint(x: cx1, y: cy1))], id: \.0) { id, pt in
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(accent, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.25), radius: 3)
                    .position(pt)
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                if activeCropHandle != id {
                                    activeCropHandle = id
                                    dragStartCrop = viewModel.config.crop
                                }
                                let dx = Double(val.translation.width / max(1, imgRect.width))
                                let dy = Double(val.translation.height / max(1, imgRect.height))
                                var next = dragStartCrop
                                let minSpan = 0.10
                                if id.contains("l") { next.x0 = max(0, min(next.x1 - minSpan, next.x0 + dx)) }
                                if id.contains("r") { next.x1 = min(1, max(next.x0 + minSpan, next.x1 + dx)) }
                                if id.contains("t") { next.y0 = max(0, min(next.y1 - minSpan, next.y0 + dy)) }
                                if id.contains("b") { next.y1 = min(1, max(next.y0 + minSpan, next.y1 + dy)) }
                                viewModel.config.crop = next
                            }
                            .onEnded { _ in
                                activeCropHandle = nil
                                viewModel.config.excludedTiles.removeAll()
                                viewModel.recomputeGeometryOnly()
                            }
                    )
            }
        }
    }

    // MARK: - Editorial Scale Reference Drawings (Human 180cm / Doorway+Sofa 210cm / House 6m)

    private func drawHumanSilhouette(
        ctx: inout GraphicsContext,
        feetX: Double,
        feetY: Double,
        heightPx: Double,
        color: Color,
        showRuler: Bool
    ) {
        guard heightPx >= 16 else { return }
        let s = heightPx / 180.0

        var path = Path()
        // Sculpted head + relaxed editorial standing body in a unified path (zero double-alpha seam!)
        path.move(to: CGPoint(x: feetX, y: feetY - 180.0 * s))
        path.addCurve(to: CGPoint(x: feetX + 9.0 * s, y: feetY - 169.0 * s),
                      control1: CGPoint(x: feetX + 6.2 * s, y: feetY - 180.0 * s),
                      control2: CGPoint(x: feetX + 9.6 * s, y: feetY - 175.4 * s))
        path.addCurve(to: CGPoint(x: feetX + 4.3 * s, y: feetY - 159.0 * s),
                      control1: CGPoint(x: feetX + 8.6 * s, y: feetY - 163.8 * s),
                      control2: CGPoint(x: feetX + 6.4 * s, y: feetY - 160.2 * s))
        // Right shoulder -> right arm -> waist -> legs -> left arm -> left shoulder -> head
        path.addCurve(to: CGPoint(x: feetX + 14.2 * s, y: feetY - 147.8 * s),
                      control1: CGPoint(x: feetX + 4.6 * s, y: feetY - 154.0 * s),
                      control2: CGPoint(x: feetX + 6.4 * s, y: feetY - 150.5 * s))
        path.addCurve(to: CGPoint(x: feetX + 24.4 * s, y: feetY - 133.5 * s),
                      control1: CGPoint(x: feetX + 20.4 * s, y: feetY - 145.8 * s),
                      control2: CGPoint(x: feetX + 23.4 * s, y: feetY - 142.0 * s))
        path.addCurve(to: CGPoint(x: feetX + 26.4 * s, y: feetY - 97.0 * s),
                      control1: CGPoint(x: feetX + 25.6 * s, y: feetY - 122.5 * s),
                      control2: CGPoint(x: feetX + 26.8 * s, y: feetY - 110.0 * s))
        path.addCurve(to: CGPoint(x: feetX + 23.4 * s, y: feetY - 83.0 * s),
                      control1: CGPoint(x: feetX + 26.2 * s, y: feetY - 89.0 * s),
                      control2: CGPoint(x: feetX + 25.4 * s, y: feetY - 84.0 * s))
        path.addCurve(to: CGPoint(x: feetX + 19.6 * s, y: feetY - 91.2 * s),
                      control1: CGPoint(x: feetX + 21.4 * s, y: feetY - 82.2 * s),
                      control2: CGPoint(x: feetX + 20.0 * s, y: feetY - 85.0 * s))
        path.addCurve(to: CGPoint(x: feetX + 16.6 * s, y: feetY - 130.5 * s),
                      control1: CGPoint(x: feetX + 19.2 * s, y: feetY - 103.0 * s),
                      control2: CGPoint(x: feetX + 18.0 * s, y: feetY - 118.0 * s))
        path.addCurve(to: CGPoint(x: feetX + 14.8 * s, y: feetY - 101.2 * s),
                      control1: CGPoint(x: feetX + 15.6 * s, y: feetY - 119.5 * s),
                      control2: CGPoint(x: feetX + 14.2 * s, y: feetY - 109.5 * s))
        path.addCurve(to: CGPoint(x: feetX + 16.0 * s, y: feetY - 73.5 * s),
                      control1: CGPoint(x: feetX + 16.2 * s, y: feetY - 93.5 * s),
                      control2: CGPoint(x: feetX + 16.6 * s, y: feetY - 85.5 * s))
        path.addCurve(to: CGPoint(x: feetX + 14.4 * s, y: feetY - 16.5 * s),
                      control1: CGPoint(x: feetX + 15.6 * s, y: feetY - 56.0 * s),
                      control2: CGPoint(x: feetX + 14.8 * s, y: feetY - 36.0 * s))
        path.addCurve(to: CGPoint(x: feetX + 17.4 * s, y: feetY - 1.5 * s),
                      control1: CGPoint(x: feetX + 14.8 * s, y: feetY - 8.5 * s),
                      control2: CGPoint(x: feetX + 16.6 * s, y: feetY - 3.5 * s))
        path.addCurve(to: CGPoint(x: feetX + 8.4 * s, y: feetY - 2.4 * s),
                      control1: CGPoint(x: feetX + 17.6 * s, y: feetY + 0.2 * s),
                      control2: CGPoint(x: feetX + 9.5 * s, y: feetY + 0.3 * s))
        path.addCurve(to: CGPoint(x: feetX + 4.0 * s, y: feetY - 66.0 * s),
                      control1: CGPoint(x: feetX + 7.6 * s, y: feetY - 18.0 * s),
                      control2: CGPoint(x: feetX + 6.2 * s, y: feetY - 42.0 * s))
        path.addCurve(to: CGPoint(x: feetX, y: feetY - 84.6 * s),
                      control1: CGPoint(x: feetX + 2.5 * s, y: feetY - 77.5 * s),
                      control2: CGPoint(x: feetX + 1.2 * s, y: feetY - 84.0 * s))
        path.addCurve(to: CGPoint(x: feetX - 3.4 * s, y: feetY - 67.0 * s),
                      control1: CGPoint(x: feetX - 1.0 * s, y: feetY - 84.0 * s),
                      control2: CGPoint(x: feetX - 2.2 * s, y: feetY - 78.0 * s))
        path.addCurve(to: CGPoint(x: feetX - 6.8 * s, y: feetY - 2.5 * s),
                      control1: CGPoint(x: feetX - 5.6 * s, y: feetY - 42.0 * s),
                      control2: CGPoint(x: feetX - 6.2 * s, y: feetY - 18.0 * s))
        path.addCurve(to: CGPoint(x: feetX - 15.6 * s, y: feetY - 1.2 * s),
                      control1: CGPoint(x: feetX - 7.8 * s, y: feetY + 0.3 * s),
                      control2: CGPoint(x: feetX - 16.0 * s, y: feetY + 0.2 * s))
        path.addCurve(to: CGPoint(x: feetX - 13.6 * s, y: feetY - 16.0 * s),
                      control1: CGPoint(x: feetX - 14.8 * s, y: feetY - 3.0 * s),
                      control2: CGPoint(x: feetX - 13.2 * s, y: feetY - 8.0 * s))
        path.addCurve(to: CGPoint(x: feetX - 15.8 * s, y: feetY - 73.0 * s),
                      control1: CGPoint(x: feetX - 14.4 * s, y: feetY - 35.0 * s),
                      control2: CGPoint(x: feetX - 15.0 * s, y: feetY - 55.0 * s))
        path.addCurve(to: CGPoint(x: feetX - 14.8 * s, y: feetY - 101.0 * s),
                      control1: CGPoint(x: feetX - 16.6 * s, y: feetY - 85.0 * s),
                      control2: CGPoint(x: feetX - 16.2 * s, y: feetY - 93.0 * s))
        path.addCurve(to: CGPoint(x: feetX - 16.6 * s, y: feetY - 130.5 * s),
                      control1: CGPoint(x: feetX - 14.2 * s, y: feetY - 109.5 * s),
                      control2: CGPoint(x: feetX - 15.6 * s, y: feetY - 119.5 * s))
        path.addCurve(to: CGPoint(x: feetX - 18.5 * s, y: feetY - 91.5 * s),
                      control1: CGPoint(x: feetX - 17.8 * s, y: feetY - 118.0 * s),
                      control2: CGPoint(x: feetX - 19.0 * s, y: feetY - 103.0 * s))
        path.addCurve(to: CGPoint(x: feetX - 21.6 * s, y: feetY - 82.6 * s),
                      control1: CGPoint(x: feetX - 18.2 * s, y: feetY - 85.2 * s),
                      control2: CGPoint(x: feetX - 19.4 * s, y: feetY - 82.0 * s))
        path.addCurve(to: CGPoint(x: feetX - 25.6 * s, y: feetY - 96.0 * s),
                      control1: CGPoint(x: feetX - 23.8 * s, y: feetY - 83.5 * s),
                      control2: CGPoint(x: feetX - 24.8 * s, y: feetY - 88.5 * s))
        path.addCurve(to: CGPoint(x: feetX - 24.4 * s, y: feetY - 133.5 * s),
                      control1: CGPoint(x: feetX - 26.8 * s, y: feetY - 109.0 * s),
                      control2: CGPoint(x: feetX - 25.6 * s, y: feetY - 122.0 * s))
        path.addCurve(to: CGPoint(x: feetX - 14.2 * s, y: feetY - 147.8 * s),
                      control1: CGPoint(x: feetX - 23.4 * s, y: feetY - 142.0 * s),
                      control2: CGPoint(x: feetX - 20.4 * s, y: feetY - 145.8 * s))
        path.addCurve(to: CGPoint(x: feetX - 4.3 * s, y: feetY - 159.0 * s),
                      control1: CGPoint(x: feetX - 6.4 * s, y: feetY - 150.5 * s),
                      control2: CGPoint(x: feetX - 4.6 * s, y: feetY - 154.0 * s))
        path.addCurve(to: CGPoint(x: feetX - 9.0 * s, y: feetY - 169.2 * s),
                      control1: CGPoint(x: feetX - 6.4 * s, y: feetY - 160.2 * s),
                      control2: CGPoint(x: feetX - 8.6 * s, y: feetY - 163.8 * s))
        path.addCurve(to: CGPoint(x: feetX, y: feetY - 180.0 * s),
                      control1: CGPoint(x: feetX - 9.5 * s, y: feetY - 175.6 * s),
                      control2: CGPoint(x: feetX - 6.2 * s, y: feetY - 180.0 * s))
        path.closeSubpath()

        ctx.fill(path, with: .color(color))

        if showRuler && heightPx >= 64 {
            let rx = feetX - 33.0 * s
            var ruler = Path()
            ruler.move(to: CGPoint(x: rx, y: feetY))
            ruler.addLine(to: CGPoint(x: rx, y: feetY - 180.0 * s))
            ruler.move(to: CGPoint(x: rx - 3.5, y: feetY))
            ruler.addLine(to: CGPoint(x: rx + 3.5, y: feetY))
            ruler.move(to: CGPoint(x: rx - 3.5, y: feetY - 180.0 * s))
            ruler.addLine(to: CGPoint(x: rx + 3.5, y: feetY - 180.0 * s))
            ctx.stroke(ruler, with: .color(color.opacity(1.5)), lineWidth: 1.0)

            let lbl = Text(L10n.tr("human_scale_label"))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color.opacity(1.8))
            ctx.draw(lbl, at: CGPoint(x: feetX, y: feetY + 11), anchor: .center)
        }
    }

    private func drawRoomWall(
        ctx: inout GraphicsContext,
        anchorRightX: Double,
        floorY: Double,
        pxPerCM: Double,
        color: Color
    ) {
        let doorH = 210.0 * pxPerCM
        let doorW = 88.0 * pxPerCM
        guard doorH >= 24 else { return }

        let dx = anchorRightX - doorW - 18.0 * pxPerCM
        let dy = floorY - doorH
        let doorRect = CGRect(x: dx, y: dy, width: doorW, height: doorH)

        var floor = Path()
        floor.move(to: CGPoint(x: dx - 165.0 * pxPerCM, y: floorY))
        floor.addLine(to: CGPoint(x: anchorRightX + 24, y: floorY))
        ctx.stroke(floor, with: .color(color.opacity(1.4)), lineWidth: 1.0)

        ctx.fill(Path(doorRect), with: .color(color.opacity(0.6)))
        ctx.stroke(Path(doorRect), with: .color(color.opacity(1.5)), lineWidth: 1.3)

        // Minimalist sofa
        let sofaW = 135.0 * pxPerCM
        let sofaH = 78.0 * pxPerCM
        let sx = dx - sofaW - 16.0 * pxPerCM
        ctx.fill(Path(CGRect(x: sx + 8 * pxPerCM, y: floorY - sofaH, width: sofaW - 16 * pxPerCM, height: sofaH * 0.55)), with: .color(color.opacity(0.85)))
        ctx.fill(Path(CGRect(x: sx, y: floorY - sofaH * 0.62, width: sofaW, height: sofaH * 0.48)), with: .color(color.opacity(0.85)))

        drawHumanSilhouette(ctx: &ctx, feetX: dx + doorW * 0.45, feetY: floorY, heightPx: 180.0 * pxPerCM, color: color.opacity(1.35), showRuler: false)

        let lbl = Text(L10n.tr("scale_door_label"))
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color.opacity(1.8))
        ctx.draw(lbl, at: CGPoint(x: doorRect.midX, y: floorY + 11), anchor: .center)
    }

    private func drawHouseFacade(
        ctx: inout GraphicsContext,
        anchorRightX: Double,
        floorY: Double,
        pxPerCM: Double,
        color: Color
    ) {
        let houseH = 600.0 * pxPerCM
        let houseW = 460.0 * pxPerCM
        guard houseH >= 24 else { return }

        let hx = anchorRightX - houseW - 18.0 * pxPerCM
        let eaveY = floorY - houseH * 0.74
        let roofY = floorY - houseH

        var house = Path()
        house.move(to: CGPoint(x: hx, y: floorY))
        house.addLine(to: CGPoint(x: hx, y: eaveY))
        house.addLine(to: CGPoint(x: hx + houseW * 0.5, y: roofY))
        house.addLine(to: CGPoint(x: hx + houseW, y: eaveY))
        house.addLine(to: CGPoint(x: hx + houseW, y: floorY))
        house.closeSubpath()
        ctx.fill(house, with: .color(color.opacity(0.68)))

        let dw = 88.0 * pxPerCM
        let dh = 210.0 * pxPerCM
        ctx.fill(Path(CGRect(x: hx + (houseW - dw) * 0.5, y: floorY - dh, width: dw, height: dh)), with: .color(.white.opacity(0.18)))

        drawHumanSilhouette(ctx: &ctx, feetX: hx + houseW * 0.5, feetY: floorY, heightPx: 180.0 * pxPerCM, color: color.opacity(1.5), showRuler: false)

        let lbl = Text(L10n.tr("scale_house_label"))
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color.opacity(1.8))
        ctx.draw(lbl, at: CGPoint(x: hx + houseW * 0.5, y: floorY + 11), anchor: .center)
    }
}
