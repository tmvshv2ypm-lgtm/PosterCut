import SwiftUI
import UIKit

enum StudioStep: Int, CaseIterable, Identifiable {
    case image = 0
    case paper = 1
    case style = 2
    case export = 3

    var id: Int { rawValue }

    var titleKey: String {
        switch self {
        case .image: return "step_image"
        case .paper: return "step_paper"
        case .style: return "step_style"
        case .export: return "step_export"
        }
    }

    var systemIcon: String {
        switch self {
        case .image: return "photo"
        case .paper: return "doc.text.viewfinder"
        case .style: return "sparkles"
        case .export: return "square.and.arrow.up"
        }
    }
}

@MainActor
final class PosterStudioViewModel: ObservableObject {
    @Published var rawImage: UIImage?
    @Published var sourceName: String = ""
    @Published var config: PosterConfig
    @Published var geometry: PosterGeometry?
    @Published var previewImage: UIImage?
    @Published var cropSourceImage: UIImage?
    @Published var styleThumbnails: [PosterStyle: UIImage] = [:]

    @Published var currentStep: StudioStep = .paper
    @Published var isCropMode: Bool = false
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var exportStatusText: String = ""

    @Published var shareItems: [Any] = []
    @Published var showShareSheet: Bool = false
    @Published var showSheetPreview: Bool = false
    @Published var toastMessage: String?

    private var previewTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    init() {
        let tm = PosterThemeManager.shared
        self.config = PosterConfig(paperID: tm.defaultPaperID, unit: tm.defaultUnit)
    }

    var hasImage: Bool { rawImage != nil }

    var croppedPixelSize: (w: Int, h: Int) {
        guard let img = rawImage else { return (0, 0) }
        return PosterEngine.croppedDimensions(for: img, config: config)
    }

    // MARK: - Loading Images

    func setLoadedImage(_ image: UIImage, name: String) {
        let normalized = image.normalizedUp()
        rawImage = normalized
        sourceName = name
        config.rotationDeg = 0
        config.flipH = false
        config.flipV = false
        config.crop = .full
        config.excludedTiles.removeAll()
        isCropMode = false
        currentStep = .paper

        refreshGeometryAndPreview(immediate: true)
        generateStyleThumbnails(for: normalized)
        triggerHaptic(.light)
    }

    func loadSampleArtwork() {
        let sample = PosterEngine.createSampleArtwork(width: 1800, height: 2250)
        setLoadedImage(sample, name: "Aurora Glacier UHD")
    }

    func pasteFromClipboard() {
        if let pasted = UIPasteboard.general.image {
            setLoadedImage(pasted, name: L10n.tr("btn_paste_clipboard"))
        } else {
            showToast(L10n.tr("err_clipboard_empty"))
        }
    }

    func loadFromURL(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            showToast(L10n.tr("err_invalid_url"))
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let img = UIImage(data: data) else {
                    showToast(L10n.tr("err_load_image"))
                    return
                }
                let name = url.lastPathComponent.isEmpty ? "URL Image" : url.lastPathComponent
                setLoadedImage(img, name: name)
            } catch {
                showToast("\(L10n.tr("err_load_image")): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Transforms & Geometry

    func rotate(by delta: Int) {
        guard rawImage != nil else { return }
        config.rotationDeg = ((config.rotationDeg + delta) % 360 + 360) % 360
        config.crop = .full
        config.excludedTiles.removeAll()
        refreshGeometryAndPreview(immediate: true)
        triggerHaptic(.light)
    }

    func flip(horizontal: Bool) {
        guard rawImage != nil else { return }
        if horizontal {
            config.flipH.toggle()
        } else {
            config.flipV.toggle()
        }
        refreshGeometryAndPreview(immediate: true)
        triggerHaptic(.light)
    }

    func resetCrop() {
        config.crop = .full
        config.excludedTiles.removeAll()
        refreshGeometryAndPreview(immediate: true)
    }

    func setCropMode(_ enabled: Bool) {
        isCropMode = enabled
        if enabled, let raw = rawImage {
            let cfg = config
            Task.detached(priority: .userInitiated) {
                let transformed = PosterEngine.applyGeometricTransforms(raw, config: cfg)
                await MainActor.run {
                    self.cropSourceImage = transformed
                }
            }
        } else {
            refreshGeometryAndPreview(immediate: true)
        }
    }

    func toggleTile(_ coord: TileCoord) {
        if config.excludedTiles.contains(coord) {
            config.excludedTiles.remove(coord)
        } else {
            config.excludedTiles.insert(coord)
        }
        recomputeGeometryOnly()
        triggerHaptic(.light)
    }

    func restoreAllTiles() {
        config.excludedTiles.removeAll()
        recomputeGeometryOnly()
    }

    func optimizeOrientation() {
        guard let raw = rawImage else { return }
        let dims = PosterEngine.croppedDimensions(for: raw, config: config)
        let res = PosterGeometry.suggestOptimalOrientation(config: config, imgWPx: dims.w, imgHPx: dims.h)
        if res.bestLandscape != config.landscape {
            let saved = abs(res.portraitSheets - res.landscapeSheets)
            if let g = geometry, config.sizeMode == .sheets {
                config.sizeMode = .physical
                config.physicalValueCM = (g.posterWMM / 10.0 * 10.0).rounded() / 10.0
                config.physicalAxis = .wide
            }
            config.landscape = res.bestLandscape
            refreshGeometryAndPreview(immediate: true)
            let orientStr = L10n.tr(res.bestLandscape ? "orient_landscape" : "orient_portrait")
            if saved > 0 {
                showToast(L10n.fmt("toast_orient_saved_fmt", orientStr, saved))
            } else {
                showToast(L10n.tr("toast_orient_already_best"))
            }
            triggerHaptic(.medium)
        } else {
            showToast(L10n.tr("toast_orient_already_best"))
        }
    }

    func applyStyle(_ style: PosterStyle) {
        config.applyStyle(style)
        config.showOriginal = false
        refreshGeometryAndPreview(immediate: true)
        triggerHaptic(.light)
    }

    func applyColorPreset(_ preset: ColorPreset) {
        config.applyColorPreset(preset)
        refreshGeometryAndPreview(immediate: true)
        triggerHaptic(.light)
    }

    func resetPhotoAdjustments() {
        config.brightness = 0
        config.contrast = 0
        config.sharpness = 0
        config.grayscaleClean = false
        refreshGeometryAndPreview(immediate: true)
    }

    func recomputeGeometryOnly() {
        guard let raw = rawImage else {
            geometry = nil
            return
        }
        let dims = PosterEngine.croppedDimensions(for: raw, config: config)
        geometry = PosterGeometry.compute(config: config, imgWPx: dims.w, imgHPx: dims.h)
    }

    func refreshGeometryAndPreview(immediate: Bool = false) {
        recomputeGeometryOnly()
        guard let raw = rawImage, let geom = geometry else { return }
        let cfg = config

        previewTask?.cancel()
        previewTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 70_000_000)
                if Task.isCancelled { return }
            }
            let rendered = await Task.detached(priority: .userInitiated) {
                PosterEngine.renderPreviewImage(rawImage: raw, config: cfg, geom: geom, maxDim: 900)
            }.value
            if Task.isCancelled { return }
            self.previewImage = rendered
        }
    }

    private func generateStyleThumbnails(for image: UIImage) {
        Task.detached(priority: .utility) {
            let maxSide: CGFloat = 180
            let scale = min(1.0, maxSide / max(1, max(image.size.width, image.size.height)))
            let tSize = CGSize(width: max(32, image.size.width * scale), height: max(32, image.size.height * scale))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            format.opaque = true
            let small = UIGraphicsImageRenderer(size: tSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: tSize))
            }
            var dict: [PosterStyle: UIImage] = [:]
            for st in PosterStyle.allCases {
                dict[st] = PosterEngine.renderStyleThumbnail(style: st, sourceThumb: small)
            }
            await MainActor.run {
                self.styleThumbnails = dict
            }
        }
    }

    // MARK: - Export (PDF / Lossless PNG) & Native iOS AirPrint

    func exportAndShare() {
        guard let raw = rawImage, let geom = geometry else { return }
        guard geom.activeSheets > 0 else {
            showToast(L10n.tr("err_no_active_sheets"))
            return
        }

        let cfg = config
        let cleanStem = Self.sanitizedStem(sourceName)
        isExporting = true
        exportProgress = 0.05
        exportStatusText = L10n.tr("exporting_title")

        Task {
            do {
                let items: [Any]
                let tempBase = FileManager.default.temporaryDirectory
                    .appendingPathComponent("PosterCutExport_\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)

                if cfg.exportFormat == .pdf {
                    let pdfURL = tempBase.appendingPathComponent("\(cleanStem)_PosterCut.pdf")
                    _ = try await Task.detached(priority: .userInitiated) {
                        try PosterEngine.exportPDF(rawImage: raw, config: cfg, outputURL: pdfURL) { cur, tot in
                            Task { @MainActor in
                                self.exportProgress = Double(cur) / Double(max(1, tot))
                                self.exportStatusText = L10n.fmt("exporting_page_fmt", cur, tot)
                            }
                        }
                    }.value
                    items = [pdfURL]
                } else {
                    let urls = try await Task.detached(priority: .userInitiated) {
                        try PosterEngine.exportPNGTiles(rawImage: raw, config: cfg, outputDir: tempBase, baseName: cleanStem) { cur, tot in
                            Task { @MainActor in
                                self.exportProgress = Double(cur) / Double(max(1, tot))
                                self.exportStatusText = L10n.fmt("exporting_page_fmt", cur, tot)
                            }
                        }
                    }.value
                    items = urls
                }

                isExporting = false
                shareItems = items
                showShareSheet = true
                triggerHaptic(.medium)
            } catch {
                isExporting = false
                showToast(L10n.fmt("err_export_failed_fmt", error.localizedDescription))
            }
        }
    }

    func printDirectlyWithAirPrint(preparedJob: PreparedPrintJob? = nil) {
        guard let raw = rawImage else { return }
        let cfg = config

        Task {
            do {
                let job: PreparedPrintJob
                if let existing = preparedJob {
                    job = existing
                } else {
                    isExporting = true
                    exportProgress = 0.25
                    exportStatusText = L10n.tr("exporting_title")
                    job = try await Task.detached(priority: .userInitiated) {
                        try PosterEngine.preparePrintJob(rawImage: raw, config: cfg)
                    }.value
                    isExporting = false
                }

                let printController = UIPrintInteractionController.shared
                let info = UIPrintInfo(dictionary: nil)
                info.jobName = sourceName.isEmpty ? "PosterCut" : sourceName
                info.outputType = .photo
                info.orientation = job.geom.paperWMM > job.geom.paperHMM ? .landscape : .portrait
                printController.printInfo = info
                printController.printPageRenderer = PosterPrintPageRenderer(job: job)
                printController.present(animated: true) { _, completed, error in
                    Task { @MainActor in
                        if let error {
                            self.showToast(L10n.fmt("err_print_failed_fmt", error.localizedDescription))
                        } else if completed {
                            self.showToast(L10n.fmt("toast_print_sent_fmt", job.totalPages))
                        }
                    }
                }
            } catch {
                isExporting = false
                showToast(L10n.fmt("err_print_failed_fmt", error.localizedDescription))
            }
        }
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
            toastMessage = message
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.22)) {
                    toastMessage = nil
                }
            }
        }
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }

    private static func sanitizedStem(_ raw: String) -> String {
        let stem = (raw as NSString).deletingPathExtension
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = stem.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let result = String(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return result.isEmpty ? "PosterCut" : result
    }
}

/// Native UIPrintPageRenderer rendering every sheet at exact 1:1 millimeter scale via CoreGraphics.
final class PosterPrintPageRenderer: UIPrintPageRenderer {
    private let job: PreparedPrintJob

    init(job: PreparedPrintJob) {
        self.job = job
        super.init()
    }

    override var numberOfPages: Int {
        job.totalPages
    }

    override func drawPage(at pageIndex: Int, in printableRect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let fullPaper = paperRect
        let targetW = CGFloat(job.geom.paperWMM * kPtPerMM)
        let targetH = CGFloat(job.geom.paperHMM * kPtPerMM)

        ctx.saveGState()
        if fullPaper.width > 1 && fullPaper.height > 1 {
            if targetW > fullPaper.width * 1.02 || targetH > fullPaper.height * 1.02 {
                let fit = min(fullPaper.width / targetW, fullPaper.height / targetH)
                ctx.translateBy(
                    x: fullPaper.minX + (fullPaper.width - targetW * fit) * 0.5,
                    y: fullPaper.minY + (fullPaper.height - targetH * fit) * 0.5
                )
                ctx.scaleBy(x: fit, y: fit)
            } else {
                ctx.translateBy(
                    x: fullPaper.minX + max(0, (fullPaper.width - targetW) * 0.5),
                    y: fullPaper.minY + max(0, (fullPaper.height - targetH) * 0.5)
                )
            }
        }
        PosterEngine.renderPage(in: ctx, job: job, pageIndex: pageIndex, scale: kPtPerMM, lossless: true)
        ctx.restoreGState()
    }
}
