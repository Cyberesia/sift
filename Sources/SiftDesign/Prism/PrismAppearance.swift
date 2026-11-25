import SiftCore
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// A colour family for the whole interface. Each skin has a dark and a light version.
public enum PrismSkin: String, CaseIterable, Identifiable, Sendable {
    case citadel
    case ocean
    case forest
    case dune
    case orchid
    case graphite

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .citadel: "Citadel"
        case .ocean: "Ocean"
        case .forest: "Forest"
        case .dune: "Dune"
        case .orchid: "Orchid"
        case .graphite: "Graphite"
        }
    }

    struct Hues {
        /// Accent for buttons, selection and focus, on dark and on light backgrounds.
        var accentDark: UInt32
        var accentLight: UInt32
        var secondaryDark: UInt32
        var secondaryLight: UInt32
        /// The tint mixed into backgrounds and panels.
        var tint: UInt32
    }

    var hues: Hues {
        switch self {
        case .citadel: Hues(accentDark: 0xFF7042, accentLight: 0xD9481C, secondaryDark: 0xFFB859, secondaryLight: 0xB86A00, tint: 0x3A2A55)
        case .ocean: Hues(accentDark: 0x45A8FF, accentLight: 0x0A6AD1, secondaryDark: 0x5EE3E0, secondaryLight: 0x00807C, tint: 0x173A5A)
        case .forest: Hues(accentDark: 0x3BDB8A, accentLight: 0x0E8A4E, secondaryDark: 0xC4E86A, secondaryLight: 0x5E7A00, tint: 0x1D3D2E)
        case .dune: Hues(accentDark: 0xE0A970, accentLight: 0x9A5A22, secondaryDark: 0xF2D18B, secondaryLight: 0x7A6200, tint: 0x4A3826)
        case .orchid: Hues(accentDark: 0xD77BFF, accentLight: 0x8B2FC9, secondaryDark: 0xFF8CC6, secondaryLight: 0xB0306E, tint: 0x3E2450)
        case .graphite: Hues(accentDark: 0x9FB4CC, accentLight: 0x3D5878, secondaryDark: 0xD9DEE5, secondaryLight: 0x5A6470, tint: 0x2A2D33)
        }
    }

    /// Swatch for pickers.
    public var swatch: [Color] {
        [Color(hex: hues.accentDark), Color(hex: hues.secondaryDark), Color(hex: hues.tint)]
    }
}

public enum PrismAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// How large the whole interface is drawn. macOS ignores Dynamic Type, so Sift zooms the window content.
public enum PrismInterfaceSize: Double, CaseIterable, Identifiable, Sendable {
    case compact = 0.9
    case standard = 1.0
    case large = 1.15
    case larger = 1.3

    public var id: Double { rawValue }
}

/// Appearance choices, saved in the defaults and applied at the window's root.
@MainActor
public final class PrismAppearanceStore: ObservableObject {
    public static let shared = PrismAppearanceStore()

    private enum Key {
        static let skin = "sift.appearance.skin"
        static let mode = "sift.appearance.mode"
        static let size = "sift.appearance.size"
    }

    @Published public var skin: PrismSkin {
        didSet {
            SiftRuntime.defaults.set(skin.rawValue, forKey: Key.skin)
            PrismTheme.activeSkin = skin
            revision += 1
        }
    }

    @Published public var mode: PrismAppearanceMode {
        didSet { SiftRuntime.defaults.set(mode.rawValue, forKey: Key.mode) }
    }

    @Published public var size: PrismInterfaceSize {
        didSet { SiftRuntime.defaults.set(size.rawValue, forKey: Key.size) }
    }

    /// Interface language. Changing it redraws the window in the new language.
    @Published public var language: SiftLanguage {
        didSet {
            SiftLanguage.current = language
            revision += 1
        }
    }

    /// Bumped when colours or language change, so the window rebuilds with the new tokens.
    @Published public private(set) var revision = 0

    private init() {
        let defaults = SiftRuntime.defaults
        skin = PrismSkin(rawValue: defaults.string(forKey: Key.skin) ?? "") ?? .citadel
        mode = PrismAppearanceMode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .dark
        size = PrismInterfaceSize(rawValue: defaults.double(forKey: Key.size)) ?? .standard
        language = SiftLanguage.current
        PrismTheme.activeSkin = skin
    }
}

public extension View {
    /// Applies the saved skin, light or dark mode, and interface size to a window's content.
    func prismAppearance(_ store: PrismAppearanceStore = .shared) -> some View {
        modifier(PrismAppearanceModifier(store: store))
    }
}

private struct PrismAppearanceModifier: ViewModifier {
    @ObservedObject var store: PrismAppearanceStore

    func body(content: Content) -> some View {
        PrismZoom(scale: store.size.rawValue) {
            content
        }
        .id(store.revision)
        .tint(PrismTheme.accent)
        .preferredColorScheme(store.mode.colorScheme)
    }
}

/// Lays the content out at 1/scale of the window, then draws it scaled up, so everything grows together.
struct PrismZoom<Content: View>: View {
    let scale: Double
    @ViewBuilder let content: () -> Content

    var body: some View {
        if abs(scale - 1) < 0.01 {
            content()
        } else {
            GeometryReader { geometry in
                content()
                    .frame(width: geometry.size.width / scale, height: geometry.size.height / scale)
                    .scaleEffect(scale, anchor: .topLeading)
            }
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// One colour for light mode and another for dark mode, resolved by the view's appearance.
    static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(AppKit)
        let lightColor = NSColor(light)
        let darkColor = NSColor(dark)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkColor : lightColor
        })
        #else
        return dark
        #endif
    }

    /// Mixes two colours in sRGB; `amount` 0 keeps self, 1 gives `other`.
    func blended(with other: Color, amount: Double) -> Color {
        #if canImport(AppKit)
        let a = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let b = NSColor(other).usingColorSpace(.sRGB) ?? .black
        let t = min(max(amount, 0), 1)
        return Color(
            .sRGB,
            red: Double(a.redComponent + (b.redComponent - a.redComponent) * t),
            green: Double(a.greenComponent + (b.greenComponent - a.greenComponent) * t),
            blue: Double(a.blueComponent + (b.blueComponent - a.blueComponent) * t),
            opacity: Double(a.alphaComponent + (b.alphaComponent - a.alphaComponent) * t)
        )
        #else
        return self
        #endif
    }
}
