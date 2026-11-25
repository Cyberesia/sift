import Foundation
import SiftCore

public enum AppMode: String, CaseIterable, Identifiable, Sendable {
    case sources
    case library
    case organize
    case rules
    case review

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .sources: tr("Discover", "Découvrir")
        case .organize: tr("Organize", "Organiser")
        case .library: tr("Library", "Bibliothèque")
        case .rules: tr("Rules", "Règles")
        case .review: tr("Review AI", "Revue IA")
        }
    }

    public var systemImage: String {
        switch self {
        case .sources: "sparkle.magnifyingglass"
        case .organize: "arrow.left.arrow.right.square"
        case .library: "photo.on.rectangle.angled"
        case .rules: "wand.and.rays"
        case .review: "sparkles"
        }
    }
}
