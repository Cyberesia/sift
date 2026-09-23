import SwiftUI

/// Bezel-welded rail with inverse flares. Its fill is supplied by the caller so
/// Prism can use liquid glass without turning it into a floating capsule.
public struct SideNotchShape: Shape {
    public var curlRadius: CGFloat = 26
    public var cornerRadius: CGFloat = 20

    public init(curlRadius: CGFloat = 26, cornerRadius: CGFloat = 20) {
        self.curlRadius = curlRadius
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        let wanted = max(0, min(cornerRadius, rect.width / 2))
        let curl = max(0, min(curlRadius, rect.height / 2, rect.width - wanted))
        let corner = max(0, min(wanted, (rect.height - 2 * curl) / 2))
        let bodyTop = rect.minY + curl
        let bodyBottom = rect.maxY - curl

        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        if curl > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - curl, y: rect.minY),
                radius: curl,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        }
        path.addLine(to: CGPoint(x: rect.minX + corner, y: bodyTop))
        path.addArc(
            center: CGPoint(x: rect.minX + corner, y: bodyTop + corner),
            radius: corner,
            startAngle: .degrees(270),
            endAngle: .degrees(180),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.minX, y: bodyBottom - corner))
        path.addArc(
            center: CGPoint(x: rect.minX + corner, y: bodyBottom - corner),
            radius: corner,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.maxX - curl, y: bodyBottom))
        if curl > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - curl, y: rect.maxY),
                radius: curl,
                startAngle: .degrees(270),
                endAngle: .degrees(360),
                clockwise: false
            )
        }
        path.closeSubpath()
        return path
    }
}

public enum NotchRailMetrics {
    public static let depth: CGFloat = 64
    public static let length: CGFloat = 624
    public static let cardWidth: CGFloat = 286
    public static let cardGap: CGFloat = 10
    public static let topPadding: CGFloat = 46
    public static let bottomPadding: CGFloat = 22
    public static let cellHeight: CGFloat = 56
    public static let cellSpacing: CGFloat = 2
    /// Matches the rail cell: 30 pt circle, 2 pt gap, 9 pt caption.
    public static let iconDiameter: CGFloat = 30
    public static let iconToCaptionSpacing: CGFloat = 2
    public static let iconCaptionLineHeight: CGFloat = 11

    public static var panelSize: CGSize {
        CGSize(width: depth + cardWidth + cardGap, height: length)
    }

    /// Grip row under the icons. Matches the rail’s last `HStack` height.
    public static let gripRowHeight: CGFloat = 18

    /// Vertical slack when the icon stack is shorter than the rail frame.
    public static var railContentInset: CGFloat {
        let rows = CGFloat(NotchRailItem.allCases.count)
        let content = topPadding
            + rows * cellHeight
            + rows * cellSpacing
            + gripRowHeight
            + bottomPadding
        return max(0, (length - content) / 2)
    }

    /// Center of the icon circle, not the cell. The caption sits under the symbol,
    /// so aligning to the cell center puts every arrow a little below its icon.
    /// The result is in points inside the rail, so it stays put on any display size.
    public static func iconCenter(index: Int) -> CGFloat {
        let cellTop = railContentInset
            + topPadding
            + CGFloat(index) * (cellHeight + cellSpacing)
        let stackHeight = iconDiameter + iconToCaptionSpacing + iconCaptionLineHeight
        let iconTop = cellTop + (cellHeight - stackHeight) / 2
        return iconTop + iconDiameter / 2
    }

    /// Card center offset from the rail center, kept inside the panel.
    public static func cardOffset(index: Int, cardHeight: CGFloat) -> CGFloat {
        let ideal = iconCenter(index: index) - length / 2
        guard cardHeight > 1 else { return ideal }
        let limit = max(0, (length - cardHeight) / 2 - 8)
        return min(limit, max(-limit, ideal))
    }
}

public enum NotchRailItem: String, CaseIterable, Identifiable {
    case index
    case library
    case garden
    case sources
    case inbox
    case organize
    case review
    case duplicates
    case search

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .index: "circle.dotted"
        case .library: "photo.on.rectangle.angled"
        case .garden: "rotate.3d"
        case .sources: "sparkle.magnifyingglass"
        case .inbox: "tray"
        case .organize: "arrow.left.arrow.right"
        case .review: "sparkles"
        case .duplicates: "square.on.square"
        case .search: "magnifyingglass"
        }
    }

    public var title: String {
        switch self {
        case .index: "Index"
        case .library: "Library"
        case .garden: "Garden"
        case .sources: "Discover"
        case .inbox: "Inbox"
        case .organize: "Organize"
        case .review: "Review"
        case .duplicates: "Dupes"
        case .search: "Search"
        }
    }
}
