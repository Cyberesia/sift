import SiftCore
import SwiftUI

public struct PhotoMosaicTile: View {
    let asset: MediaAssetSummary
    let isHovered: Bool

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.black.opacity(0.25))
            if asset.kind == .image || asset.kind == .video {
                ThumbnailImageView(path: asset.thumbnailPath, contentMode: .fit)
                    .padding(2)
                if asset.kind == .video {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(Circle().fill(.black.opacity(0.45)))
                }
                VStack {
                    Spacer()
                    Text(GalleryDateLabel.added(asset.addedAt))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.45))
                }
            } else {
                MediaMark(asset: asset, showsName: true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(isHovered ? 0.35 : 0.12), lineWidth: isHovered ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

public struct PhotoMosaicGrid: View {
    let assets: [MediaAssetSummary]
    let columns: Int
    let selectedIDs: Set<String>
    let onOpen: (MediaAssetSummary) -> Void
    let onHoverAsset: (MediaAssetSummary?) -> Void
    let onToggleSelection: (MediaAssetSummary, Bool) -> Void
    let hasMore: Bool
    let isLoadingMore: Bool
    let onLoadMore: () -> Void

    @State private var hoveredID: String?

    public init(
        assets: [MediaAssetSummary],
        columns: Int = 4,
        selectedIDs: Set<String> = [],
        onOpen: @escaping (MediaAssetSummary) -> Void,
        onHoverAsset: @escaping (MediaAssetSummary?) -> Void = { _ in },
        onToggleSelection: @escaping (MediaAssetSummary, Bool) -> Void = { _, _ in },
        hasMore: Bool = false,
        isLoadingMore: Bool = false,
        onLoadMore: @escaping () -> Void = {}
    ) {
        self.assets = assets
        self.columns = columns
        self.selectedIDs = selectedIDs
        self.onOpen = onOpen
        self.onHoverAsset = onHoverAsset
        self.onToggleSelection = onToggleSelection
        self.hasMore = hasMore
        self.isLoadingMore = isLoadingMore
        self.onLoadMore = onLoadMore
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(minimum: 120), spacing: 10),
                    count: max(1, columns)
                ),
                spacing: 10
            ) {
                ForEach(Array(assets.enumerated()), id: \.element.id) { index, asset in
                    let isSelected = selectedIDs.contains(asset.id)
                    Button {
                        #if os(macOS)
                        let extend = NSEvent.modifierFlags.contains(.shift)
                        let command = NSEvent.modifierFlags.contains(.command)
                        if command || extend {
                            onToggleSelection(asset, extend)
                        } else {
                            onOpen(asset)
                        }
                        #else
                        onOpen(asset)
                        #endif
                    } label: {
                        PhotoMosaicTile(
                            asset: asset,
                            isHovered: hoveredID == asset.id
                        )
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(PrismTheme.accent, lineWidth: 3)
                            }
                        }
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
                    .onAppear {
                        prefetch(after: index)
                        if hasMore, index >= assets.count - 16 {
                            onLoadMore()
                        }
                    }
                }

                if hasMore {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .onAppear(perform: onLoadMore)
                        .opacity(isLoadingMore ? 1 : 0.55)
                }
            }
            .padding(14)
        }
    }

    private func prefetch(after index: Int) {
        let lower = min(index + 1, assets.count)
        let upper = min(lower + 24, assets.count)
        guard lower < upper else { return }
        let paths = assets[lower..<upper].compactMap(\.thumbnailPath)
        Task { await ThumbnailImageLoader.shared.prefetch(paths: paths) }
    }
}

#if os(macOS)
import AppKit
#endif

/// Backward-compatible name used by the shell.
public typealias MasonryGrid = PhotoMosaicGrid

extension Notification.Name {
    public static let siftAssetSelected = Notification.Name("sift.assetSelected")
}
