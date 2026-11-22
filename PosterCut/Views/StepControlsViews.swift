import SwiftUI

/// Step-by-step Liquid Glass inspector controls (Steps 1-4) designed for fast one-hand iPhone & iPad use.
struct StepControlsView: View {
    @ObservedObject var viewModel: PosterStudioViewModel
    let onPickPhotos: () -> Void
    let onPickFiles: () -> Void
    let onPromptURL: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            switch viewModel.currentStep {
            case .image:
                ImageStepControls(
                    viewModel: viewModel,
                    onPickPhotos: onPickPhotos,
                    onPickFiles: onPickFiles,
                    onPromptURL: onPromptURL
                )
            case .paper:
                PaperStepControls(viewModel: viewModel)
            case .style:
                StyleStepControls(viewModel: viewModel)
            case .export:
                ExportStepControls(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Reusable Glass Card Container

private struct GlassSectionCard<Content: View>: View {
    let title: String?
    let trailing: AnyView?
    @ViewBuilder let content: () -> Content

    init(title: String? = nil, trailing: AnyView? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            if title != nil || trailing != nil {
                HStack(alignment: .center) {
                    if let title {
                        Text(title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                    Spacer(minLength: 4)
                    if let trailing {
                        trailing
                    }
                }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassRoundedRect(cornerRadius: 20, interactive: false)
    }
}

// MARK: - Step 1: Image & Transforms

private struct ImageStepControls: View {
    @ObservedObject var viewModel: PosterStudioViewModel
    @ObservedObject private var themeManager = PosterThemeManager.shared

    let onPickPhotos: () -> Void
    let onPickFiles: () -> Void
    let onPromptURL: () -> Void

    var body: some View {
        let dims = viewModel.croppedPixelSize
        let mp = Double(dims.w * dims.h) / 1_000_000.0

        VStack(spacing: 12) {
            GlassSectionCard(title: L10n.tr("sec_source_image")) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(themeManager.primaryAccent.opacity(0.15))
                            .frame(width: 42, height: 42)
                        Image(systemName: "photo.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(themeManager.primaryAccent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.sourceName.isEmpty ? L10n.tr("step_image") : viewModel.sourceName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(String(format: "%d × %d px · %.1f MP", dims.w, dims.h, mp))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    sourceActionButton(icon: "photo.on.rectangle", title: L10n.tr("btn_change_image"), tint: themeManager.primaryAccent, action: onPickPhotos)
                    sourceActionButton(icon: "folder", title: L10n.tr("ios_from_files"), tint: nil, action: onPickFiles)
                    sourceActionButton(icon: "doc.on.clipboard", title: L10n.tr("btn_paste_clipboard"), tint: nil, action: viewModel.pasteFromClipboard)
                    sourceActionButton(icon: "link", title: L10n.tr("btn_from_url"), tint: nil, action: onPromptURL)
                }
            }

            GlassSectionCard(title: L10n.tr("sec_transforms")) {
                HStack(spacing: 8) {
                    transformButton(icon: "rotate.left", label: L10n.tr("tip_rotate_left")) {
                        viewModel.rotate(by: -90)
                    }
                    transformButton(icon: "rotate.right", label: L10n.tr("tip_rotate_right")) {
                        viewModel.rotate(by: 90)
                    }
                    transformButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", label: L10n.tr("tip_flip_h")) {
                        viewModel.flip(horizontal: true)
                    }
                    transformButton(icon: "arrow.up.and.down.righttriangle.up.righttriangle.down", label: L10n.tr("tip_flip_v")) {
                        viewModel.flip(horizontal: false)
                    }
                }
            }

            GlassSectionCard(title: L10n.tr("sec_crop")) {
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            viewModel.setCropMode(!viewModel.isCropMode)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isCropMode ? "checkmark.circle.fill" : "crop")
                                .font(.subheadline.weight(.semibold))
                            Text(viewModel.isCropMode ? L10n.tr("btn_apply_crop") : L10n.tr("btn_crop_mode"))
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(viewModel.isCropMode ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .liquidGlassCapsule(
                            tint: viewModel.isCropMode ? themeManager.primaryAccent : nil,
                            interactive: true
                        )
                    }
                    .buttonStyle(.plain)

                    if !viewModel.config.crop.isFull {
                        Button {
                            viewModel.resetCrop()
                        } label: {
                            Text(L10n.tr("btn_reset_crop"))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .liquidGlassCapsule(interactive: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sourceActionButton(icon: String, title: String, tint: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(tint != nil ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .liquidGlassCapsule(tint: tint, interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func transformButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeManager.primaryAccent)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .liquidGlassRoundedRect(cornerRadius: 14, interactive: true)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 2: Paper, Size, Margins & Glue Overlap

private struct PaperStepControls: View {
    @ObservedObject var viewModel: PosterStudioViewModel
    @ObservedObject private var themeManager = PosterThemeManager.shared

    private let quickSheetPresets: [Double] = [1, 2, 2.5, 3, 4, 5, 6, 8]

    var body: some View {
        VStack(spacing: 12) {
            // Paper Preset & Orientation
            GlassSectionCard(title: L10n.tr("sec_paper_format")) {
                HStack {
                    Text(L10n.tr("lbl_paper_size"))
                        .font(.subheadline)
                    Spacer()
                    Picker(L10n.tr("lbl_paper_size"), selection: Binding(
                        get: { viewModel.config.paperID },
                        set: { newID in
                            viewModel.config.paperID = newID
                            viewModel.refreshGeometryAndPreview()
                        }
                    )) {
                        ForEach(PaperPreset.all) { preset in
                            Text(L10n.paperName(preset)).tag(preset.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.primaryAccent)
                }

                if viewModel.config.paperID == "custom" {
                    HStack(spacing: 10) {
                        mmStepperField(
                            title: L10n.tr("lbl_width_mm"),
                            value: Binding(
                                get: { viewModel.config.customWidthMM },
                                set: { viewModel.config.customWidthMM = max(50, min(1500, $0)); viewModel.refreshGeometryAndPreview() }
                            ),
                            range: 50...1500,
                            step: 5
                        )
                        mmStepperField(
                            title: L10n.tr("lbl_height_mm"),
                            value: Binding(
                                get: { viewModel.config.customHeightMM },
                                set: { viewModel.config.customHeightMM = max(50, min(1500, $0)); viewModel.refreshGeometryAndPreview() }
                            ),
                            range: 50...1500,
                            step: 5
                        )
                    }
                }

                HStack(spacing: 8) {
                    Picker(L10n.tr("lbl_orientation"), selection: Binding(
                        get: { viewModel.config.landscape },
                        set: { newVal in
                            viewModel.config.landscape = newVal
                            viewModel.refreshGeometryAndPreview()
                        }
                    )) {
                        Label(L10n.tr("orient_portrait"), systemImage: "rectangle.portrait").tag(false)
                        Label(L10n.tr("orient_landscape"), systemImage: "rectangle").tag(true)
                    }
                    .pickerStyle(.segmented)

                    Button {
                        viewModel.optimizeOrientation()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                                .font(.caption.weight(.bold))
                            Text(L10n.tr("btn_optimize"))
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(themeManager.primaryAccent)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .liquidGlassCapsule(tint: themeManager.primaryAccent.opacity(0.14), interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Output Size (Sheets decimal or Physical cm/in)
            GlassSectionCard(title: L10n.tr("sec_output_size")) {
                Picker("", selection: Binding(
                    get: { viewModel.config.sizeMode },
                    set: { mode in
                        if mode == .physical, let g = viewModel.geometry {
                            viewModel.config.physicalValueCM = ((g.posterWMM / 10.0) * 10.0).rounded() / 10.0
                            viewModel.config.physicalAxis = .wide
                        }
                        viewModel.config.sizeMode = mode
                        viewModel.refreshGeometryAndPreview()
                    }
                )) {
                    Text(L10n.tr("size_by_sheets")).tag(SizeMode.sheets)
                    Text(L10n.tr("size_by_physical")).tag(SizeMode.physical)
                }
                .pickerStyle(.segmented)

                if viewModel.config.sizeMode == .sheets {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.1f %@", viewModel.config.sheetsValue, L10n.tr("lbl_sheets_word")))
                                .font(.title3.weight(.bold).monospacedDigit())
                                .foregroundStyle(themeManager.primaryAccent)
                            Text(L10n.tr("hint_decimal_sheets"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Stepper(
                            "",
                            value: Binding(
                                get: { viewModel.config.sheetsValue },
                                set: { viewModel.config.sheetsValue = max(0.5, min(25.0, ($0 * 10).rounded() / 10)); viewModel.refreshGeometryAndPreview() }
                            ),
                            in: 0.5...25.0,
                            step: 0.5
                        )
                        .labelsHidden()
                    }

                    Slider(
                        value: Binding(
                            get: { min(12.0, viewModel.config.sheetsValue) },
                            set: { viewModel.config.sheetsValue = ($0 * 10).rounded() / 10; viewModel.refreshGeometryAndPreview() }
                        ),
                        in: 0.5...12.0,
                        step: 0.1
                    )
                    .tint(themeManager.primaryAccent)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(quickSheetPresets, id: \.self) { val in
                                let active = abs(viewModel.config.sheetsValue - val) < 0.05
                                Button {
                                    viewModel.config.sheetsValue = val
                                    viewModel.refreshGeometryAndPreview()
                                } label: {
                                    Text(val == floor(val) ? "\(Int(val))" : String(format: "%.1f", val))
                                        .font(.caption.weight(.bold).monospacedDigit())
                                        .foregroundStyle(active ? .white : .primary)
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6)
                                        .liquidGlassCapsule(tint: active ? themeManager.primaryAccent : nil, interactive: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Picker("", selection: Binding(
                        get: { viewModel.config.sheetsAxis },
                        set: { viewModel.config.sheetsAxis = $0; viewModel.refreshGeometryAndPreview() }
                    )) {
                        Text(L10n.tr("axis_wide")).tag(SizeAxis.wide)
                        Text(L10n.tr("axis_high")).tag(SizeAxis.high)
                    }
                    .pickerStyle(.segmented)
                } else {
                    let isInch = viewModel.config.unit == .inch
                    let displayVal = isInch ? (viewModel.config.physicalValueCM / 2.54) : viewModel.config.physicalValueCM
                    let unitLabel = isInch ? L10n.tr("unit_in") : L10n.tr("unit_cm")

                    HStack {
                        Text(String(format: "%.1f %@", displayVal, unitLabel))
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(themeManager.primaryAccent)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { viewModel.config.unit },
                            set: { viewModel.config.unit = $0; viewModel.refreshGeometryAndPreview() }
                        )) {
                            Text(L10n.tr("unit_cm")).tag(LengthUnit.cm)
                            Text(L10n.tr("unit_in")).tag(LengthUnit.inch)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 112)
                    }

                    Slider(
                        value: Binding(
                            get: { min(350.0, viewModel.config.physicalValueCM) },
                            set: { viewModel.config.physicalValueCM = $0.rounded(); viewModel.refreshGeometryAndPreview() }
                        ),
                        in: 10.0...350.0,
                        step: 1.0
                    )
                    .tint(themeManager.primaryAccent)

                    HStack {
                        Picker("", selection: Binding(
                            get: { viewModel.config.physicalAxis },
                            set: { viewModel.config.physicalAxis = $0; viewModel.refreshGeometryAndPreview() }
                        )) {
                            Text(L10n.tr("axis_wide")).tag(SizeAxis.wide)
                            Text(L10n.tr("axis_high")).tag(SizeAxis.high)
                        }
                        .pickerStyle(.segmented)

                        Stepper(
                            "",
                            value: Binding(
                                get: { viewModel.config.physicalValueCM },
                                set: { viewModel.config.physicalValueCM = max(5.0, min(800.0, $0)); viewModel.refreshGeometryAndPreview() }
                            ),
                            in: 5.0...800.0,
                            step: 1.0
                        )
                        .labelsHidden()
                    }
                }
            }

            // Margins & Glue Overlap
            GlassSectionCard(title: L10n.tr("sec_margins_overlap")) {
                Toggle(isOn: Binding(
                    get: { viewModel.config.marginEnabled },
                    set: { viewModel.config.marginEnabled = $0; viewModel.refreshGeometryAndPreview() }
                )) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.tr("lbl_white_margin"))
                            .font(.subheadline.weight(.medium))
                        Text(viewModel.config.marginEnabled ? String(format: "%.0f mm", viewModel.config.marginMM) : L10n.tr("lbl_borderless"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Color(uiColor: .systemGreen))

                if viewModel.config.marginEnabled {
                    Slider(
                        value: Binding(
                            get: { viewModel.config.marginMM },
                            set: { viewModel.config.marginMM = $0.rounded(); viewModel.refreshGeometryAndPreview() }
                        ),
                        in: 2...35,
                        step: 1
                    )
                    .tint(themeManager.primaryAccent)
                }

                Divider()

                Toggle(isOn: Binding(
                    get: { viewModel.config.overlapEnabled },
                    set: { viewModel.config.overlapEnabled = $0; viewModel.refreshGeometryAndPreview() }
                )) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.tr("lbl_glue_overlap"))
                            .font(.subheadline.weight(.medium))
                        Text(L10n.tr("lbl_glue_overlap_desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Color(uiColor: .systemGreen))

                if viewModel.config.overlapEnabled {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { viewModel.config.overlapMM },
                                set: { viewModel.config.overlapMM = $0.rounded(); viewModel.refreshGeometryAndPreview() }
                            ),
                            in: 2...25,
                            step: 1
                        )
                        .tint(themeManager.primaryAccent)

                        Text(String(format: "%.0f mm", viewModel.config.overlapMM))
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func mmStepperField(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                Text(String(format: "%.0f mm", value.wrappedValue))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Spacer(minLength: 2)
                Stepper("", value: value, in: range, step: step)
                    .labelsHidden()
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Step 3: Visual Styles, Photo Enhancements & Halftone Colors

private struct StyleStepControls: View {
    @ObservedObject var viewModel: PosterStudioViewModel
    @ObservedObject private var themeManager = PosterThemeManager.shared

    var body: some View {
        VStack(spacing: 12) {
            GlassSectionCard(title: L10n.tr("sec_visual_style")) {
                VStack(spacing: 8) {
                    ForEach(PosterStyle.allCases) { style in
                        StyleOptionCard(
                            style: style,
                            thumbnail: viewModel.styleThumbnails[style],
                            isSelected: viewModel.config.style == style,
                            accent: themeManager.primaryAccent
                        ) {
                            viewModel.applyStyle(style)
                        }
                    }
                }
            }

            if viewModel.config.style == .original {
                GlassSectionCard(
                    title: L10n.tr("sec_photo_adjust"),
                    trailing: AnyView(
                        Button(L10n.tr("btn_reset_adjust")) {
                            viewModel.resetPhotoAdjustments()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeManager.primaryAccent)
                    )
                ) {
                    percentSlider(
                        title: L10n.tr("lbl_brightness"),
                        value: Binding(
                            get: { viewModel.config.brightness },
                            set: { viewModel.config.brightness = $0; viewModel.refreshGeometryAndPreview() }
                        ),
                        range: -0.5...0.5
                    )
                    percentSlider(
                        title: L10n.tr("lbl_contrast"),
                        value: Binding(
                            get: { viewModel.config.contrast },
                            set: { viewModel.config.contrast = $0; viewModel.refreshGeometryAndPreview() }
                        ),
                        range: -0.5...0.5
                    )
                    percentSlider(
                        title: L10n.tr("lbl_sharpness"),
                        value: Binding(
                            get: { viewModel.config.sharpness },
                            set: { viewModel.config.sharpness = $0; viewModel.refreshGeometryAndPreview() }
                        ),
                        range: 0.0...1.0
                    )

                    Toggle(L10n.tr("lbl_grayscale_clean"), isOn: Binding(
                        get: { viewModel.config.grayscaleClean },
                        set: { viewModel.config.grayscaleClean = $0; viewModel.refreshGeometryAndPreview() }
                    ))
                    .font(.subheadline)
                    .tint(Color(uiColor: .systemGreen))
                }
            } else {
                GlassSectionCard(title: L10n.tr("sec_halftone_params")) {
                    labeledSlider(
                        title: L10n.tr("lbl_dot_size"),
                        value: Binding(
                            get: { viewModel.config.dotSizeMM },
                            set: { viewModel.config.dotSizeMM = ($0 * 2).rounded() / 2; viewModel.refreshGeometryAndPreview() }
                        ),
                        range: 2.0...28.0,
                        suffix: " mm"
                    )

                    labeledSlider(
                        title: L10n.tr("lbl_grid_angle"),
                        value: Binding(
                            get: { viewModel.config.gridAngle },
                            set: { viewModel.config.gridAngle = $0.rounded(); viewModel.refreshGeometryAndPreview() }
                        ),
                        range: 0...45,
                        suffix: "°"
                    )
                }

                GlassSectionCard(title: L10n.tr("sec_color_palettes")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(ColorPreset.all) { preset in
                            let selected = viewModel.config.colorMode == preset.colorMode
                                && viewModel.config.bgMode == preset.bgMode
                                && viewModel.config.rasterHex.caseInsensitiveCompare(preset.rasterHex) == .orderedSame
                                && viewModel.config.bgHex.caseInsensitiveCompare(preset.bgHex) == .orderedSame
                            ColorPresetSwatchButton(
                                preset: preset,
                                isSelected: selected,
                                accent: themeManager.primaryAccent
                            ) {
                                viewModel.applyColorPreset(preset)
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.tr("lbl_raster_color"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("", selection: Binding(
                            get: { viewModel.config.colorMode },
                            set: { viewModel.config.colorMode = $0; viewModel.refreshGeometryAndPreview() }
                        )) {
                            Text(L10n.tr("color_black")).tag(ColorMode.black)
                            Text(L10n.tr("color_single")).tag(ColorMode.single)
                            Text(L10n.tr("color_multi")).tag(ColorMode.multicolor)
                        }
                        .pickerStyle(.segmented)

                        if viewModel.config.colorMode == .single {
                            ColorPicker(
                                L10n.tr("lbl_pick_raster_color"),
                                selection: Binding(
                                    get: { Color(hex: viewModel.config.rasterHex) },
                                    set: { viewModel.config.rasterHex = $0.toHexString; viewModel.refreshGeometryAndPreview() }
                                ),
                                supportsOpacity: false
                            )
                            .font(.subheadline)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.tr("lbl_bg_color"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("", selection: Binding(
                            get: { viewModel.config.bgMode },
                            set: { viewModel.config.bgMode = $0; viewModel.refreshGeometryAndPreview() }
                        )) {
                            Text(L10n.tr("bg_white")).tag(BgMode.white)
                            Text(L10n.tr("bg_single")).tag(BgMode.single)
                            Text(L10n.tr("bg_transparent")).tag(BgMode.transparent)
                        }
                        .pickerStyle(.segmented)

                        if viewModel.config.bgMode == .single {
                            ColorPicker(
                                L10n.tr("lbl_pick_bg_color"),
                                selection: Binding(
                                    get: { Color(hex: viewModel.config.bgHex) },
                                    set: { viewModel.config.bgHex = $0.toHexString; viewModel.refreshGeometryAndPreview() }
                                ),
                                supportsOpacity: false
                            )
                            .font(.subheadline)
                        }
                    }
                }
            }
        }
    }

    private func labeledSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f%@", value.wrappedValue, suffix))
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .tint(themeManager.primaryAccent)
        }
    }

    private func percentSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                let pct = Int((value.wrappedValue * 100.0).rounded())
                Text(pct > 0 ? "+\(pct)%" : "\(pct)%")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .tint(themeManager.primaryAccent)
        }
    }
}

// MARK: - Step 4: Export, Built-In Sheet Preview & Direct AirPrint

private struct ExportStepControls: View {
    @ObservedObject var viewModel: PosterStudioViewModel
    @ObservedObject private var themeManager = PosterThemeManager.shared

    var body: some View {
        let activeCount = viewModel.geometry?.activeSheets ?? 0

        VStack(spacing: 12) {
            // Primary Share + Sheet Preview + AirPrint Action Suite
            GlassSectionCard {
                Button {
                    viewModel.exportAndShare()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.config.exportFormat == .pdf ? "doc.richtext.fill" : "photo.stack.fill")
                            .font(.headline)
                        Text(
                            viewModel.config.exportFormat == .pdf
                                ? L10n.fmt("ios_share_pdf_fmt", activeCount)
                                : L10n.fmt("ios_share_png_fmt", activeCount)
                        )
                        .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .liquidGlassCapsule(tint: themeManager.primaryAccent, interactive: true)
                }
                .buttonStyle(.plain)
                .disabled(activeCount == 0 || viewModel.isExporting)

                HStack(spacing: 10) {
                    Button {
                        viewModel.showSheetPreview = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.grid.2x2")
                                .font(.subheadline.weight(.semibold))
                            Text(L10n.tr("btn_preview_sheets"))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .liquidGlassCapsule(interactive: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(activeCount == 0)

                    Button {
                        viewModel.printDirectlyWithAirPrint()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "printer.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(themeManager.primaryAccent)
                            Text(L10n.tr("ios_airprint"))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .liquidGlassCapsule(tint: themeManager.primaryAccent.opacity(0.14), interactive: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(activeCount == 0 || viewModel.isExporting)
                }

                if !viewModel.config.excludedTiles.isEmpty {
                    Button {
                        viewModel.restoreAllTiles()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .foregroundStyle(themeManager.primaryAccent)
                            Text(L10n.fmt("btn_restore_excluded_fmt", viewModel.config.excludedTiles.count))
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .liquidGlassCapsule(interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Export Format & Lossless Quality
            GlassSectionCard(title: L10n.tr("sec_export_format")) {
                Picker("", selection: Binding(
                    get: { viewModel.config.exportFormat },
                    set: { viewModel.config.exportFormat = $0 }
                )) {
                    Text(L10n.tr("fmt_pdf")).tag(ExportFormat.pdf)
                    Text(L10n.tr("fmt_png_tiles")).tag(ExportFormat.png)
                }
                .pickerStyle(.segmented)

                if viewModel.config.exportFormat == .pdf {
                    Toggle(isOn: Binding(
                        get: { viewModel.config.pdfLossless },
                        set: { viewModel.config.pdfLossless = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("lbl_pdf_lossless"))
                                .font(.subheadline.weight(.medium))
                            Text(L10n.tr("lbl_pdf_lossless_desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(Color(uiColor: .systemGreen))
                } else {
                    HStack {
                        Text(L10n.tr("lbl_png_dpi"))
                            .font(.subheadline)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { viewModel.config.pngDPI },
                            set: { viewModel.config.pngDPI = $0 }
                        )) {
                            Text("150 DPI").tag(150)
                            Text("300 DPI").tag(300)
                            Text("600 DPI").tag(600)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 210)
                    }
                }
            }

            // Printing Guides & Assembly Map
            GlassSectionCard(title: L10n.tr("sec_guides_options")) {
                Toggle(L10n.tr("lbl_crop_marks"), isOn: Binding(
                    get: { viewModel.config.cropMarks },
                    set: { viewModel.config.cropMarks = $0 }
                ))
                .font(.subheadline)
                .tint(Color(uiColor: .systemGreen))

                Toggle(L10n.tr("lbl_page_coords"), isOn: Binding(
                    get: { viewModel.config.pageCoords },
                    set: { viewModel.config.pageCoords = $0 }
                ))
                .font(.subheadline)
                .tint(Color(uiColor: .systemGreen))

                Toggle(L10n.tr("lbl_skip_blank"), isOn: Binding(
                    get: { viewModel.config.skipBlankPages },
                    set: { viewModel.config.skipBlankPages = $0 }
                ))
                .font(.subheadline)
                .tint(Color(uiColor: .systemGreen))

                Toggle(isOn: Binding(
                    get: { viewModel.config.includeAssemblyMap },
                    set: { viewModel.config.includeAssemblyMap = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("lbl_assembly_map"))
                            .font(.subheadline)
                        Text(L10n.tr("lbl_assembly_map_desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Color(uiColor: .systemGreen))
            }
        }
    }
}
