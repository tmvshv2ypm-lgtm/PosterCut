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
enum PosterVisualTheme: String, CaseIterable, Identifiable, Sendable {
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
        case .sapphire: return "ios_theme_sapphire"
        case .iceCyan: return "ios_theme_cyan"
        case .indigo: return "ios_theme_indigo"
        case .emerald: return "ios_theme_emerald"
        case .violet: return "ios_theme_violet"
        case .rose: return "ios_theme_rose"
        case .graphite: return "ios_theme_graphite"
        }
    }

    var primaryHex: String {
        switch self {
        case .sapphire: return "#2563EB"
        case .iceCyan: return "#06B6D4"
        case .indigo: return "#4F46E5"
        case .emerald: return "#0EA571"
        case .violet: return "#7C3AED"
        case .rose: return "#E11D74"
        case .graphite: return "#475569"
        }
    }

    var secondaryHex: String {
        switch self {
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

    var swatchColors: [Color] {
        [primaryAccent, secondaryGlow, primaryAccent.opacity(0.55), secondaryGlow.opacity(0.45)]
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
        self.currentTheme = savedTheme.flatMap(PosterVisualTheme.init(rawValue:)) ?? .sapphire

        let savedApp = UserDefaults.standard.string(forKey: Self.appearanceKey)
        self.appearance = savedApp.flatMap(AppAppearanceMode.init(rawValue:)) ?? .system

        self.defaultPaperID = UserDefaults.standard.string(forKey: Self.defaultPaperKey) ?? "letter"

        let savedUnit = UserDefaults.standard.string(forKey: Self.defaultUnitKey)
        self.defaultUnit = savedUnit.flatMap(LengthUnit.init(rawValue:)) ?? .cm
    }

    var primaryAccent: Color { currentTheme.primaryAccent }
    var secondaryGlow: Color { currentTheme.secondaryGlow }
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
}

/// Calm ambient Liquid Glass background glow inspired by Voice Notes.
struct AmbientLiquidBackdrop: View {
    @ObservedObject private var themeManager = PosterThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            Circle()
                .fill(themeManager.primaryAccent.opacity(colorScheme == .dark ? 0.16 : 0.11))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: -120, y: -220)

            Circle()
                .fill(themeManager.secondaryGlow.opacity(colorScheme == .dark ? 0.14 : 0.09))
                .frame(width: 300, height: 300)
                .blur(radius: 85)
                .offset(x: 130, y: 200)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
