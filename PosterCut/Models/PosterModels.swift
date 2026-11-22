import Foundation
import CoreGraphics

let kMMPerInch: Double = 25.4
let kPtPerMM: Double = 72.0 / 25.4

struct PaperPreset: Identifiable, Hashable, Sendable {
    let id: String
    let labelKey: String
    let widthMM: Double
    let heightMM: Double

    static let all: [PaperPreset] = [
        PaperPreset(id: "letter", labelKey: "paper_letter", widthMM: 215.9, heightMM: 279.4),
        PaperPreset(id: "a4", labelKey: "paper_a4", widthMM: 210.0, heightMM: 297.0),
        PaperPreset(id: "legal", labelKey: "paper_legal", widthMM: 215.9, heightMM: 355.6),
        PaperPreset(id: "a3", labelKey: "paper_a3", widthMM: 297.0, heightMM: 420.0),
        PaperPreset(id: "tabloid", labelKey: "paper_tabloid", widthMM: 279.4, heightMM: 431.8),
        PaperPreset(id: "a5", labelKey: "paper_a5", widthMM: 148.0, heightMM: 210.0),
        PaperPreset(id: "b4", labelKey: "paper_b4", widthMM: 250.0, heightMM: 353.0),
        PaperPreset(id: "b5", labelKey: "paper_b5", widthMM: 176.0, heightMM: 250.0),
        PaperPreset(id: "custom", labelKey: "paper_custom", widthMM: 210.0, heightMM: 297.0),
    ]

    static func byID(_ id: String) -> PaperPreset {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}

enum PosterStyle: String, CaseIterable, Identifiable, Sendable {
    case original
    case halftoneColor
    case halftoneBW
    case halftoneSquares
    case halftoneDiamonds
    case halftoneLines

    var id: String { rawValue }
    var isHalftone: Bool { self != .original }

    var titleKey: String {
        switch self {
        case .original: return "style_original_title"
        case .halftoneColor: return "style_halftone_color_title"
        case .halftoneBW: return "style_halftone_bw_title"
        case .halftoneSquares: return "style_halftone_squares_title"
        case .halftoneDiamonds: return "style_halftone_diamonds_title"
        case .halftoneLines: return "style_halftone_lines_title"
        }
    }

    var descKey: String {
        switch self {
        case .original: return "style_original_desc"
        case .halftoneColor: return "style_halftone_color_desc"
        case .halftoneBW: return "style_halftone_bw_desc"
        case .halftoneSquares: return "style_halftone_squares_desc"
        case .halftoneDiamonds: return "style_halftone_diamonds_desc"
        case .halftoneLines: return "style_halftone_lines_desc"
        }
    }
}

enum ColorMode: String, CaseIterable, Identifiable, Sendable {
    case black
    case single
    case multicolor

    var id: String { rawValue }
}

enum BgMode: String, CaseIterable, Identifiable, Sendable {
    case white
    case single
    case transparent

    var id: String { rawValue }
}

enum SizeMode: String, CaseIterable, Identifiable, Sendable {
    case sheets
    case physical
    var id: String { rawValue }
}

enum SizeAxis: String, CaseIterable, Identifiable, Sendable {
    case wide
    case high
    var id: String { rawValue }
}

enum LengthUnit: String, CaseIterable, Identifiable, Sendable {
    case cm
    case inch
    var id: String { rawValue }
}

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case pdf
    case png
    var id: String { rawValue }
}

struct TileCoord: Hashable, Sendable {
    let col: Int
    let row: Int
}

struct NormalizedCropRect: Equatable, Sendable {
    var x0: Double = 0.0
    var y0: Double = 0.0
    var x1: Double = 1.0
    var y1: Double = 1.0

    static let full = NormalizedCropRect(x0: 0, y0: 0, x1: 1, y1: 1)

    var isFull: Bool {
        x0 <= 0.001 && y0 <= 0.001 && x1 >= 0.999 && y1 >= 0.999
    }
}

struct ColorPreset: Identifiable, Sendable {
    let id: String
    let colorMode: ColorMode
    let rasterHex: String
    let bgMode: BgMode
    let bgHex: String
    let swatchDots: [String]

    static let all: [ColorPreset] = [
        ColorPreset(id: "multi_white", colorMode: .multicolor, rasterHex: "#111111", bgMode: .white, bgHex: "#FFFFFF",
                    swatchDots: ["#D9381E", "#2C8C48", "#2B6CB0", "#E2A318"]),
        ColorPreset(id: "multi_black", colorMode: .multicolor, rasterHex: "#111111", bgMode: .single, bgHex: "#111114",
                    swatchDots: ["#FF595E", "#8AC926", "#1982C4", "#FFCA3A"]),
        ColorPreset(id: "multi_cream", colorMode: .multicolor, rasterHex: "#111111", bgMode: .single, bgHex: "#F5EFE0",
                    swatchDots: ["#C84B31", "#346751", "#2D4263", "#D99B26"]),
        ColorPreset(id: "classic_bw", colorMode: .black, rasterHex: "#111111", bgMode: .white, bgHex: "#FFFFFF",
                    swatchDots: ["#111111", "#111111", "#111111", "#111111"]),
        ColorPreset(id: "inverted_wb", colorMode: .single, rasterHex: "#FFFFFF", bgMode: .single, bgHex: "#141418",
                    swatchDots: ["#FFFFFF", "#FFFFFF", "#FFFFFF", "#FFFFFF"]),
        ColorPreset(id: "ocean_sky", colorMode: .single, rasterHex: "#023E8A", bgMode: .single, bgHex: "#CAF0F8",
                    swatchDots: ["#023E8A", "#023E8A", "#023E8A", "#023E8A"]),
        ColorPreset(id: "cobalt_white", colorMode: .single, rasterHex: "#1D4ED8", bgMode: .white, bgHex: "#FFFFFF",
                    swatchDots: ["#1D4ED8", "#1D4ED8", "#1D4ED8", "#1D4ED8"]),
        ColorPreset(id: "cyan_midnight", colorMode: .single, rasterHex: "#38BDF8", bgMode: .single, bgHex: "#0B1120",
                    swatchDots: ["#38BDF8", "#38BDF8", "#38BDF8", "#38BDF8"]),
        ColorPreset(id: "teal_night", colorMode: .single, rasterHex: "#2DD4BF", bgMode: .single, bgHex: "#0F172A",
                    swatchDots: ["#2DD4BF", "#2DD4BF", "#2DD4BF", "#2DD4BF"]),
        ColorPreset(id: "violet_lilac", colorMode: .single, rasterHex: "#4A148C", bgMode: .single, bgHex: "#EDE7F6",
                    swatchDots: ["#4A148C", "#4A148C", "#4A148C", "#4A148C"]),
        ColorPreset(id: "forest_mint", colorMode: .single, rasterHex: "#1B4332", bgMode: .single, bgHex: "#D8F3DC",
                    swatchDots: ["#1B4332", "#1B4332", "#1B4332", "#1B4332"]),
        ColorPreset(id: "crimson_blush", colorMode: .single, rasterHex: "#7A0C2E", bgMode: .single, bgHex: "#FADDE1",
                    swatchDots: ["#7A0C2E", "#7A0C2E", "#7A0C2E", "#7A0C2E"]),
        ColorPreset(id: "indigo_sun", colorMode: .single, rasterHex: "#23395B", bgMode: .single, bgHex: "#FFE169",
                    swatchDots: ["#23395B", "#23395B", "#23395B", "#23395B"]),
        ColorPreset(id: "magenta_snow", colorMode: .single, rasterHex: "#C2185B", bgMode: .white, bgHex: "#FFFFFF",
                    swatchDots: ["#C2185B", "#C2185B", "#C2185B", "#C2185B"]),
        ColorPreset(id: "neon_pink_dark", colorMode: .single, rasterHex: "#F472B6", bgMode: .single, bgHex: "#18181B",
                    swatchDots: ["#F472B6", "#F472B6", "#F472B6", "#F472B6"]),
        ColorPreset(id: "pop_red_gray", colorMode: .single, rasterHex: "#B91C1C", bgMode: .single, bgHex: "#E5E7EB",
                    swatchDots: ["#B91C1C", "#B91C1C", "#B91C1C", "#B91C1C"]),
        ColorPreset(id: "coral_navy", colorMode: .single, rasterHex: "#FF6B6B", bgMode: .single, bgHex: "#1E293B",
                    swatchDots: ["#FF6B6B", "#FF6B6B", "#FF6B6B", "#FF6B6B"]),
        ColorPreset(id: "sepia_paper", colorMode: .single, rasterHex: "#5C3A21", bgMode: .single, bgHex: "#F4ECE1",
                    swatchDots: ["#5C3A21", "#5C3A21", "#5C3A21", "#5C3A21"]),
    ]
}

struct PosterConfig: Equatable, Sendable {
    // Paper & orientation
    var paperID: String = "letter"
    var customWidthMM: Double = 210.0
    var customHeightMM: Double = 297.0
    var landscape: Bool = false

    // Margins & glue overlap
    var marginEnabled: Bool = true
    var marginMM: Double = 10.0
    var overlapEnabled: Bool = false
    var overlapMM: Double = 5.0

    // Output sizing
    var sizeMode: SizeMode = .sheets
    var sheetsValue: Double = 3.0
    var sheetsAxis: SizeAxis = .wide
    var physicalValueCM: Double = 60.0
    var physicalAxis: SizeAxis = .wide
    var unit: LengthUnit = .cm

    // Transforms
    var rotationDeg: Int = 0
    var flipH: Bool = false
    var flipV: Bool = false
    var crop: NormalizedCropRect = .full

    // Style & enhancements
    var style: PosterStyle = .original
    var brightness: Double = 0.0
    var contrast: Double = 0.0
    var sharpness: Double = 0.0
    var grayscaleClean: Bool = false

    // Halftone parameters
    var dotSizeMM: Double = 8.0
    var gridAngle: Double = 0.0
    var colorMode: ColorMode = .multicolor
    var rasterHex: String = "#111111"
    var bgMode: BgMode = .white
    var bgHex: String = "#FFFFFF"

    // Output & guides
    var cropMarks: Bool = true
    var pageCoords: Bool = true
    var skipBlankPages: Bool = false
    var includeAssemblyMap: Bool = false
    var excludedTiles: Set<TileCoord> = []
    var exportFormat: ExportFormat = .pdf
    var pdfLossless: Bool = true
    var pngDPI: Int = 300

    // Preview toggles
    var showSilhouette: Bool = true
    var silhouetteHeightCM: Double = 180.0
    var showOriginal: Bool = false
    var showGrid: Bool = true

    func paperDimensionsMM(landscapeOverride: Bool? = nil) -> (width: Double, height: Double) {
        let isLand = landscapeOverride ?? landscape
        if paperID == "custom" {
            let w = max(50.0, customWidthMM)
            let h = max(50.0, customHeightMM)
            return isLand ? (h, w) : (w, h)
        }
        let preset = PaperPreset.byID(paperID)
        let lo = min(preset.widthMM, preset.heightMM)
        let hi = max(preset.widthMM, preset.heightMM)
        return isLand ? (hi, lo) : (lo, hi)
    }

    mutating func applyStyle(_ newStyle: PosterStyle) {
        style = newStyle
        if newStyle == .halftoneBW {
            colorMode = .black
            bgMode = .white
            rasterHex = "#111111"
            bgHex = "#FFFFFF"
        } else if newStyle == .halftoneColor && colorMode == .black {
            colorMode = .multicolor
        }
    }

    mutating func applyColorPreset(_ preset: ColorPreset) {
        colorMode = preset.colorMode
        rasterHex = preset.rasterHex
        bgMode = preset.bgMode
        bgHex = preset.bgHex
    }
}

struct TileRect: Sendable {
    let col: Int
    let row: Int
    let posterX0MM: Double
    let posterY0MM: Double
    let posterX1MM: Double
    let posterY1MM: Double
    let artX0MM: Double
    let artY0MM: Double
    let artX1MM: Double
    let artY1MM: Double
    let pageArtXMM: Double
    let pageArtYMM: Double
    let pageArtWMM: Double
    let pageArtHMM: Double

    var hasArtwork: Bool { pageArtWMM > 0.05 && pageArtHMM > 0.05 }
}

enum DPIRating: String, Sendable {
    case excellent
    case good
    case medium
    case low
}

struct PosterGeometry: Sendable {
    let paperWMM: Double
    let paperHMM: Double
    let marginMM: Double
    let overlapMM: Double
    let printableWMM: Double
    let printableHMM: Double
    let stepWMM: Double
    let stepHMM: Double
    let cols: Int
    let rows: Int
    let exactCols: Double
    let exactRows: Double
    let posterWMM: Double
    let posterHMM: Double
    let posterWithMarginsWMM: Double
    let posterWithMarginsHMM: Double
    let totalSheets: Int
    let activeSheets: Int
    let effectiveDPI: Double
    let dpiRating: DPIRating
    let imgWPx: Int
    let imgHPx: Int

    var gridWMM: Double { Double(cols) * stepWMM + overlapMM }
    var gridHMM: Double { Double(rows) * stepHMM + overlapMM }

    func tileRect(col: Int, row: Int) -> TileRect {
        let px0 = Double(col) * stepWMM
        let py0 = Double(row) * stepHMM
        let px1 = px0 + printableWMM
        let py1 = py0 + printableHMM

        let ax0 = max(0.0, px0)
        let ay0 = max(0.0, py0)
        let ax1 = min(posterWMM, px1)
        let ay1 = min(posterHMM, py1)

        return TileRect(
            col: col,
            row: row,
            posterX0MM: px0,
            posterY0MM: py0,
            posterX1MM: px1,
            posterY1MM: py1,
            artX0MM: ax0,
            artY0MM: ay0,
            artX1MM: ax1,
            artY1MM: ay1,
            pageArtXMM: marginMM + (ax0 - px0),
            pageArtYMM: marginMM + (ay0 - py0),
            pageArtWMM: max(0.0, ax1 - ax0),
            pageArtHMM: max(0.0, ay1 - ay0)
        )
    }

    static func compute(
        config: PosterConfig,
        imgWPx: Int,
        imgHPx: Int,
        landscapeOverride: Bool? = nil
    ) -> PosterGeometry {
        let wPx = max(1, imgWPx)
        let hPx = max(1, imgHPx)
        let paper = config.paperDimensionsMM(landscapeOverride: landscapeOverride)
        let maxMargin = min(paper.width, paper.height) * 0.35
        let marginMM = config.marginEnabled ? min(max(0.0, config.marginMM), maxMargin) : 0.0

        let printableW = max(10.0, paper.width - 2.0 * marginMM)
        let printableH = max(10.0, paper.height - 2.0 * marginMM)

        let maxOverlap = min(printableW, printableH) * 0.35
        let overlapMM = config.overlapEnabled ? min(max(0.0, config.overlapMM), maxOverlap) : 0.0

        let stepW = max(5.0, printableW - overlapMM)
        let stepH = max(5.0, printableH - overlapMM)

        let aspect = Double(wPx) / Double(hPx)
        let posterW: Double
        let posterH: Double

        switch config.sizeMode {
        case .physical:
            let targetMM = max(20.0, config.physicalValueCM * 10.0)
            if config.physicalAxis == .wide {
                posterW = targetMM
                posterH = posterW / aspect
            } else {
                posterH = targetMM
                posterW = posterH * aspect
            }
        case .sheets:
            let sVal = max(0.2, min(40.0, config.sheetsValue))
            if config.sheetsAxis == .wide {
                posterW = sVal <= 1.0 ? (sVal * printableW) : (printableW + (sVal - 1.0) * stepW)
                posterH = posterW / aspect
            } else {
                posterH = sVal <= 1.0 ? (sVal * printableH) : (printableH + (sVal - 1.0) * stepH)
                posterW = posterH * aspect
            }
        }

        let exactCols = posterW <= printableW ? max(0.01, posterW / printableW) : (1.0 + (posterW - printableW) / stepW)
        let exactRows = posterH <= printableH ? max(0.01, posterH / printableH) : (1.0 + (posterH - printableH) / stepH)
        let cols = max(1, Int(ceil(exactCols - 1e-4)))
        let rows = max(1, Int(ceil(exactRows - 1e-4)))

        let totalSheets = cols * rows
        let excludedValid = config.excludedTiles.filter { $0.col >= 0 && $0.col < cols && $0.row >= 0 && $0.row < rows }.count
        let activeSheets = max(0, totalSheets - excludedValid)

        let dpi = Double(wPx) / max(0.01, posterW / kMMPerInch)
        let rating: DPIRating
        if dpi >= 240.0 {
            rating = .excellent
        } else if dpi >= 150.0 {
            rating = .good
        } else if dpi >= 95.0 {
            rating = .medium
        } else {
            rating = .low
        }

        return PosterGeometry(
            paperWMM: paper.width,
            paperHMM: paper.height,
            marginMM: marginMM,
            overlapMM: overlapMM,
            printableWMM: printableW,
            printableHMM: printableH,
            stepWMM: stepW,
            stepHMM: stepH,
            cols: cols,
            rows: rows,
            exactCols: exactCols,
            exactRows: exactRows,
            posterWMM: posterW,
            posterHMM: posterH,
            posterWithMarginsWMM: Double(cols) * paper.width,
            posterWithMarginsHMM: Double(rows) * paper.height,
            totalSheets: totalSheets,
            activeSheets: activeSheets,
            effectiveDPI: dpi,
            dpiRating: rating,
            imgWPx: wPx,
            imgHPx: hPx
        )
    }

    static func suggestOptimalOrientation(
        config: PosterConfig,
        imgWPx: Int,
        imgHPx: Int
    ) -> (bestLandscape: Bool, portraitSheets: Int, landscapeSheets: Int) {
        let cur = compute(config: config, imgWPx: imgWPx, imgHPx: imgHPx)
        var probe = config
        probe.sizeMode = .physical
        probe.physicalValueCM = cur.posterWMM / 10.0
        probe.physicalAxis = .wide

        let gP = compute(config: probe, imgWPx: imgWPx, imgHPx: imgHPx, landscapeOverride: false)
        let gL = compute(config: probe, imgWPx: imgWPx, imgHPx: imgHPx, landscapeOverride: true)

        if gL.totalSheets < gP.totalSheets { return (true, gP.totalSheets, gL.totalSheets) }
        if gP.totalSheets < gL.totalSheets { return (false, gP.totalSheets, gL.totalSheets) }
        let wasteP = Double(gP.totalSheets) * gP.paperWMM * gP.paperHMM
        let wasteL = Double(gL.totalSheets) * gL.paperWMM * gL.paperHMM
        return (wasteL < wasteP, gP.totalSheets, gL.totalSheets)
    }

    static func formatLength(mm: Double, unit: LengthUnit) -> String {
        switch unit {
        case .inch: return String(format: "%.1f", mm / kMMPerInch)
        case .cm: return String(format: "%.1f", mm / 10.0)
        }
    }
}

func parseHexRGB(_ hex: String) -> (r: Double, g: Double, b: Double) {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var val: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&val)
    switch cleaned.count {
    case 3:
        let r = Double((val >> 8) * 17) / 255.0
        let g = Double(((val >> 4) & 0xF) * 17) / 255.0
        let b = Double((val & 0xF) * 17) / 255.0
        return (r, g, b)
    case 6:
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0
        return (r, g, b)
    default:
        return (0.07, 0.07, 0.08)
    }
}

func rgbToHex(r: Double, g: Double, b: Double) -> String {
    let ri = max(0, min(255, Int((r * 255.0).rounded())))
    let gi = max(0, min(255, Int((g * 255.0).rounded())))
    let bi = max(0, min(255, Int((b * 255.0).rounded())))
    return String(format: "#%02X%02X%02X", ri, gi, bi)
}
