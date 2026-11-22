import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let rgb = parseHexRGB(hex)
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1.0)
    }

    var toHexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return rgbToHex(r: Double(r), g: Double(g), b: Double(b))
        }
        return "#111111"
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var titleKey: String {
        switch self {
        case .system: return "theme_mode_system"
        case .light: return "theme_mode_light"
        case .dark: return "theme_mode_dark"
        }
    }
}

/// Subtle Liquid Glass accent palettes preserving native Light/Dark system modes and green switches.
/// Includes `colorful` (Multicolor Original inspired by Voice Notes, zero orange).
enum PosterVisualTheme: String, CaseIterable, Identifiable, Sendable {
    case colorful
    case sapphire
    case iceCyan
    case indigo
    case emerald
    case violet
    case rose
    case graphite

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .colorful: return "ios_theme_colorful"
        case .sapphire: return "ios_theme_sapphire"
        case .iceCyan: return "ios_theme_cyan"
        case .indigo: return "ios_theme_indigo"
        case .emerald: return "ios_theme_emerald"
        case .violet: return "ios_theme_violet"
        case .rose: return "ios_theme_rose"
        case .graphite: return "ios_theme_graphite"
        }
    }

    var subtitleKey: String {
        switch self {
        case .colorful: return "ios_theme_colorful_sub"
        case .sapphire: return "ios_theme_sapphire_sub"
        case .iceCyan: return "ios_theme_cyan_sub"
        case .indigo: return "ios_theme_indigo_sub"
        case .emerald: return "ios_theme_emerald_sub"
        case .violet: return "ios_theme_violet_sub"
        case .rose: return "ios_theme_rose_sub"
        case .graphite: return "ios_theme_graphite_sub"
        }
    }

    var primaryHex: String {
        switch self {
        case .colorful: return "#2563EB"
        case .sapphire: return "#2563EB"
        case .iceCyan: return "#06B6D4"
        case .indigo: return "#4F46E5"
        case .emerald: return "#0EA571"
        case .violet: return "#7C3AED"
        case .rose: return "#E11D74"
        case .graphite: return "#64748B"
        }
    }

    var secondaryHex: String {
        switch self {
        case .colorful: return "#06B6D4"
        case .sapphire: return "#38BDF8"
        case .iceCyan: return "#67E8F9"
        case .indigo: return "#818CF8"
        case .emerald: return "#34D399"
        case .violet: return "#C084FC"
        case .rose: return "#F472B6"
        case .graphite: return "#94A3B8"
        }
    }

    var primaryAccent: Color { Color(hex: primaryHex) }
    var secondaryGlow: Color { Color(hex: secondaryHex) }

    /// Distinct jewel tones for the 4 studio steps when `colorful` is active (zero orange).
    func stepAccent(_ step: StudioStep) -> Color {
        guard self == .colorful else { return primaryAccent }
        switch step {
        case .image: return Color(hex: "#2563EB")   // Sapphire Blue
        case .paper: return Color(hex: "#06B6D4")   // Arctic Cyan
        case .style: return Color(hex: "#8B5CF6")   // Vivid Violet
        case .export: return Color(hex: "#10B981")  // Emerald Green
        }
    }

    var swatchColors: [Color] {
        if self == .colorful {
            return [
                Color(hex: "#2563EB"),
                Color(hex: "#06B6D4"),
                Color(hex: "#8B5CF6"),
                Color(hex: "#10B981")
            ]
        }
        return [primaryAccent, secondaryGlow, primaryAccent.opacity(0.62), secondaryGlow.opacity(0.50)]
    }
}

@MainActor
final class PosterThemeManager: ObservableObject {
    static let shared = PosterThemeManager()

    private static let themeKey = "com.mosaika.postercut.visualTheme"
    private static let appearanceKey = "com.mosaika.postercut.appearance"
    private static let defaultPaperKey = "com.mosaika.postercut.defaultPaper"
    private static let defaultUnitKey = "com.mosaika.postercut.defaultUnit"

    @Published var currentTheme: PosterVisualTheme {
        didSet { UserDefaults.standard.set(currentTheme.rawValue, forKey: Self.themeKey) }
    }

    @Published var appearance: AppAppearanceMode {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    @Published var defaultPaperID: String {
        didSet { UserDefaults.standard.set(defaultPaperID, forKey: Self.defaultPaperKey) }
    }

    @Published var defaultUnit: LengthUnit {
        didSet { UserDefaults.standard.set(defaultUnit.rawValue, forKey: Self.defaultUnitKey) }
    }

    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: Self.themeKey)
        self.currentTheme = savedTheme.flatMap(PosterVisualTheme.init(rawValue:)) ?? .colorful

        let savedApp = UserDefaults.standard.string(forKey: Self.appearanceKey)
        self.appearance = savedApp.flatMap(AppAppearanceMode.init(rawValue:)) ?? .system

        self.defaultPaperID = UserDefaults.standard.string(forKey: Self.defaultPaperKey) ?? "letter"

        let savedUnit = UserDefaults.standard.string(forKey: Self.defaultUnitKey)
        self.defaultUnit = savedUnit.flatMap(LengthUnit.init(rawValue:)) ?? .cm
    }

    var primaryAccent: Color { currentTheme.primaryAccent }
    var secondaryGlow: Color { currentTheme.secondaryGlow }

    func accent(for step: StudioStep) -> Color {
        currentTheme.stepAccent(step)
    }
}

// MARK: - Native iOS 26 Liquid Glass View Modifiers (with graceful iOS 17/18 fallback)

extension View {
    @ViewBuilder
    func liquidGlassCircle(tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .circle)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .circle)
                } else {
                    self.glassEffect(.regular, in: .circle)
                }
            }
        } else {
            self
                .background(
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        if let tint {
                            Circle().fill(tint.opacity(0.65))
                        }
                    }
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.45), Color.white.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                )
        }
    }

    @ViewBuilder
    func liquidGlassCapsule(tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .capsule)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    self.glassEffect(.regular, in: .capsule)
                }
            }
        } else {
            self
                .background(
                    ZStack {
                        Capsule().fill(.ultraThinMaterial)
                        if let tint {
                            Capsule().fill(tint.opacity(0.28))
                        }
                    }
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
                )
        }
    }

    @ViewBuilder
    func liquidGlassRoundedRect(cornerRadius: CGFloat = 22, tint: Color? = nil, interactive: Bool = true) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: shape)
                } else {
                    self.glassEffect(.regular.tint(tint), in: shape)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: shape)
                } else {
                    self.glassEffect(.regular, in: shape)
                }
            }
        } else {
            self
                .background(
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        if let tint {
                            shape.fill(tint.opacity(0.24))
                        }
                    }
                )
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
                )
        }
    }

    /// Lightweight native iOS card surface for scrolling sections & grid controls (zero live blur shaders -> cool GPU).
    func studioCardSurface(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(StudioCardSurfaceModifier(cornerRadius: cornerRadius))
    }
}

private struct StudioCardSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(
                shape.fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(colorScheme == .dark ? 0.90 : 0.95))
            )
            .overlay(
                shape.strokeBorder(
                    Color.primary.opacity(colorScheme == .dark ? 0.11 : 0.06),
                    lineWidth: 0.75
                )
            )
    }
}

/// GPU-friendly ambient Liquid Glass backdrop using RadialGradients (zero live Gaussian blur passes -> cool battery!).
struct AmbientLiquidBackdrop: View {
    var activeAccent: Color? = nil
    @ObservedObject private var themeManager = PosterThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primary = activeAccent ?? themeManager.primaryAccent
        let secondary = themeManager.secondaryGlow
        let topOpacity = colorScheme == .dark ? 0.16 : 0.10
        let botOpacity = colorScheme == .dark ? 0.12 : 0.08

        ZStack {
            Color(uiColor: .systemGroupedBackground)

            RadialGradient(
                colors: [primary.opacity(topOpacity), .clear],
                center: UnitPoint(x: 0.18, y: 0.12),
                startRadius: 10,
                endRadius: 340
            )

            RadialGradient(
                colors: [secondary.opacity(botOpacity), .clear],
                center: UnitPoint(x: 0.86, y: 0.82),
                startRadius: 10,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
