import SiftCore
import SwiftUI

public struct MediaListView: View {
    let assets: [MediaAssetSummary]
    let onOpen: (MediaAssetSummary) -> Void
    let hasMore: Bool
    let onLoadMore: () -> Void
    let onHoverAsset: (MediaAssetSummary?) -> Void
    @State private var hoveredID: String?

    public init(
        assets: [MediaAssetSummary],
        hasMore: Bool = false,
        onLoadMore: @escaping () -> Void = {},
        onHoverAsset: @escaping (MediaAssetSummary?) -> Void = { _ in },
        onOpen: @escaping (MediaAssetSummary) -> Void
    ) {
        self.assets = assets
        self.hasMore = hasMore
        self.onLoadMore = onLoadMore
        self.onHoverAsset = onHoverAsset
        self.onOpen = onOpen
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(assets) { asset in
                    Button {
                        onOpen(asset)
                    } label: {
                        MediaListRow(asset: asset, isHovered: hoveredID == asset.id)
                    }
                    .buttonStyle(.plain)
                    .prismClickable()
                    .onHover { hovering in
                        if hovering {
                            hoveredID = asset.id
                            onHoverAsset(asset)
                        } else if hoveredID == asset.id {
                            hoveredID = nil
                            onHoverAsset(nil)
                        }
                    }
                    Divider().opacity(0.2)
                }
                if hasMore {
                    ProgressView()
                        .controlSize(.small)
                        .padding(20)
                        .onAppear(perform: onLoadMore)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct MediaListRow: View {
    let asset: MediaAssetSummary
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 14) {
            ThumbnailStripTile(asset: asset, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.fileName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(asset.pipeline.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !asset.topCategories.isEmpty {
                    Text(asset.topCategories.prefix(3).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if GalleryDateLabel.showsAddedDate(for: asset.kind) {
                Text(GalleryDateLabel.added(asset.addedAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if asset.kind == .video {
                Image(systemName: "film")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(isHovered ? 0.1 : 0))
        )
        .animation(PrismMotion.quick, value: isHovered)
    }
}
