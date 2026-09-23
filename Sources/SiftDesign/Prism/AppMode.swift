import Foundation

public enum AppMode: String, CaseIterable, Identifiable, Sendable {
    case sources
    case library
    case organize
    case review

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .sources: "Discover"
        case .organize: "Organize"
        case .library: "Library"
        case .review: "Review AI"
        }
    }

    public var systemImage: String {
        switch self {
        case .sources: "sparkle.magnifyingglass"
        case .organize: "arrow.left.arrow.right.square"
        case .library: "photo.on.rectangle.angled"
        case .review: "sparkles"
        }
    }
}
