import SiftCore
import SwiftUI

public struct AssetDetailView: View {
    let asset: MediaAssetSummary
    let related: [MediaAssetSummary]
    let onOpenRelated: (MediaAssetSummary) -> Void
    let onPersonLabelCommit: (String) -> Void

    public init(
        asset: MediaAssetSummary,
        related: [MediaAssetSummary],
        onOpenRelated: @escaping (MediaAssetSummary) -> Void = { _ in },
        onPersonLabelCommit: @escaping (String) -> Void = { _ in }
    ) {
        self.asset = asset
        self.related = related
        self.onOpenRelated = onOpenRelated
        self.onPersonLabelCommit = onPersonLabelCommit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GalleryInlinePreview(asset: asset)
            Text(asset.fileName)
                .font(.headline)
                .textSelection(.enabled)
            Text(asset.sourceLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(GalleryDateLabel.added(asset.addedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
            metadataGrid
            if asset.faceCount > 0 || asset.pipeline == .people {
                PrismPersonTagRow(
                    faceCount: max(asset.faceCount, 1),
                    initialName: asset.personDisplayName ?? "",
                    onCommit: onPersonLabelCommit
                )
            }
            if !related.isEmpty {
                Text("Similar photos")
                    .font(.subheadline.weight(.semibold))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(related.prefix(8)) { item in
                            Button {
                                onOpenRelated(item)
                            } label: {
                                ThumbnailStripTile(asset: item, size: 72)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(20)
        .prismGlass(cornerRadius: 24, padding: 0)
    }

    private var metadataGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("Pipeline").foregroundStyle(.secondary)
                Text(asset.pipeline.displayName)
            }
            GridRow {
                Text("Categories").foregroundStyle(.secondary)
                Text(asset.topCategories.joined(separator: ", ").ifEmpty("—"))
            }
            GridRow {
                Text("Faces").foregroundStyle(.secondary)
                Text("\(asset.faceCount)")
            }
        }
        .font(.caption)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
