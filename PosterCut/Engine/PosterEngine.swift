import UIKit
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

extension UIImage {
    /// Normalize EXIF orientation into an upright `.up` CGImage-backed UIImage preserving full resolution.
    func normalizedUp() -> UIImage {
        if imageOrientation == .up, cgImage != nil {
            return self
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

struct HalftoneSampleBuffer: Sendable {
    let width: Int
    let height: Int
    let rgba: [UInt8]
}

struct PreparedPrintJob: @unchecked Sendable {
    let config: PosterConfig
    let croppedImage: UIImage
    let geom: PosterGeometry
    let tiles: [TileRect]
    let sampleBuffer: HalftoneSampleBuffer?
    let hasAssemblyMap: Bool

    var totalPages: Int {
        tiles.count + (hasAssemblyMap ? 1 : 0)
    }

    func pageLabel(for index: Int) -> String {
        if index < tiles.count {
            let t = tiles[index]
            return L10n.rowCol(t.row + 1, t.col + 1)
        }
        return L10n.tr("assembly_map_short")
    }
}

enum PosterEngineError: LocalizedError {
    case noActiveSheets
    case imageUnavailable

    var errorDescription: String? {
        switch self {
        case .noActiveSheets: return L10n.tr("err_no_active_sheets")
        case .imageUnavailable: return L10n.tr("err_load_image")
        }
    }
}

enum PosterEngine {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Built-in Cool Aurora Glacier Sample Artwork (Zero Orange)

    static func createSampleArtwork(width: Int = 1800, height: Int = 2250) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { rendererCtx in
            let ctx = rendererCtx.cgContext
            let w = size.width
            let h = size.height
            let cs = CGColorSpaceCreateDeviceRGB()

            // Deep arctic sky gradient
            if let sky = CGGradient(
                colorsSpace: cs,
                colors: [
                    UIColor(red: 0.04, green: 0.08, blue: 0.19, alpha: 1).cgColor,
                    UIColor(red: 0.08, green: 0.18, blue: 0.36, alpha: 1).cgColor,
                    UIColor(red: 0.14, green: 0.42, blue: 0.58, alpha: 1).cgColor,
                    UIColor(red: 0.62, green: 0.87, blue: 0.94, alpha: 1).cgColor,
                ] as CFArray,
                locations: [0.0, 0.45, 0.80, 1.0]
            ) {
                ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: h * 0.68), options: [.drawsAfterEndLocation])
            }

            // Flowing aurora borealis curtains
            let ribbons: [(CGFloat, UIColor, CGFloat)] = [
                (0.24, UIColor(red: 0.18, green: 0.92, blue: 0.78, alpha: 0.42), 0.11),
                (0.32, UIColor(red: 0.32, green: 0.74, blue: 0.99, alpha: 0.38), 0.14),
                (0.18, UIColor(red: 0.50, green: 0.96, blue: 0.86, alpha: 0.28), 0.08),
            ]
            for (yOff, color, amp) in ribbons {
                ctx.saveGState()
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: h * (yOff + 0.08)))
                path.addCurve(
                    to: CGPoint(x: w, y: h * (yOff - 0.06)),
                    control1: CGPoint(x: w * 0.28, y: h * (yOff - amp)),
                    control2: CGPoint(x: w * 0.62, y: h * (yOff + amp))
                )
                path.addLine(to: CGPoint(x: w, y: h * (yOff + 0.16)))
                path.addCurve(
                    to: CGPoint(x: 0, y: h * (yOff + 0.22)),
                    control1: CGPoint(x: w * 0.64, y: h * (yOff + amp + 0.14)),
                    control2: CGPoint(x: w * 0.30, y: h * (yOff - amp + 0.14))
                )
                path.closeSubpath()
                ctx.addPath(path)
                ctx.setFillColor(color.cgColor)
                ctx.fillPath()
                ctx.restoreGState()
            }

            // Moon + icy halo
            let moonCenter = CGPoint(x: w * 0.50, y: h * 0.35)
            if let halo = CGGradient(
                colorsSpace: cs,
                colors: [
                    UIColor(red: 0.88, green: 0.97, blue: 1.0, alpha: 0.55).cgColor,
                    UIColor(red: 0.42, green: 0.82, blue: 0.98, alpha: 0.18).cgColor,
                    UIColor(red: 0.20, green: 0.55, blue: 0.90, alpha: 0.0).cgColor,
                ] as CFArray,
                locations: [0.0, 0.55, 1.0]
            ) {
                ctx.drawRadialGradient(halo, startCenter: moonCenter, startRadius: w * 0.05, endCenter: moonCenter, endRadius: w * 0.25, options: [])
            }
            ctx.setFillColor(UIColor(red: 0.90, green: 0.96, blue: 1.0, alpha: 1.0).cgColor)
            let moonR = w * 0.125
            ctx.fillEllipse(in: CGRect(x: moonCenter.x - moonR, y: moonCenter.y - moonR, width: moonR * 2, height: moonR * 2))

            // Distant glacier peaks
            let backMt = CGMutablePath()
            backMt.move(to: CGPoint(x: 0, y: h * 0.66))
            backMt.addLine(to: CGPoint(x: w * 0.17, y: h * 0.46))
            backMt.addLine(to: CGPoint(x: w * 0.35, y: h * 0.56))
            backMt.addLine(to: CGPoint(x: w * 0.56, y: h * 0.40))
            backMt.addLine(to: CGPoint(x: w * 0.77, y: h * 0.53))
            backMt.addLine(to: CGPoint(x: w * 0.91, y: h * 0.45))
            backMt.addLine(to: CGPoint(x: w, y: h * 0.54))
            backMt.addLine(to: CGPoint(x: w, y: h))
            backMt.addLine(to: CGPoint(x: 0, y: h))
            backMt.closeSubpath()
            ctx.addPath(backMt)
            ctx.setFillColor(UIColor(red: 0.20, green: 0.33, blue: 0.52, alpha: 1).cgColor)
            ctx.fillPath()

            // Snow facets
            let snow = CGMutablePath()
            snow.move(to: CGPoint(x: w * 0.56, y: h * 0.40))
            snow.addLine(to: CGPoint(x: w * 0.46, y: h * 0.49))
            snow.addLine(to: CGPoint(x: w * 0.54, y: h * 0.52))
            snow.addLine(to: CGPoint(x: w * 0.62, y: h * 0.47))
            snow.closeSubpath()
            ctx.addPath(snow)
            ctx.setFillColor(UIColor(red: 0.85, green: 0.94, blue: 0.99, alpha: 1).cgColor)
            ctx.fillPath()

            // Mid mountain range
            let midMt = CGMutablePath()
            midMt.move(to: CGPoint(x: 0, y: h * 0.58))
            midMt.addLine(to: CGPoint(x: w * 0.24, y: h * 0.49))
            midMt.addLine(to: CGPoint(x: w * 0.45, y: h * 0.64))
            midMt.addLine(to: CGPoint(x: w * 0.72, y: h * 0.50))
            midMt.addLine(to: CGPoint(x: w, y: h * 0.62))
            midMt.addLine(to: CGPoint(x: w, y: h))
            midMt.addLine(to: CGPoint(x: 0, y: h))
            midMt.closeSubpath()
            ctx.addPath(midMt)
            ctx.setFillColor(UIColor(red: 0.10, green: 0.21, blue: 0.36, alpha: 1).cgColor)
            ctx.fillPath()

            // Reflective arctic lake
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: h * 0.66, width: w, height: h * 0.34))
            if let lake = CGGradient(
                colorsSpace: cs,
                colors: [
                    UIColor(red: 0.08, green: 0.24, blue: 0.39, alpha: 1).cgColor,
                    UIColor(red: 0.06, green: 0.16, blue: 0.29, alpha: 1).cgColor,
                    UIColor(red: 0.04, green: 0.09, blue: 0.19, alpha: 1).cgColor,
                ] as CFArray,
                locations: [0.0, 0.45, 1.0]
            ) {
                ctx.drawLinearGradient(lake, start: CGPoint(x: 0, y: h * 0.66), end: CGPoint(x: 0, y: h), options: [])
            }
            ctx.restoreGState()

            // Moonlight shimmer bars
            for k in 0..<14 {
                let frac = CGFloat(k) / 13.0
                let ry = h * (0.685 + frac * 0.25)
                let rw = w * (0.32 * (1.0 - frac * 0.62))
                let rh = h * (0.008 + frac * 0.004)
                ctx.setFillColor(UIColor(red: 0.62, green: 0.94, blue: 0.99, alpha: 0.72 - frac * 0.42).cgColor)
                ctx.fill(CGRect(x: moonCenter.x - rw / 2, y: ry, width: rw, height: rh))
            }

            // Pine silhouettes
            ctx.setFillColor(UIColor(red: 0.04, green: 0.08, blue: 0.15, alpha: 1).cgColor)
            let trees: [(CGFloat, CGFloat, CGFloat)] = [
                (0.09, 0.75, 0.11), (0.16, 0.77, 0.13), (0.24, 0.81, 0.10),
                (0.77, 0.79, 0.11), (0.85, 0.75, 0.14), (0.93, 0.76, 0.12),
            ]
            for (tx, ty, th) in trees {
                let cxT = w * tx
                let baseY = h * (ty + th * 0.35)
                let treeH = h * th
                for tier in 0..<3 {
                    let tw = treeH * (0.34 - CGFloat(tier) * 0.06)
                    let topY = baseY - treeH * (0.55 + CGFloat(tier) * 0.22)
                    let botY = baseY - treeH * (CGFloat(tier) * 0.20)
                    let tri = CGMutablePath()
                    tri.move(to: CGPoint(x: cxT, y: topY))
                    tri.addLine(to: CGPoint(x: cxT - tw, y: botY))
                    tri.addLine(to: CGPoint(x: cxT + tw, y: botY))
                    tri.closeSubpath()
                    ctx.addPath(tri)
                    ctx.fillPath()
                }
            }

            // Museum inner frame
            let pad = w * 0.038
            ctx.setStrokeColor(UIColor(red: 0.94, green: 0.98, blue: 1.0, alpha: 0.88).cgColor)
            ctx.setLineWidth(w * 0.004)
            ctx.stroke(CGRect(x: pad, y: pad, width: w - 2 * pad, height: h - 2 * pad))
        }
    }

    // MARK: - Geometric Transforms, Cropping & Photo Enhancements

    static func croppedDimensions(for rawImage: UIImage, config: PosterConfig) -> (w: Int, h: Int) {
        let baseW = rawImage.cgImage?.width ?? Int(rawImage.size.width * rawImage.scale)
        let baseH = rawImage.cgImage?.height ?? Int(rawImage.size.height * rawImage.scale)
        let rot = ((config.rotationDeg % 360) + 360) % 360
        let w = (rot == 90 || rot == 270) ? baseH : baseW
        let h = (rot == 90 || rot == 270) ? baseW : baseH
        let x0 = max(0.0, min(0.98, config.crop.x0))
        let y0 = max(0.0, min(0.98, config.crop.y0))
        let x1 = max(x0 + 0.02, min(1.0, config.crop.x1))
        let y1 = max(y0 + 0.02, min(1.0, config.crop.y1))
        return (max(1, Int(((x1 - x0) * Double(w)).rounded())), max(1, Int(((y1 - y0) * Double(h)).rounded())))
    }

    static func applyGeometricTransforms(_ image: UIImage, config: PosterConfig) -> UIImage {
        let rot = ((config.rotationDeg % 360) + 360) % 360
        if rot == 0 && !config.flipH && !config.flipV {
            return image
        }
        guard let cg = image.cgImage else { return image }
        let srcW = CGFloat(cg.width)
        let srcH = CGFloat(cg.height)
        let dstSize = (rot == 90 || rot == 270) ? CGSize(width: srcH, height: srcW) : CGSize(width: srcW, height: srcH)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: dstSize, format: format)
        return renderer.image { rctx in
            let ctx = rctx.cgContext
            ctx.translateBy(x: dstSize.width * 0.5, y: dstSize.height * 0.5)
            ctx.scaleBy(x: config.flipH ? -1.0 : 1.0, y: config.flipV ? -1.0 : 1.0)
            ctx.rotate(by: CGFloat(rot) * .pi / 180.0)
            UIImage(cgImage: cg).draw(in: CGRect(x: -srcW * 0.5, y: -srcH * 0.5, width: srcW, height: srcH))
        }
    }

    static func applyCropAndEnhancements(
        _ rawImage: UIImage,
        config: PosterConfig,
        applyEnhancements: Bool = true
    ) -> UIImage {
        var working = applyGeometricTransforms(rawImage, config: config)

        if !config.crop.isFull, let cg = working.cgImage {
            let w = Double(cg.width)
            let h = Double(cg.height)
            let x0 = max(0.0, min(0.98, config.crop.x0))
            let y0 = max(0.0, min(0.98, config.crop.y0))
            let x1 = max(x0 + 0.02, min(1.0, config.crop.x1))
            let y1 = max(y0 + 0.02, min(1.0, config.crop.y1))
            let rect = CGRect(
                x: floor(x0 * w),
                y: floor(y0 * h),
                width: max(1.0, ceil((x1 - x0) * w)),
                height: max(1.0, ceil((y1 - y0) * h))
            ).intersection(CGRect(x: 0, y: 0, width: w, height: h))
            if let croppedCG = cg.cropping(to: rect) {
                working = UIImage(cgImage: croppedCG, scale: 1.0, orientation: .up)
            }
        }

        if applyEnhancements && !config.style.isHalftone {
            let needsFilter = config.grayscaleClean || abs(config.brightness) > 0.005 || abs(config.contrast) > 0.005 || config.sharpness > 0.005
            if needsFilter, let cg = working.cgImage {
                var ci = CIImage(cgImage: cg)
                if config.grayscaleClean || abs(config.brightness) > 0.005 || abs(config.contrast) > 0.005 {
                    let controls = CIFilter.colorControls()
                    controls.inputImage = ci
                    controls.brightness = Float(config.brightness * 0.55)
                    controls.contrast = Float(1.0 + config.contrast)
                    controls.saturation = config.grayscaleClean ? 0.0 : 1.0
                    if let out = controls.outputImage { ci = out }
                }
                if config.sharpness > 0.005 {
                    let sharp = CIFilter.sharpenLuminance()
                    sharp.inputImage = ci
                    sharp.sharpness = Float(config.sharpness * 0.9)
                    if let out = sharp.outputImage { ci = out }
                }
                if let outCG = ciContext.createCGImage(ci, from: ci.extent) {
                    working = UIImage(cgImage: outCG, scale: 1.0, orientation: .up)
                }
            }
        }

        return working
    }

    // MARK: - Vector Halftone Sampler & CoreGraphics Vector Renderer

    private static func shouldInvertDots(_ config: PosterConfig) -> Bool {
        guard config.bgMode == .single else { return false }
        let bg = parseHexRGB(config.bgHex)
        let bgLum = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
        if bgLum >= 0.45 { return false }
        if config.colorMode == .multicolor { return true }
        if config.colorMode == .single {
            let fg = parseHexRGB(config.rasterHex)
            let fgLum = 0.299 * fg.r + 0.587 * fg.g + 0.114 * fg.b
            return fgLum > bgLum + 0.12
        }
        return false
    }

    static func prepareHalftoneSampleBuffer(
        croppedImage: UIImage,
        posterWMM: Double,
        posterHMM: Double,
        dotSizeMM: Double
    ) -> HalftoneSampleBuffer {
        let srcW = croppedImage.cgImage?.width ?? Int(croppedImage.size.width)
        let srcH = croppedImage.cgImage?.height ?? Int(croppedImage.size.height)
        let targetW = max(8, min(srcW, Int(((posterWMM / max(1.0, dotSizeMM)) * 2.5).rounded())))
        let targetH = max(8, min(srcH, Int(((posterHMM / max(1.0, dotSizeMM)) * 2.5).rounded())))

        var pixels = [UInt8](repeating: 255, count: targetW * targetH * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        pixels.withUnsafeMutableBytes { rawBuf in
            guard let basePtr = rawBuf.baseAddress,
                  let ctx = CGContext(
                    data: basePtr,
                    width: targetW,
                    height: targetH,
                    bitsPerComponent: 8,
                    bytesPerRow: targetW * 4,
                    space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return }
            ctx.interpolationQuality = .high
            // Flip so row 0 corresponds to top of image cleanly
            ctx.translateBy(x: 0, y: CGFloat(targetH))
            ctx.scaleBy(x: 1, y: -1)
            UIGraphicsPushContext(ctx)
            croppedImage.draw(in: CGRect(x: 0, y: 0, width: targetW, height: targetH))
            UIGraphicsPopContext()
        }
        return HalftoneSampleBuffer(width: targetW, height: targetH, rgba: pixels)
    }

    static func drawHalftoneRegion(
        in ctx: CGContext,
        sample: HalftoneSampleBuffer,
        config: PosterConfig,
        posterWMM: Double,
        posterHMM: Double,
        regionX0: Double,
        regionY0: Double,
        regionX1: Double,
        regionY1: Double,
        destX: Double,
        destY: Double,
        scale: Double
    ) {
        let regW = max(0.0, regionX1 - regionX0)
        let regH = max(0.0, regionY1 - regionY0)
        guard regW > 0.01 && regH > 0.01 else { return }

        ctx.saveGState()
        let clipRect = CGRect(x: destX, y: destY, width: regW * scale, height: regH * scale)
        ctx.clip(to: clipRect)

        // Background fill
        switch config.bgMode {
        case .white:
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(clipRect)
        case .single:
            let bg = parseHexRGB(config.bgHex)
            ctx.setFillColor(CGColor(srgbRed: bg.r, green: bg.g, blue: bg.b, alpha: 1.0))
            ctx.fill(clipRect)
        case .transparent:
            break
        }

        // Map poster millimeter coordinates into destination space
        ctx.translateBy(x: destX - regionX0 * scale, y: destY - regionY0 * scale)
        ctx.scaleBy(x: scale, y: scale)

        let spacing = max(1.5, config.dotSizeMM)
        let angleRad = config.gridAngle * .pi / 180.0
        let cosA = cos(angleRad)
        let sinA = sin(angleRad)
        let cxP = posterWMM * 0.5
        let cyP = posterHMM * 0.5

        let pad = spacing * 1.4
        let corners: [(Double, Double)] = [
            (regionX0 - pad - cxP, regionY0 - pad - cyP),
            (regionX1 + pad - cxP, regionY0 - pad - cyP),
            (regionX1 + pad - cxP, regionY1 + pad - cyP),
            (regionX0 - pad - cxP, regionY1 + pad - cyP),
        ]
        let us = corners.map { $0.0 * cosA + $0.1 * sinA }
        let vs = corners.map { -$0.0 * sinA + $0.1 * cosA }
        let uMin = Int(floor((us.min() ?? 0) / spacing))
        let uMax = Int(ceil((us.max() ?? 0) / spacing))
        let vMin = Int(floor((vs.min() ?? 0) / spacing))
        let vMax = Int(ceil((vs.max() ?? 0) / spacing))

        let invert = shouldInvertDots(config)
        let multicolor = config.colorMode == .multicolor
        let fgRGB: (r: Double, g: Double, b: Double) = config.colorMode == .black ? (0.04, 0.04, 0.05) : parseHexRGB(config.rasterHex)
        let fgCG = CGColor(srgbRed: fgRGB.r, green: fgRGB.g, blue: fgRGB.b, alpha: 1.0)

        let sw = sample.width
        let sh = sample.height
        let buf = sample.rgba

        @inline(__always)
        func samplePixel(xMM: Double, yMM: Double) -> (r: Double, g: Double, b: Double, strength: Double) {
            let ix = max(0, min(sw - 1, Int((xMM / posterWMM) * Double(sw - 1))))
            let iy = max(0, min(sh - 1, Int((yMM / posterHMM) * Double(sh - 1))))
            let off = (iy * sw + ix) * 4
            let r = Double(buf[off]) / 255.0
            let g = Double(buf[off + 1]) / 255.0
            let b = Double(buf[off + 2]) / 255.0
            let lum = 0.299 * r + 0.587 * g + 0.114 * b
            return (r, g, b, invert ? lum : (1.0 - lum))
        }

        if config.style == .halftoneLines {
            let stepU = spacing * 0.55
            let uStart = us.min() ?? 0
            let uEnd = us.max() ?? 0
            ctx.setLineCap(.round)
            if !multicolor { ctx.setStrokeColor(fgCG) }

            for vIdx in vMin...vMax {
                let vPos = Double(vIdx) * spacing
                var u = uStart
                while u < uEnd {
                    let uNext = u + stepU
                    let x1 = cxP + u * cosA - vPos * sinA
                    let y1 = cyP + u * sinA + vPos * cosA
                    let x2 = cxP + uNext * cosA - vPos * sinA
                    let y2 = cyP + uNext * sinA + vPos * cosA
                    u = uNext
                    if max(x1, x2) < -spacing || min(x1, x2) > posterWMM + spacing || max(y1, y2) < -spacing || min(y1, y2) > posterHMM + spacing {
                        continue
                    }
                    let p1 = samplePixel(xMM: x1, yMM: y1)
                    let p2 = samplePixel(xMM: x2, yMM: y2)
                    let st = 0.5 * (p1.strength + p2.strength)
                    if st < 0.04 { continue }
                    if multicolor {
                        ctx.setStrokeColor(CGColor(srgbRed: p1.r, green: p1.g, blue: p1.b, alpha: 1.0))
                    }
                    ctx.setLineWidth(spacing * 0.88 * st)
                    ctx.move(to: CGPoint(x: x1, y: y1))
                    ctx.addLine(to: CGPoint(x: x2, y: y2))
                    ctx.strokePath()
                }
            }
            ctx.restoreGState()
            return
        }

        if !multicolor {
            ctx.setFillColor(fgCG)
        }

        for vIdx in vMin...vMax {
            let vPos = Double(vIdx) * spacing
            for uIdx in uMin...uMax {
                let uPos = Double(uIdx) * spacing
                let x = cxP + uPos * cosA - vPos * sinA
                let y = cyP + uPos * sinA + vPos * cosA
                if x < max(-spacing * 0.5, regionX0 - spacing) || x > min(posterWMM + spacing * 0.5, regionX1 + spacing) ||
                   y < max(-spacing * 0.5, regionY0 - spacing) || y > min(posterHMM + spacing * 0.5, regionY1 + spacing) {
                    continue
                }
                let p = samplePixel(xMM: x, yMM: y)
                if p.strength <= 0.025 { continue }
                let root = sqrt(p.strength)

                if multicolor {
                    ctx.setFillColor(CGColor(srgbRed: p.r, green: p.g, blue: p.b, alpha: 1.0))
                }

                switch config.style {
                case .halftoneColor, .halftoneBW:
                    let r = 0.5 * spacing * 1.07 * root
                    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))

                case .halftoneSquares:
                    let hs = 0.48 * spacing * root
                    if abs(angleRad) > 1e-4 {
                        ctx.saveGState()
                        ctx.translateBy(x: x, y: y)
                        ctx.rotate(by: angleRad)
                        ctx.fill(CGRect(x: -hs, y: -hs, width: hs * 2, height: hs * 2))
                        ctx.restoreGState()
                    } else {
                        ctx.fill(CGRect(x: x - hs, y: y - hs, width: hs * 2, height: hs * 2))
                    }

                case .halftoneDiamonds:
                    let d = 0.64 * spacing * root
                    let dx1 = d * cosA, dy1 = d * sinA
                    let dx2 = -d * sinA, dy2 = d * cosA
                    ctx.move(to: CGPoint(x: x + dx1, y: y + dy1))
                    ctx.addLine(to: CGPoint(x: x + dx2, y: y + dy2))
                    ctx.addLine(to: CGPoint(x: x - dx1, y: y - dy1))
                    ctx.addLine(to: CGPoint(x: x - dx2, y: y - dy2))
                    ctx.closePath()
                    ctx.fillPath()

                default:
                    break
                }
            }
        }

        ctx.restoreGState()
    }

    // MARK: - Preview Image Generation (WYSIWYG)

    static func renderPreviewImage(
        rawImage: UIImage,
        config: PosterConfig,
        geom: PosterGeometry,
        maxDim: CGFloat = 960
    ) -> UIImage {
        let cropped = applyCropAndEnhancements(rawImage, config: config, applyEnhancements: !config.showOriginal)
        let w = CGFloat(cropped.cgImage?.width ?? Int(cropped.size.width))
        let h = CGFloat(cropped.cgImage?.height ?? Int(cropped.size.height))
        let ratio = min(1.0, maxDim / max(1, max(w, h)))
        let pw = max(16, Int((w * ratio).rounded()))
        let ph = max(16, Int((h * ratio).rounded()))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: pw, height: ph), format: format)

        if config.showOriginal || !config.style.isHalftone {
            return renderer.image { _ in
                cropped.draw(in: CGRect(x: 0, y: 0, width: pw, height: ph))
            }
        }

        let sample = prepareHalftoneSampleBuffer(
            croppedImage: cropped,
            posterWMM: geom.posterWMM,
            posterHMM: geom.posterHMM,
            dotSizeMM: config.dotSizeMM
        )
        let scale = Double(pw) / max(1.0, geom.posterWMM)
        return renderer.image { rctx in
            let ctx = rctx.cgContext
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
            drawHalftoneRegion(
                in: ctx,
                sample: sample,
                config: config,
                posterWMM: geom.posterWMM,
                posterHMM: geom.posterHMM,
                regionX0: 0,
                regionY0: 0,
                regionX1: geom.posterWMM,
                regionY1: geom.posterHMM,
                destX: 0,
                destY: 0,
                scale: scale
            )
        }
    }

    static func renderStyleThumbnail(style: PosterStyle, sourceThumb: UIImage, size: CGSize = CGSize(width: 112, height: 80)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        // Center-crop thumbnail to card aspect
        let sw = sourceThumb.size.width
        let sh = sourceThumb.size.height
        let targetAspect = size.width / max(1, size.height)
        let srcAspect = sw / max(1, sh)
        let drawRect: CGRect
        if srcAspect > targetAspect {
            let drawW = size.height * srcAspect
            drawRect = CGRect(x: (size.width - drawW) * 0.5, y: 0, width: drawW, height: size.height)
        } else {
            let drawH = size.width / srcAspect
            drawRect = CGRect(x: 0, y: (size.height - drawH) * 0.5, width: size.width, height: drawH)
        }

        let fitted = renderer.image { _ in
            sourceThumb.draw(in: drawRect)
        }
        if style == .original { return fitted }

        var cfg = PosterConfig()
        cfg.applyStyle(style)
        cfg.dotSizeMM = style == .halftoneLines ? 6.2 : 7.5
        if style == .halftoneLines {
            cfg.colorMode = .black
            cfg.bgMode = .white
            cfg.gridAngle = 12.0
        }
        let pH = 100.0 * Double(size.height / max(1, size.width))
        let sample = prepareHalftoneSampleBuffer(croppedImage: fitted, posterWMM: 100.0, posterHMM: pH, dotSizeMM: cfg.dotSizeMM)
        return renderer.image { rctx in
            let ctx = rctx.cgContext
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            drawHalftoneRegion(
                in: ctx,
                sample: sample,
                config: cfg,
                posterWMM: 100.0,
                posterHMM: pH,
                regionX0: 0,
                regionY0: 0,
                regionX1: 100.0,
                regionY1: pH,
                destX: 0,
                destY: 0,
                scale: Double(size.width) / 100.0
            )
        }
    }

    // MARK: - Blank Tile Detection, Guides, Assembly Map & Unified Print Job

    private static func isTileBlank(croppedImage: UIImage, geom: PosterGeometry, tile: TileRect) -> Bool {
        guard tile.hasArtwork, let cg = croppedImage.cgImage else { return true }
        let w = Double(cg.width)
        let h = Double(cg.height)
        let px0 = max(0, Int(floor(tile.artX0MM / geom.posterWMM * w)))
        let py0 = max(0, Int(floor(tile.artY0MM / geom.posterHMM * h)))
        let px1 = min(cg.width, max(px0 + 1, Int(ceil(tile.artX1MM / geom.posterWMM * w))))
        let py1 = min(cg.height, max(py0 + 1, Int(ceil(tile.artY1MM / geom.posterHMM * h))))
        guard let patch = cg.cropping(to: CGRect(x: px0, y: py0, width: px1 - px0, height: py1 - py0)) else {
            return false
        }
        let sampleSz = 32
        var bytes = [UInt8](repeating: 255, count: sampleSz * sampleSz * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        bytes.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress,
                  let ctx = CGContext(data: base, width: sampleSz, height: sampleSz, bitsPerComponent: 8, bytesPerRow: sampleSz * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.draw(patch, in: CGRect(x: 0, y: 0, width: sampleSz, height: sampleSz))
        }
        var darkCount = 0
        for i in stride(from: 0, to: bytes.count, by: 4) {
            if bytes[i] < 248 || bytes[i + 1] < 248 || bytes[i + 2] < 248 {
                darkCount += 1
            }
        }
        return darkCount <= 4
    }

    static func preparePrintJob(rawImage: UIImage, config: PosterConfig) throws -> PreparedPrintJob {
        let cropped = applyCropAndEnhancements(rawImage, config: config, applyEnhancements: true)
        let cw = cropped.cgImage?.width ?? Int(cropped.size.width)
        let ch = cropped.cgImage?.height ?? Int(cropped.size.height)
        let geom = PosterGeometry.compute(config: config, imgWPx: cw, imgHPx: ch)

        var active: [TileRect] = []
        for r in 0..<geom.rows {
            for c in 0..<geom.cols {
                if config.excludedTiles.contains(TileCoord(col: c, row: r)) { continue }
                let tile = geom.tileRect(col: c, row: r)
                if !tile.hasArtwork { continue }
                if config.skipBlankPages && isTileBlank(croppedImage: cropped, geom: geom, tile: tile) { continue }
                active.append(tile)
            }
        }
        guard !active.isEmpty else { throw PosterEngineError.noActiveSheets }

        let sampleBuf: HalftoneSampleBuffer? = config.style.isHalftone
            ? prepareHalftoneSampleBuffer(croppedImage: cropped, posterWMM: geom.posterWMM, posterHMM: geom.posterHMM, dotSizeMM: config.dotSizeMM)
            : nil

        return PreparedPrintJob(
            config: config,
            croppedImage: cropped,
            geom: geom,
            tiles: active,
            sampleBuffer: sampleBuf,
            hasAssemblyMap: config.includeAssemblyMap
        )
    }

    private static func paintOriginalSlice(
        in ctx: CGContext,
        croppedImage: UIImage,
        geom: PosterGeometry,
        tile: TileRect,
        scale: Double,
        lossless: Bool
    ) {
        guard tile.hasArtwork, let cg = croppedImage.cgImage else { return }
        let w = Double(cg.width)
        let h = Double(cg.height)

        let fx0 = (tile.artX0MM / geom.posterWMM) * w
        let fy0 = (tile.artY0MM / geom.posterHMM) * h
        let fx1 = (tile.artX1MM / geom.posterWMM) * w
        let fy1 = (tile.artY1MM / geom.posterHMM) * h

        let ix0 = max(0, Int(floor(fx0)))
        let iy0 = max(0, Int(floor(fy0)))
        let ix1 = min(cg.width, max(ix0 + 1, Int(ceil(fx1))))
        let iy1 = min(cg.height, max(iy0 + 1, Int(ceil(fy1))))

        guard let sliceCG = cg.cropping(to: CGRect(x: ix0, y: iy0, width: ix1 - ix0, height: iy1 - iy0)) else { return }

        let sliceUI: UIImage
        if !lossless, let jpg = UIImage(cgImage: sliceCG).jpegData(compressionQuality: 0.90), let dec = UIImage(data: jpg) {
            sliceUI = dec
        } else {
            sliceUI = UIImage(cgImage: sliceCG, scale: 1.0, orientation: .up)
        }

        let destX = tile.pageArtXMM * scale
        let destY = tile.pageArtYMM * scale
        let destW = tile.pageArtWMM * scale
        let destH = tile.pageArtHMM * scale

        let sx = destW / max(1e-6, fx1 - fx0)
        let sy = destH / max(1e-6, fy1 - fy0)

        let drawRect = CGRect(
            x: destX - (fx0 - Double(ix0)) * sx,
            y: destY - (fy0 - Double(iy0)) * sy,
            width: Double(ix1 - ix0) * sx,
            height: Double(iy1 - iy0) * sy
        )

        ctx.saveGState()
        ctx.clip(to: CGRect(x: destX, y: destY, width: destW, height: destH))
        ctx.interpolationQuality = .high
        UIGraphicsPushContext(ctx)
        sliceUI.draw(in: drawRect)
        UIGraphicsPopContext()
        ctx.restoreGState()
    }

    private static func drawPageGuides(
        in ctx: CGContext,
        config: PosterConfig,
        geom: PosterGeometry,
        tile: TileRect,
        pageNum: Int,
        totalPages: Int,
        scale: Double
    ) {
        let pw = geom.paperWMM * scale
        let ph = geom.paperHMM * scale
        let m = geom.marginMM * scale
        let ax = tile.pageArtXMM * scale
        let ay = tile.pageArtYMM * scale
        let aw = tile.pageArtWMM * scale
        let ah = tile.pageArtHMM * scale

        if config.cropMarks {
            ctx.saveGState()
            ctx.setStrokeColor(UIColor(white: 0.28, alpha: 1).cgColor)
            ctx.setLineWidth(max(0.4, 0.14 * scale))
            let gap = min(2.0 * scale, max(0.8 * scale, m * 0.22))
            let arm = min(6.0 * scale, max(2.8 * scale, m * 0.65))

            if m >= 1.5 * scale {
                let corners: [(Double, Double, Double, Double)] = [
                    (ax, ay, -1, -1), (ax + aw, ay, 1, -1),
                    (ax, ay + ah, -1, 1), (ax + aw, ay + ah, 1, 1),
                ]
                for (cx, cy, sx, sy) in corners {
                    ctx.move(to: CGPoint(x: cx + sx * gap, y: cy))
                    ctx.addLine(to: CGPoint(x: cx + sx * (gap + arm), y: cy))
                    ctx.move(to: CGPoint(x: cx, y: cy + sy * gap))
                    ctx.addLine(to: CGPoint(x: cx, y: cy + sy * (gap + arm)))
                }
                ctx.strokePath()

                if geom.overlapMM > 0.2 {
                    let ov = geom.overlapMM * scale
                    ctx.setStrokeColor(UIColor(red: 0.20, green: 0.45, blue: 0.85, alpha: 0.80).cgColor)
                    ctx.setLineDash(phase: 0, lengths: [1.2 * scale, 1.2 * scale])
                    if tile.col > 0 && ax + ov < ax + aw {
                        ctx.move(to: CGPoint(x: ax + ov, y: max(0, ay - gap - arm * 0.6)))
                        ctx.addLine(to: CGPoint(x: ax + ov, y: max(0, ay - gap * 0.6)))
                        ctx.move(to: CGPoint(x: ax + ov, y: min(ph, ay + ah + gap * 0.6)))
                        ctx.addLine(to: CGPoint(x: ax + ov, y: min(ph, ay + ah + gap + arm * 0.6)))
                    }
                    if tile.row > 0 && ay + ov < ay + ah {
                        ctx.move(to: CGPoint(x: max(0, ax - gap - arm * 0.6), y: ay + ov))
                        ctx.addLine(to: CGPoint(x: max(0, ax - gap * 0.6), y: ay + ov))
                        ctx.move(to: CGPoint(x: min(pw, ax + aw + gap * 0.6), y: ay + ov))
                        ctx.addLine(to: CGPoint(x: min(pw, ax + aw + gap + arm * 0.6), y: ay + ov))
                    }
                    ctx.strokePath()
                }
            } else {
                let tick = 3.2 * scale
                let corners: [(Double, Double, Double, Double)] = [
                    (ax, ay, 1, 1), (ax + aw, ay, -1, 1),
                    (ax, ay + ah, 1, -1), (ax + aw, ay + ah, -1, -1),
                ]
                for (cx, cy, sx, sy) in corners {
                    ctx.move(to: CGPoint(x: cx, y: cy))
                    ctx.addLine(to: CGPoint(x: cx + sx * tick, y: cy))
                    ctx.move(to: CGPoint(x: cx, y: cy))
                    ctx.addLine(to: CGPoint(x: cx, y: cy + sy * tick))
                }
                ctx.strokePath()
            }
            ctx.restoreGState()
        }

        if config.pageCoords {
            let coord = L10n.rowCol(tile.row + 1, tile.col + 1)
            let label = "\(coord)   (\(pageNum)/\(totalPages))"
            let fontSize = max(5.5, min(8.5, 2.7 * scale))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: UIColor(white: 0.36, alpha: 1.0),
            ]
            let attrStr = NSAttributedString(string: label, attributes: attrs)
            let textSize = attrStr.size()

            ctx.saveGState()
            UIGraphicsPushContext(ctx)
            if m >= 4.2 * scale {
                let tx = ax + (aw - Double(textSize.width)) * 0.5
                let ty = ay + ah + min(m * 0.35, 2.0 * scale)
                attrStr.draw(at: CGPoint(x: tx, y: ty))
            } else {
                let padX = 1.6 * scale
                let padY = 0.8 * scale
                let box = CGRect(
                    x: pw - Double(textSize.width) - 2 * padX - 2 * scale,
                    y: ph - Double(textSize.height) - 2 * padY - 2 * scale,
                    width: Double(textSize.width) + 2 * padX,
                    height: Double(textSize.height) + 2 * padY
                )
                UIColor(white: 1.0, alpha: 0.80).setFill()
                UIRectFill(box)
                attrStr.draw(at: CGPoint(x: box.minX + padX, y: box.minY + padY))
            }
            UIGraphicsPopContext()
            ctx.restoreGState()
        }
    }

    private static func drawAssemblyMapPage(in ctx: CGContext, job: PreparedPrintJob, scale: Double) {
        let geom = job.geom
        let pw = geom.paperWMM * scale
        let ph = geom.paperHMM * scale
        let pad = 16.0 * scale

        ctx.saveGState()
        UIGraphicsPushContext(ctx)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 5.5 * scale, weight: .bold),
            .foregroundColor: UIColor(white: 0.12, alpha: 1),
        ]
        NSAttributedString(string: L10n.tr("map_title"), attributes: titleAttrs)
            .draw(at: CGPoint(x: pad, y: pad))

        let unitLbl = L10n.tr(job.config.unit == .inch ? "unit_in" : "unit_cm")
        let meta = "\(L10n.tr("metric_poster_trimmed")): \(PosterGeometry.formatLength(mm: geom.posterWMM, unit: job.config.unit)) × \(PosterGeometry.formatLength(mm: geom.posterHMM, unit: job.config.unit)) \(unitLbl)  ·  \(geom.cols) × \(geom.rows) (\(job.tiles.count))"
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 3.1 * scale, weight: .regular),
            .foregroundColor: UIColor(white: 0.38, alpha: 1),
        ]
        NSAttributedString(string: meta, attributes: subAttrs)
            .draw(at: CGPoint(x: pad, y: pad + 7.2 * scale))

        let boxX = pad
        let boxY = pad + 16.0 * scale
        let boxW = pw - 2 * pad
        let boxH = ph - boxY - pad - 14.0 * scale

        let fit = min(boxW / max(1.0, geom.gridWMM), boxH / max(1.0, geom.gridHMM))
        let ox = boxX + (boxW - geom.gridWMM * fit) * 0.5
        let oy = boxY + (boxH - geom.gridHMM * fit) * 0.5

        // Soft thumbnail behind grid
        job.croppedImage.draw(
            in: CGRect(x: ox, y: oy, width: geom.posterWMM * fit, height: geom.posterHMM * fit),
            blendMode: .normal,
            alpha: 0.34
        )

        let activeSet = Set(job.tiles.map { TileCoord(col: $0.col, row: $0.row) })
        var pageNum = 0
        for r in 0..<geom.rows {
            for c in 0..<geom.cols {
                let rect = CGRect(
                    x: ox + Double(c) * geom.stepWMM * fit,
                    y: oy + Double(r) * geom.stepHMM * fit,
                    width: geom.printableWMM * fit,
                    height: geom.printableHMM * fit
                )
                if activeSet.contains(TileCoord(col: c, row: r)) {
                    pageNum += 1
                    ctx.setStrokeColor(UIColor(red: 0.16, green: 0.42, blue: 0.85, alpha: 0.85).cgColor)
                    ctx.setLineWidth(0.35 * scale)
                    ctx.stroke(rect)

                    let fs = max(4.5, min(9.5, Double(min(rect.width, rect.height)) * 0.22))
                    let coordStr = NSAttributedString(
                        string: L10n.rowCol(r + 1, c + 1),
                        attributes: [
                            .font: UIFont.systemFont(ofSize: fs, weight: .bold),
                            .foregroundColor: UIColor(white: 0.10, alpha: 1),
                        ]
                    )
                    let numStr = NSAttributedString(
                        string: "#\(pageNum)",
                        attributes: [
                            .font: UIFont.systemFont(ofSize: fs * 0.78, weight: .medium),
                            .foregroundColor: UIColor(white: 0.36, alpha: 1),
                        ]
                    )
                    let s1 = coordStr.size()
                    let s2 = numStr.size()
                    coordStr.draw(at: CGPoint(x: rect.midX - s1.width * 0.5, y: rect.midY - s1.height * 0.9))
                    numStr.draw(at: CGPoint(x: rect.midX - s2.width * 0.5, y: rect.midY + s1.height * 0.12))
                } else {
                    ctx.setFillColor(UIColor(white: 0.78, alpha: 0.48).cgColor)
                    ctx.fill(rect)
                    ctx.setStrokeColor(UIColor(white: 0.52, alpha: 0.8).cgColor)
                    ctx.setLineWidth(0.25 * scale)
                    ctx.move(to: CGPoint(x: rect.minX, y: rect.minY))
                    ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    ctx.strokePath()
                }
            }
        }

        let tipAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 3.0 * scale, weight: .regular),
            .foregroundColor: UIColor(white: 0.30, alpha: 1),
        ]
        NSAttributedString(string: L10n.tr("map_tip"), attributes: tipAttrs)
            .draw(at: CGPoint(x: pad, y: ph - pad * 0.9))

        UIGraphicsPopContext()
        ctx.restoreGState()
    }

    static func renderPage(
        in ctx: CGContext,
        job: PreparedPrintJob,
        pageIndex: Int,
        scale: Double,
        lossless: Bool = true
    ) {
        let pw = job.geom.paperWMM * scale
        let ph = job.geom.paperHMM * scale

        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: 0, width: pw, height: ph))
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pw, height: ph))

        if pageIndex < job.tiles.count {
            let tile = job.tiles[pageIndex]
            if job.config.style.isHalftone, let sample = job.sampleBuffer {
                drawHalftoneRegion(
                    in: ctx,
                    sample: sample,
                    config: job.config,
                    posterWMM: job.geom.posterWMM,
                    posterHMM: job.geom.posterHMM,
                    regionX0: tile.artX0MM,
                    regionY0: tile.artY0MM,
                    regionX1: tile.artX1MM,
                    regionY1: tile.artY1MM,
                    destX: tile.pageArtXMM * scale,
                    destY: tile.pageArtYMM * scale,
                    scale: scale
                )
            } else {
                paintOriginalSlice(
                    in: ctx,
                    croppedImage: job.croppedImage,
                    geom: job.geom,
                    tile: tile,
                    scale: scale,
                    lossless: lossless
                )
            }
            drawPageGuides(
                in: ctx,
                config: job.config,
                geom: job.geom,
                tile: tile,
                pageNum: pageIndex + 1,
                totalPages: job.tiles.count,
                scale: scale
            )
        } else if job.hasAssemblyMap {
            drawAssemblyMapPage(in: ctx, job: job, scale: scale)
        }

        ctx.restoreGState()
    }

    static func renderSheetPreviewImage(job: PreparedPrintJob, pageIndex: Int, maxDim: Double = 1100.0) -> UIImage {
        let scale = maxDim / max(1.0, max(job.geom.paperWMM, job.geom.paperHMM))
        let size = CGSize(
            width: max(40, (job.geom.paperWMM * scale).rounded()),
            height: max(40, (job.geom.paperHMM * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { rctx in
            renderPage(in: rctx.cgContext, job: job, pageIndex: pageIndex, scale: scale, lossless: true)
        }
    }

    // MARK: - Lossless UHD / 100% Vector Multi-Page PDF Exporter

    static func exportPDF(
        rawImage: UIImage,
        config: PosterConfig,
        outputURL: URL,
        progress: ((Int, Int) -> Void)? = nil
    ) throws -> Int {
        let job = try preparePrintJob(rawImage: rawImage, config: config)
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: job.geom.paperWMM * kPtPerMM,
            height: job.geom.paperHMM * kPtPerMM
        )
        let meta: [String: Any] = [
            kCGPDFContextCreator as String: "PosterCut (Mosaika 1.0.0)",
            kCGPDFContextTitle as String: "PosterCut Poster",
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = meta
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        try renderer.writePDF(to: outputURL) { pdfCtx in
            for idx in 0..<job.totalPages {
                autoreleasepool {
                    progress?(idx + 1, job.totalPages)
                    pdfCtx.beginPage()
                    renderPage(
                        in: pdfCtx.cgContext,
                        job: job,
                        pageIndex: idx,
                        scale: kPtPerMM,
                        lossless: config.pdfLossless
                    )
                }
            }
        }
        return job.tiles.count
    }

    // MARK: - Lossless PNG Sheet Exporter

    static func exportPNGTiles(
        rawImage: UIImage,
        config: PosterConfig,
        outputDir: URL,
        baseName: String = "PosterCut",
        progress: ((Int, Int) -> Void)? = nil
    ) throws -> [URL] {
        let job = try preparePrintJob(rawImage: rawImage, config: config)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let dpi = Double(max(72, min(600, config.pngDPI)))
        let pxPerMM = dpi / kMMPerInch
        let size = CGSize(
            width: max(64, (job.geom.paperWMM * pxPerMM).rounded()),
            height: max(64, (job.geom.paperHMM * pxPerMM).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        var urls: [URL] = []
        for idx in 0..<job.totalPages {
            try autoreleasepool {
                progress?(idx + 1, job.totalPages)
                let renderer = UIGraphicsImageRenderer(size: size, format: format)
                let img = renderer.image { rctx in
                    renderPage(in: rctx.cgContext, job: job, pageIndex: idx, scale: pxPerMM, lossless: true)
                }
                guard let png = img.pngData() else { return }
                let fname: String
                if idx < job.tiles.count {
                    let t = job.tiles[idx]
                    fname = String(format: "%@_%02d_R%d_C%d.png", baseName, idx + 1, t.row + 1, t.col + 1)
                } else {
                    fname = "\(baseName)_00_assembly_map.png"
                }
                let fileURL = outputDir.appendingPathComponent(fname)
                try png.write(to: fileURL, options: .atomic)
                urls.append(fileURL)
            }
        }
        return urls
    }
}
