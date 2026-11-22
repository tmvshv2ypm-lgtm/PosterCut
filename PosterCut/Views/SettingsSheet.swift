import SwiftUI
import UIKit

/// Clean Apple Liquid Glass Settings sheet matching Voice Notes:
/// Appearance (System / Light / Dark), Subtle Liquid Glass Theme Picker with live preview,
/// Default Paper & Units, and the dedicated "Información de la aplicación" card presenting Mosaika.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PosterStudioViewModel
    @ObservedObject private var themeManager = PosterThemeManager.shared

    private var appVersionString: String {
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v\(ver)"
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Appearance & Liquid Glass Theme
                Section {
                    Picker(selection: $themeManager.appearance) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Text(L10n.tr(mode.titleKey)).tag(mode)
                        }
                    } label: {
                        Label {
                            Text(L10n.tr("ios_appearance_mode"))
                        } icon: {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundStyle(themeManager.primaryAccent)
                        }
                    }
                    .pickerStyle(.segmented)

                    NavigationLink {
                        PosterThemePickerView()
                    } label: {
                        HStack(spacing: 12) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.tr("ios_theme_title"))
                                        .foregroundStyle(.primary)
                                    Text(L10n.tr("ios_theme_subtitle"))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "paintpalette.fill")
                                    .foregroundStyle(themeManager.primaryAccent)
                            }

                            Spacer(minLength: 6)

                            HStack(spacing: 6) {
                                Text(L10n.tr(themeManager.currentTheme.titleKey))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(themeManager.primaryAccent)

                                HStack(spacing: 3) {
                                    ForEach(Array(themeManager.currentTheme.swatchColors.prefix(4).enumerated()), id: \.offset) { _, swatch in
                                        Circle()
                                            .fill(swatch)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text(L10n.tr("ios_appearance_section"))
                }

                // MARK: - Default Studio Preferences
                Section {
                    Picker(selection: $themeManager.defaultPaperID) {
                        ForEach(PaperPreset.all.filter { $0.id != "custom" }) { preset in
                            Text(L10n.paperName(preset)).tag(preset.id)
                        }
                    } label: {
                        Label {
                            Text(L10n.tr("lbl_paper_size"))
                        } icon: {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(themeManager.primaryAccent)
                        }
                    }
                    .onChange(of: themeManager.defaultPaperID) { _, newPaper in
                        if !viewModel.hasImage {
                            viewModel.config.paperID = newPaper
                        }
                    }

                    Picker(selection: $themeManager.defaultUnit) {
                        Text(L10n.tr("unit_cm")).tag(LengthUnit.cm)
                        Text(L10n.tr("unit_in")).tag(LengthUnit.inch)
                    } label: {
                        Label {
                            Text(L10n.tr("ios_default_units"))
                        } icon: {
                            Image(systemName: "ruler.fill")
                                .foregroundStyle(themeManager.primaryAccent)
                        }
                    }
                    .onChange(of: themeManager.defaultUnit) { _, newUnit in
                        viewModel.config.unit = newUnit
                    }
                } header: {
                    Text(L10n.tr("ios_defaults_section"))
                }

                // MARK: - Información de la aplicación (Mosaika Identity Card)
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            PosterMarkView(size: 58)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Mosaika")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.primary)

                                HStack(spacing: 6) {
                                    Text("PosterCut")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(themeManager.primaryAccent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(themeManager.primaryAccent.opacity(0.14), in: Capsule())

                                    Text(appVersionString)
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer(minLength: 0)
                        }

                        Text(L10n.tr("ios_app_info_desc"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text(L10n.tr("ios_app_info_section"))
                }
            }
            .navigationTitle(L10n.tr("ios_settings_title"))
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.primaryAccent)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("btn_close")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

/// Subtle Liquid Glass Theme Picker with live preview card (inspired directly by Voice Notes).
struct PosterThemePickerView: View {
    @ObservedObject private var themeManager = PosterThemeManager.shared

    var body: some View {
        List {
            Section {
                liveStudioPreviewCard
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .listRowBackground(Color.clear)
            } header: {
                Text(L10n.tr("ios_theme_preview_header"))
            }

            Section {
                ForEach(PosterVisualTheme.allCases) { theme in
                    let isSelected = themeManager.currentTheme == theme
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                            themeManager.currentTheme = theme
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ThemeSwatchQuad(colors: theme.swatchColors, accent: theme.primaryAccent, isSelected: isSelected)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.tr(theme.titleKey))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.primary)

                                Text(L10n.tr(theme.subtitleKey))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                HStack(spacing: 5) {
                                    ForEach(Array(theme.swatchColors.enumerated()), id: \.offset) { _, swatch in
                                        Circle()
                                            .fill(swatch)
                                            .frame(width: 10, height: 10)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                                            )
                                    }
                                }
                                .padding(.top, 2)
                            }

                            Spacer(minLength: 6)

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(isSelected ? theme.primaryAccent : Color.secondary.opacity(0.35))
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(L10n.tr("ios_theme_list_header"))
            } footer: {
                Text(L10n.tr("ios_theme_footer"))
            }
        }
        .navigationTitle(L10n.tr("ios_theme_title"))
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeManager.primaryAccent)
    }

    private var liveStudioPreviewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .systemGroupedBackground))

            RadialGradient(
                colors: [themeManager.primaryAccent.opacity(0.16), .clear],
                center: UnitPoint(x: 0.15, y: 0.15),
                startRadius: 4,
                endRadius: 150
            )

            RadialGradient(
                colors: [themeManager.secondaryGlow.opacity(0.14), .clear],
                center: UnitPoint(x: 0.85, y: 0.85),
                startRadius: 4,
                endRadius: 140
            )

            VStack(spacing: 12) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(StudioStep.allCases) { step in
                        let tileColor = themeManager.currentTheme.stepAccent(step)
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(tileColor.opacity(0.22))
                                    .frame(width: 28, height: 28)
                                Image(systemName: step.systemIcon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(tileColor)
                            }

                            Text(L10n.tr(step.titleKey))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(tileColor.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(tileColor.opacity(0.24), lineWidth: 0.8)
                        )
                    }
                }

                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        PosterMarkView(size: 22)
                        Text("60 × 80 cm · 6 \(L10n.tr("lbl_sheets_word"))")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption2.weight(.bold))
                        Text(L10n.tr("step_export"))
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .liquidGlassCapsule(tint: themeManager.currentTheme.stepAccent(.export), interactive: false)
                }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .animation(.spring(response: 0.30, dampingFraction: 0.85), value: themeManager.currentTheme)
    }
}

private struct ThemeSwatchQuad: View {
    let colors: [Color]
    let accent: Color
    let isSelected: Bool

    var body: some View {
        let safe = (0..<4).map { idx in idx < colors.count ? colors[idx] : accent }
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                cell(safe[0])
                cell(safe[1])
            }
            HStack(spacing: 3) {
                cell(safe[2])
                cell(safe[3])
            }
        }
        .padding(5)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? accent.opacity(0.75) : Color.primary.opacity(0.10), lineWidth: isSelected ? 1.8 : 1.0)
        )
    }

    private func cell(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color.opacity(0.24))
            .frame(width: 14, height: 14)
            .overlay(Circle().fill(color).frame(width: 7, height: 7))
    }
}
