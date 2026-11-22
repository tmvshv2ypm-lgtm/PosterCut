import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Main native iOS 26 Liquid Glass studio for PosterCut.
/// Automatically adapts between Portrait iPhone (top canvas + bottom glass inspector)
/// and Landscape / iPad (side-by-side canvas + glass sidebar).
struct StudioView: View {
    @StateObject private var viewModel = PosterStudioViewModel()
    @ObservedObject private var themeManager = PosterThemeManager.shared

    @State private var showPhotosPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showFileImporter: Bool = false
    @State private var showSettings: Bool = false
    @State private var showURLAlert: Bool = false
    @State private var urlInputText: String = ""

    var body: some View {
        ZStack {
            AmbientLiquidBackdrop()

            VStack(spacing: 0) {
                topHeaderBar
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                if viewModel.hasImage {
                    GeometryReader { geo in
                        let isSideBySide = geo.size.width >= 760 && geo.size.width > geo.size.height
                        if isSideBySide {
                            HStack(spacing: 12) {
                                canvasContainer
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                inspectorContainer
                                    .frame(width: min(390, geo.size.width * 0.42))
                                    .frame(maxHeight: .infinity)
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 10)
                        } else {
                            VStack(spacing: 10) {
                                canvasContainer
                                    .frame(height: max(220, geo.size.height * 0.43))
                                inspectorContainer
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 6)
                        }
                    }
                } else {
                    welcomeEmptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Export Progress HUD
            if viewModel.isExporting {
                exportProgressHUD
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }

            // Floating Toast Pill
            if let toast = viewModel.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .liquidGlassCapsule(interactive: false)
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                        .padding(.bottom, 22)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let item = newItem else { return }
            loadSelectedPhoto(item)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert(L10n.tr("dlg_url_title"), isPresented: $showURLAlert) {
            TextField("https://...", text: $urlInputText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button(L10n.tr("btn_cancel"), role: .cancel) {}
            Button(L10n.tr("btn_load")) {
                viewModel.loadFromURL(urlInputText)
                urlInputText = ""
            }
        } message: {
            Text(L10n.tr("dlg_url_body"))
        }
        .sheet(isPresented: $viewModel.showSheetPreview) {
            SheetPreviewView(viewModel: viewModel)
                .preferredColorScheme(themeManager.appearance.preferredColorScheme)
                .tint(themeManager.primaryAccent)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(viewModel: viewModel)
                .preferredColorScheme(themeManager.appearance.preferredColorScheme)
                .tint(themeManager.primaryAccent)
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            ActivityShareSheet(items: viewModel.shareItems)
                .ignoresSafeArea()
        }
    }

    // MARK: - Top Header Bar

    private var topHeaderBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                PosterMarkView(size: 30)
                Text("PosterCut")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)

            if viewModel.hasImage {
                Button {
                    viewModel.showSheetPreview = true
                } label: {
                    Image(systemName: "rectangle.grid.2x2")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 38, height: 38)
                        .liquidGlassCircle(interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("btn_preview_sheets"))

                Button {
                    viewModel.exportAndShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .liquidGlassCircle(tint: themeManager.primaryAccent, interactive: true)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isExporting)
                .accessibilityLabel(L10n.tr("step_export"))
            }

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .liquidGlassCircle(interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("ios_settings_title"))
        }
    }

    // MARK: - Welcome Empty State

    private var welcomeEmptyState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Spacer(minLength: 24)

                VStack(spacing: 16) {
                    PosterMarkView(size: 86)

                    VStack(spacing: 6) {
                        Text(L10n.tr("welcome_title"))
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text(L10n.tr("welcome_subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)

                    // Primary Photos CTA
                    Button {
                        showPhotosPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.headline)
                            Text(L10n.tr("btn_choose_image"))
                                .font(.headline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .liquidGlassCapsule(tint: themeManager.primaryAccent, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    // Secondary Quick Sources
                    HStack(spacing: 10) {
                        quickSourceTile(icon: "folder.fill", title: L10n.tr("ios_from_files")) {
                            showFileImporter = true
                        }
                        quickSourceTile(icon: "doc.on.clipboard.fill", title: L10n.tr("btn_paste_clipboard")) {
                            viewModel.pasteFromClipboard()
                        }
                        quickSourceTile(icon: "link", title: L10n.tr("btn_from_url")) {
                            showURLAlert = true
                        }
                    }

                    Button {
                        viewModel.loadSampleArtwork()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.bold))
                            Text(L10n.tr("btn_try_sample"))
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(themeManager.primaryAccent)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .frame(maxWidth: 440)
                .liquidGlassRoundedRect(cornerRadius: 28, interactive: false)
                .padding(.horizontal, 20)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func quickSourceTile(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeManager.primaryAccent)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .liquidGlassRoundedRect(cornerRadius: 16, interactive: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active Studio Canvas + Floating Pills

    private var canvasContainer: some View {
        ZStack {
            PosterCanvasView(viewModel: viewModel)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .liquidGlassRoundedRect(cornerRadius: 24, interactive: false)

            // Top floating canvas toolbar pill
            VStack {
                HStack(spacing: 6) {
                    if viewModel.isCropMode {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                viewModel.setCropMode(false)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                Text(L10n.tr("btn_apply_crop"))
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .liquidGlassCapsule(tint: themeManager.primaryAccent, interactive: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        canvasPillToggle(
                            icon: "figure.stand",
                            isActive: viewModel.config.showSilhouette,
                            tooltip: L10n.tr("tip_toggle_human")
                        ) {
                            viewModel.config.showSilhouette.toggle()
                        }

                        canvasPillToggle(
                            icon: "grid",
                            isActive: viewModel.config.showGrid,
                            tooltip: L10n.tr("tip_toggle_grid")
                        ) {
                            viewModel.config.showGrid.toggle()
                        }

                        if viewModel.config.style.isHalftone {
                            canvasPillToggle(
                                icon: "eye",
                                isActive: viewModel.config.showOriginal,
                                tooltip: L10n.tr("tip_compare_original")
                            ) {
                                viewModel.config.showOriginal.toggle()
                                viewModel.refreshGeometryAndPreview(immediate: true)
                            }
                        }
                    }

                    Spacer()

                    if let geom = viewModel.geometry {
                        metricsCompactPill(geom: geom)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 9)

                Spacer()
            }
        }
    }

    private func canvasPillToggle(icon: String, isActive: Bool, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isActive ? .white : .primary)
                .frame(width: 32, height: 32)
                .liquidGlassCircle(tint: isActive ? themeManager.primaryAccent : nil, interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tooltip)
    }

    private func metricsCompactPill(geom: PosterGeometry) -> some View {
        let unitLabel = viewModel.config.unit == .inch ? L10n.tr("unit_in") : L10n.tr("unit_cm")
        let wStr = PosterGeometry.formatLength(mm: geom.posterWMM, unit: viewModel.config.unit)
        let hStr = PosterGeometry.formatLength(mm: geom.posterHMM, unit: viewModel.config.unit)
        let dpiColor = colorForDPIRating(geom.dpiRating)

        return HStack(spacing: 6) {
            Text("\(wStr)×\(hStr) \(unitLabel)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.primary)

            Text("·")
                .foregroundStyle(.secondary)

            Text("\(geom.activeSheets) \(L10n.tr("lbl_sheets_word"))")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(themeManager.primaryAccent)

            if !viewModel.config.style.isHalftone {
                Text("\(Int(geom.effectiveDPI.rounded()))")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundStyle(dpiColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(dpiColor.opacity(0.16), in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .liquidGlassCapsule(interactive: false)
    }

    private func colorForDPIRating(_ rating: DPIRating) -> Color {
        switch rating {
        case .excellent: return Color(uiColor: .systemGreen)
        case .good: return themeManager.primaryAccent
        case .medium: return Color(uiColor: .systemYellow)
        case .low: return Color(uiColor: .systemRed)
        }
    }

    // MARK: - Bottom / Side Inspector Container

    private var inspectorContainer: some View {
        VStack(spacing: 10) {
            // 4-Step Floating Liquid Glass Bar
            HStack(spacing: 4) {
                ForEach(StudioStep.allCases) { step in
                    let isSelected = viewModel.currentStep == step
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            viewModel.currentStep = step
                            if step != .image && viewModel.isCropMode {
                                viewModel.setCropMode(false)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: step.systemIcon)
                                .font(.system(size: 12, weight: .bold))
                            Text(L10n.tr(step.titleKey))
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 4)
                        .background(
                            Group {
                                if isSelected {
                                    Capsule()
                                        .fill(themeManager.primaryAccent)
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .liquidGlassCapsule(interactive: false)

            // Scrollable Controls for Selected Step
            ScrollView(showsIndicators: false) {
                StepControlsView(
                    viewModel: viewModel,
                    onPickPhotos: { showPhotosPicker = true },
                    onPickFiles: { showFileImporter = true },
                    onPromptURL: { showURLAlert = true }
                )
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Export Progress HUD

    private var exportProgressHUD: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView(value: viewModel.exportProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(themeManager.primaryAccent)
                    .frame(width: 210)

                Text(viewModel.exportStatusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .liquidGlassRoundedRect(cornerRadius: 24, interactive: false)
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        }
    }

    // MARK: - Image Import Helpers

    private func loadSelectedPhoto(_ item: PhotosPickerItem) {
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let name = item.itemIdentifier ?? "Photo"
                    viewModel.setLoadedImage(uiImage, name: name)
                } else {
                    viewModel.showToast(L10n.tr("err_load_image"))
                }
            } catch {
                viewModel.showToast("\(L10n.tr("err_load_image")): \(error.localizedDescription)")
            }
            selectedPhotoItem = nil
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                if let uiImage = UIImage(data: data) {
                    viewModel.setLoadedImage(uiImage, name: url.lastPathComponent)
                } else {
                    viewModel.showToast(L10n.tr("err_load_image"))
                }
            } catch {
                viewModel.showToast("\(L10n.tr("err_load_image")): \(error.localizedDescription)")
            }
        case .failure(let error):
            viewModel.showToast("\(L10n.tr("err_load_image")): \(error.localizedDescription)")
        }
    }
}
