import SwiftUI

private struct MosaicAspectRatioKey: LayoutValueKey {
    static let defaultValue: CGFloat = 1
}

extension View {
    func mosaicAspectRatio(_ ratio: CGFloat) -> some View {
        layoutValue(key: MosaicAspectRatioKey.self, value: ratio)
    }
}

/// Column-based mosaic: each tile keeps its orientation; tiles never overlap.
struct PhotoMosaicLayout: Layout {
    let columns: Int
    let spacing: CGFloat

    struct Cache {
        var placements: [CGRect] = []
        var totalSize: CGSize = .zero
        var laidOutWidth: CGFloat = 0
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? 640
        let layout = computeLayout(width: width, subviews: subviews)
        cache.placements = layout.placements
        cache.totalSize = layout.size
        cache.laidOutWidth = width
        return layout.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        if cache.placements.count != subviews.count || abs(cache.laidOutWidth - bounds.width) > 0.5 {
            let layout = computeLayout(width: bounds.width, subviews: subviews)
            cache.placements = layout.placements
            cache.totalSize = layout.size
            cache.laidOutWidth = bounds.width
        }
        for (index, subview) in subviews.enumerated() where index < cache.placements.count {
            let rect = cache.placements[index]
            subview.place(
                at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: rect.width, height: rect.height)
            )
        }
    }

    private func computeLayout(width: CGFloat, subviews: Subviews) -> (placements: [CGRect], size: CGSize) {
        let columnCount = max(1, columns)
        let totalSpacing = spacing * CGFloat(columnCount - 1)
        let columnWidth = max(1, (width - totalSpacing) / CGFloat(columnCount))
        var columnHeights = Array(repeating: CGFloat(0), count: columnCount)
        var placements: [CGRect] = []

        for subview in subviews {
            let aspect = min(max(subview[MosaicAspectRatioKey.self], 0.45), 2.4)
            let itemHeight = columnWidth / aspect
            let column = columnHeights.enumerated().min(by: { $0.element < $1.element })!.offset
            let x = CGFloat(column) * (columnWidth + spacing)
            let y = columnHeights[column]
            placements.append(CGRect(x: x, y: y, width: columnWidth, height: itemHeight))
            columnHeights[column] += itemHeight + spacing
        }

        let maxColumnHeight = columnHeights.max() ?? 0
        let totalHeight = max(0, maxColumnHeight - (subviews.isEmpty ? 0 : spacing))
        return (placements, CGSize(width: width, height: totalHeight))
    }
}
