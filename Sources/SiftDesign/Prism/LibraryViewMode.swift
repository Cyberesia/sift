import Foundation

public enum LibraryViewMode: String, CaseIterable, Identifiable, Sendable {
    case grid
    case list
    case orbit

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .grid: "Grid"
        case .list: "List"
        case .orbit: "Garden"
        }
    }

    public var systemImage: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        case .orbit: "rotate.3d"
        }
    }
}
