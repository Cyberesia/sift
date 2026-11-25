import Foundation

/// The interface language. "System" follows the Mac: French when French is the first preferred language.
///
/// Sift's copy is written as `tr("English", "Français")` next to the view that shows it, so a screen and
/// its translation are reviewed together. Adding a language means adding a case and an argument.
public enum SiftLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case french

    public var id: String { rawValue }

    public static let defaultsKey = "sift.uiLanguage"

    /// Each language names itself, so the picker stays readable whatever is selected.
    public var title: String {
        switch self {
        case .system: tr("Same as the Mac", "Comme le Mac")
        case .english: "English"
        case .french: "Français"
        }
    }

    public static var current: SiftLanguage {
        get { SiftLanguage(rawValue: SiftRuntime.defaults.string(forKey: defaultsKey) ?? "") ?? .system }
        set { SiftRuntime.defaults.set(newValue.rawValue, forKey: defaultsKey) }
    }

    public static var isFrench: Bool {
        switch current {
        case .french: return true
        case .english: return false
        case .system: return (Locale.preferredLanguages.first ?? "").lowercased().hasPrefix("fr")
        }
    }
}

/// English or French copy, picked by the language in Settings.
public func tr(_ english: String, _ french: String) -> String {
    SiftLanguage.isFrench ? french : english
}
