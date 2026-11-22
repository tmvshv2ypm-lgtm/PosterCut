import SwiftUI

/// Step-by-step inspector controls (Steps 1-4) designed for fast one-hand iPhone & iPad use
/// with lightweight native surfaces inside scroll views (cool GPU & 60/120fps scrolling).
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

// MARK: - Reusable Lightweight Section Card

private struct StudioSectionCard<Content: View>: View {
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
        .studioCardSurface(cornerRadius: 20)
    }
}

// MARK: - Step 1: Image & Transforms

private struct ImageStepControls: View {
    @ObservedObject var viewModel: PosterStudioViewModel
    @ObservedObject private var themeManager = PosterThemeManager.shared

    let onPickPhotos: () -> Void
    let onPickFiles: () -> Void
    let onPromptURL: () -> Void

    private var accent: Color { themeManager.accent(for: .image) }

    var body: some View {
        let dims = viewModel.croppedPixelSize
        let mp = Double(dims.w * dims.h) / 1_000_000.0

        VStack(spacing: 12) {
            StudioSectionCard(title: L10n.tr("sec_source_image")) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(accent.opacity(0.16))
                            .frame(width: 42, height: 42)
                        Image(systemName: "photo.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accent)
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
                    sourceActionButton(icon: "photo.on.rectangle", title: L10n.tr("btn_change_image"), tint: accent, action: onPickPhotos)
                    sourceActionButton(icon: "folder", title: L10n.tr("ios_from_files"), tint: nil, action: onPickFiles)
                    sourceActionButton(icon: "doc.on.clipboard", title: L10n.tr("btn_paste_clipboard"), tint: nil, action: viewModel.pasteFromClipboard)
                    sourceActionButton(icon: "link", title: L10n.tr("btn_from_url"), tint: nil, action: onPromptURL)
                }
            }

            StudioSectionCard(title: L10n.tr("sec_transforms")) {
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

            StudioSectionCard(title: L10n.tr("sec_crop")) {
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
                        .background(
                            Capsule().fill(viewModel.isCropMode ? accent : Color(uiColor: .tertiarySystemFill))
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
                                .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
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
            .background(Capsule().fill(tint ?? Color(uiColor: .tertiarySystemFill)))
        }
        .buttonStyle(.plain)
    }

    private func transformButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 2: Paper, Size, Margins & Glue Overlap

private struct PaperStepControls: View {
    @ObservedObject var viewModel: PosterStudioViewModel
    @ObservedObject private var themeManager = PosterThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    private let quickSheetPresets: [Double] = [1, 2, 2.5, 3, 4, 5, 6, 8]
    private var accent: Color { themeManager.accent(for: .paper) }

    var body: some View {
        VStack(spacing: 12) {
            // Paper Preset & Orientation
            StudioSectionCard(title: L10n.tr("sec_paper_format")) {
                HStack(spacing: 8) {
                    Text(L10n.tr("lbl_paper_size"))
                        .font(.subheadline)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 4)
                    Picker(L10n.tr("lbl_paper_size"), selection: Binding(
                        get: { viewModel.config.paperID },
                        set: { newID in
                            viewModel.config.paperID = newID
                            viewModel.onGeometrySettingChanged()
                        }
                    )) {
                        ForEach(PaperPreset.all) { preset in
                            Text(L10n.paperName(preset)).tag(preset.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }

                if viewModel.config.paperID == "custom" {
                    HStack(spacing: 10) {
                        mmStepperField(
                            title: L10n.tr("lbl_width_mm"),
                            value: Binding(
                                get: { viewModel.config.customWidthMM },
                                set: { viewModel.config.customWidthMM = max(50, min(1500, $0)); viewModel.onGeometrySettingChanged() }
                            ),
                            range: 50...1500,
                            step: 5
                        )
                        mmStepperField(
                            title: L10n.tr("lbl_height_mm"),
                            value: Binding(
                                get: { viewModel.config.customHeightMM },
                                set: { viewModel.config.customHeightMM = max(50, min(1500, $0)); viewModel.onGeometrySettingChanged() }
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
                            viewModel.onGeometrySettingChanged()
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
                                .lineLimit(1)
                        }
                        .foregroundStyle(colorScheme == .dark ? .white : accent)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(accent.opacity(colorScheme == .dark ? 0.28 : 0.14))
                        )
                        .overlay(
                            Capsule().strokeBorder(accent.opacity(colorScheme == .dark ? 0.65 : 0.35), lineWidth: 1.0)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Output Size (Sheets decimal or Physical cm/in)
            StudioSectionCard(title: L10n.tr("sec_output_size")) {
                Picker("", selection: Binding(
                    get: { viewModel.config.sizeMode },
                    set: { mode in
                        if mode == .physical, let g = viewModel.geometry {
                            viewModel.config.physicalValueCM = ((g.posterWMM / 10.0) * 10.0).rounded() / 10.0
                            viewModel.config.physicalAxis = .wide
                        }
                        viewModel.config.sizeMode = mode
                        viewModel.onGeometrySettingChanged()
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
                                .foregroundStyle(accent)
                            Text(L10n.tr("hint_decimal_sheets"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Stepper(
                            "",
                            value: Binding(
                                get: { viewModel.config.sheetsValue },
                                set: { viewModel.config.sheetsValue = max(0.5, min(25.0, ($0 * 10).rounded() / 10)); viewModel.onGeometrySettingChanged() }
                            ),
                            in: 0.5...25.0,
                            step: 0.5
                        )
                        .labelsHidden()
                    }

                    Slider(
                        value: Binding(
                            get: { min(12.0, viewModel.config.sheetsValue) },
                            set: { viewModel.config.sheetsValue = ($0 * 10).rounded() / 10; viewModel.onGeometrySettingChanged() }
                        ),
                        in: 0.5...12.0,
                        step: 0.1
                    )
                    .tint(accent)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(quickSheetPresets, id: \.self) { val in
                                let active = abs(viewModel.config.sheetsValue - val) < 0.05
                                Button {
                                    viewModel.config.sheetsValue = val
                                    viewModel.onGeometrySettingChanged()
                                } label: {
                                    Text(val == floor(val) ? "\(Int(val))" : String(format: "%.1f", val))
                                        .font(.caption.weight(.bold).monospacedDigit())
                                        .foregroundStyle(active ? .white : .primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule().fill(active ? accent : Color(uiColor: .tertiarySystemFill))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Picker("", selection: Binding(
                        get: { viewModel.config.sheetsAxis },
                        set: { viewModel.config.sheetsAxis = $0; viewModel.onGeometrySettingChanged() }
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
                            .foregroundStyle(accent)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { viewModel.config.unit },
                            set: { viewModel.config.unit = $0; viewModel.onGeometrySettingChanged() }
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
                            set: { viewModel.config.physicalValueCM = $0.rounded(); viewModel.onGeometrySettingChanged() }
                        ),
                        in: 10.0...350.0,
                        step: 1.0
                    )
                    .tint(accent)

                    HStack {
                        Picker("", selection: Binding(
                            get: { viewModel.config.physicalAxis },
                            set: { viewModel.config.physicalAxis = $0; viewModel.onGeometrySettingChanged() }
                        )) {
                            Text(L10n.tr("axis_wide")).tag(SizeAxis.wide)
                            Text(L10n.tr("axis_high")).tag(SizeAxis.high)
                        }
                        .pickerStyle(.segmented)

                        Stepper(
                            "",
                            value: Binding(
                                get: { viewModel.config.physicalValueCM },
                                set: { viewModel.config.physicalValueCM = max(5.0, min(800.0, $0)); viewModel.onGeometrySettingChanged() }
                            ),
                            in: 5.0...800.0,
                            step: 1.0
                        )
                        .labelsHidden()
                    }
                }
            }

            // Margins & Glue Overlap
            StudioSectionCard(title: L10n.tr("sec_margins_overlap")) {
                Toggle(isOn: Binding(
                    get: { viewModel.config.marginEnabled },
                    set: { viewModel.config.marginEnabled = $0; viewModel.onGeometrySettingChanged() }
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
                            set: { viewModel.config.marginMM = $0.rounded(); viewModel.onGeometrySettingChanged() }
                        ),
                        in: 2...35,
                        step: 1
                    )
                    .tint(accent)
                }

                Divider()

                Toggle(isOn: Binding(
                    get: { viewModel.config.overlapEnabled },
                    set: { viewModel.config.overlapEnabled = $0; viewModel.onGeometrySettingChanged() }
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
                                set: { viewModel.config.overlapMM = $0.rounded(); viewModel.onGeometrySettingChanged() }
                            ),
                            in: 2...25,
                            step: 1
                        )
                        .tint(accent)

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
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Step 3: Visual Styles, Photo Enhancements & Halftone Colors

private struct StyleStepControls: View {
    @ObservedObject var viewModel: PosterStudioViewModel
    @ObservedObject private var themeManager = PosterThemeManager.shared

    private var accent: Color { themeManager.accent(for: .style) }

    var body: some View {
        VStack(spacing: 12) {
            StudioSectionCard(title: L10n.tr("sec_visual_style")) {
                VStack(spacing: 8) {
                    ForEach(PosterStyle.allCases) { style in
                        StyleOptionCard(
                            style: style,
                            thumbnail: viewModel.styleThumbnails[style],
                            isSelected: viewModel.config.style == style,
                            accent: accent
                        ) {
                            viewModel.applyStyle(style)
                        }
                    }
                }
            }

            if viewModel.config.style == .original {
                StudioSectionCard(
                    title: L10n.tr("sec_photo_adjust"),
                    trailing: AnyView(
                        Button(L10n.tr("btn_reset_adjust")) {
                            viewModel.resetPhotoAdjustments()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
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
                StudioSectionCard(title: L10n.tr("sec_halftone_params")) {
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

                StudioSectionCard(title: L10n.tr("sec_color_palettes")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(ColorPreset.all) { preset in
                            let selected = viewModel.config.colorMode == preset.colorMode
                                && viewModel.config.bgMode == preset.bgMode
                                && viewModel.config.rasterHex.caseInsensitiveCompare(preset.rasterHex) == .orderedSame
                                && viewModel.config.bgHex.caseInsensitiveCompare(preset.bgHex) == .orderedSame
                            ColorPresetSwatchButton(
                                preset: preset,
                                isSelected: selected,
                                accent: accent
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
                .tint(accent)
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
                .tint(accent)
        }
    }
}

// MARK: - Step 4: Export, Built-In Sheet Preview & Direct AirPrint

private struct ExportStepControls: View {
    @ObservedObject var viewModel: PosterStudioViewModel
    @ObservedObject private var themeManager = PosterThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color { themeManager.accent(for: .export) }

    var body: some View {
        let activeCount = viewModel.geometry?.activeSheets ?? 0

        VStack(spacing: 12) {
            // Primary Share + Sheet Preview + AirPrint Action Suite
            StudioSectionCard {
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
                    .liquidGlassCapsule(tint: accent, interactive: true)
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
                        .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
                    }
                    .buttonStyle(.plain)
                    .disabled(activeCount == 0)

                    Button {
                        viewModel.printDirectlyWithAirPrint()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "printer.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(colorScheme == .dark ? .white : accent)
                            Text(L10n.tr("ios_airprint"))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(colorScheme == .dark ? .white : accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(accent.opacity(colorScheme == .dark ? 0.28 : 0.14)))
                        .overlay(Capsule().strokeBorder(accent.opacity(colorScheme == .dark ? 0.62 : 0.34), lineWidth: 1.0))
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
                                .foregroundStyle(accent)
                            Text(L10n.fmt("btn_restore_excluded_fmt", viewModel.config.excludedTiles.count))
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Export Format & Lossless Quality
            StudioSectionCard(title: L10n.tr("sec_export_format")) {
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
            StudioSectionCard(title: L10n.tr("sec_guides_options")) {
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
