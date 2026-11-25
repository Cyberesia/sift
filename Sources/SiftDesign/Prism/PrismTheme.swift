import SwiftUI

/// 60 / 30 / 10 color system for Prism UI.
/// - **60%** dominant field (background wash)
/// - **30%** secondary surfaces (panels, sidebars, glass)
/// - **10%** high-intensity accent (selection, CTAs, focus)
public enum PrismTheme {
    /// Set by `PrismAppearanceStore`. Read on the main thread while views draw.
    nonisolated(unsafe) static var activeSkin: PrismSkin = .citadel

    private static var hues: PrismSkin.Hues { activeSkin.hues }

    /// Dark backgrounds start from the original Citadel values and lean toward the skin's tint.
    private static func darkBase(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        let base = Color(red: red, green: green, blue: blue)
        return activeSkin == .citadel ? base : base.blended(with: Color(hex: hues.tint), amount: 0.32)
    }

    private static func lightBase(_ hex: UInt32, tint amount: Double) -> Color {
        Color(hex: hex).blended(with: Color(hex: hues.tint), amount: amount)
    }

    // MARK: 60% — dominant

    public static var dominant: Color { .adaptive(light: lightBase(0xF5F3F8, tint: 0.06), dark: darkBase(0.06, 0.055, 0.08)) }
    public static var dominantMid: Color { .adaptive(light: lightBase(0xEBE8F0, tint: 0.10), dark: darkBase(0.09, 0.08, 0.11)) }
    public static var dominantDeep: Color { .adaptive(light: lightBase(0xD9D5E0, tint: 0.12), dark: darkBase(0.04, 0.035, 0.05)) }

    // MARK: 30% — secondary surfaces

    public static var surface: Color { .adaptive(light: lightBase(0xFFFFFF, tint: 0.03), dark: darkBase(0.17, 0.15, 0.22)) }
    public static var surfaceElevated: Color { .adaptive(light: lightBase(0xFFFFFF, tint: 0.0), dark: darkBase(0.24, 0.21, 0.30)) }
    public static var surfaceMuted: Color { .adaptive(light: lightBase(0xF1EFF5, tint: 0.05), dark: darkBase(0.13, 0.12, 0.16)) }
    public static var borderSubtle: Color { .adaptive(light: Color.black.opacity(0.10), dark: Color.white.opacity(0.10)) }
    public static var borderStrong: Color { .adaptive(light: Color.black.opacity(0.18), dark: Color.white.opacity(0.18)) }

    // MARK: 10% — accent (high contrast)

    /// Primary pop color (use sparingly). Darker on light backgrounds so text on it stays readable.
    public static var accent: Color { .adaptive(light: Color(hex: hues.accentLight), dark: Color(hex: hues.accentDark)) }
    public static var accentSecondary: Color { .adaptive(light: Color(hex: hues.secondaryLight), dark: Color(hex: hues.secondaryDark)) }
    public static var accentGlow: Color { accent.opacity(0.42) }
    public static var accentSoft: Color { accent.opacity(0.16) }

    /// For faint fills and strokes on panels: white on dark, black on light. Use with a low opacity.
    public static var wash: Color { .adaptive(light: .black, dark: .white) }

    // MARK: Text

    public static var textPrimary: Color { .adaptive(light: Color.black.opacity(0.88), dark: Color.white.opacity(0.94)) }
    public static var textSecondary: Color { .adaptive(light: Color.black.opacity(0.62), dark: Color.white.opacity(0.62)) }
    public static var textTertiary: Color { .adaptive(light: Color.black.opacity(0.44), dark: Color.white.opacity(0.40)) }

    public static var dominantGradient: LinearGradient {
        LinearGradient(
            colors: [dominant, dominantMid],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentSecondary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public static var glassStrokeGradient: LinearGradient {
        LinearGradient(
            colors: [
                borderStrong,
                accent.opacity(0.55),
                surfaceElevated.opacity(0.6),
                borderSubtle,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public extension View {
    /// Applies the global accent tint for prominent controls.
    func prismAccentTint() -> some View {
        tint(PrismTheme.accent)
    }
}
