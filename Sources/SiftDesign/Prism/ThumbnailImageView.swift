import SiftCore
import SwiftUI

#if os(macOS)
@preconcurrency import AppKit
#endif

/// Displays an indexed thumbnail from disk (fast). Optional lazy fallback for single-item views only.
public struct ThumbnailImageView: View {
    let path: String?
    let fallbackURL: URL?
    let contentMode: ContentMode
    let allowOriginalFallback: Bool

    @State private var diskImage: PlatformThumbImage?
    @State private var fallbackImage: PlatformThumbImage?

    public init(
        path: String?,
        fallbackURL: URL? = nil,
        contentMode: ContentMode = .fit,
        allowOriginalFallback: Bool = false
    ) {
        self.path = path
        self.fallbackURL = fallbackURL
        self.contentMode = contentMode
        self.allowOriginalFallback = allowOriginalFallback
    }

    public var body: some View {
        Group {
            if let diskImage {
                platformImage(diskImage)
            } else if let fallbackImage {
                platformImage(fallbackImage)
            } else {
                placeholder
            }
        }
        .task(id: loadTaskID) {
            await loadThumbnail()
        }
    }

    private var loadTaskID: String {
        "\(path ?? "")|\(fallbackURL?.path ?? "")|\(allowOriginalFallback)"
    }

    @ViewBuilder
    private func platformImage(_ image: PlatformThumbImage) -> some View {
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: contentMode == .fit ? .fit : .fill)
        #else
        EmptyView()
        #endif
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary.opacity(0.35))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }

    private func loadThumbnail() async {
        diskImage = nil
        fallbackImage = nil

        #if os(macOS)
        guard !Task.isCancelled else { return }
        if let path, FileManager.default.fileExists(atPath: path) {
            let loaded = await ThumbnailImageLoader.shared.image(at: path)
            guard !Task.isCancelled else { return }
            diskImage = loaded
            if diskImage != nil { return }
        }

        guard !Task.isCancelled else { return }
        guard allowOriginalFallback,
              let fallbackURL,
              FileManager.default.fileExists(atPath: fallbackURL.path) else {
            return
        }

        let url = fallbackURL
        let loadedFallback: NSImage? = await Task.detached(priority: .utility) { () -> NSImage? in
            if VideoThumbnailGenerator.isVideoFile(url) {
                guard let cg = await VideoThumbnailGenerator.generatePoster(for: url, maxPixelSize: 320) else {
                    return nil
                }
                return NSImage(cgImage: cg, size: .zero)
            }
            guard let cg = SafeImageLoader.loadForCarouselDisplay(from: url, maxPixelSize: 320) else {
                return nil
            }
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }.value
        guard !Task.isCancelled else { return }
        fallbackImage = loadedFallback
        #endif
    }
}

#if os(macOS)
typealias PlatformThumbImage = NSImage
#else
typealias PlatformThumbImage = Never
#endif

public struct ThumbnailStripTile: View {
    let asset: MediaAssetSummary
    let size: CGFloat
    let allowOriginalFallback: Bool

    public init(asset: MediaAssetSummary, size: CGFloat, allowOriginalFallback: Bool = false) {
        self.asset = asset
        self.size = size
        self.allowOriginalFallback = allowOriginalFallback
    }

    public var body: some View {
        Group {
            if asset.kind == .audio || asset.kind == .document {
                MediaMark(asset: asset, showsName: false)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.black.opacity(0.2))
                    ThumbnailImageView(
                        path: asset.thumbnailPath,
                        fallbackURL: allowOriginalFallback ? asset.fileURL : nil,
                        contentMode: .fit,
                        allowOriginalFallback: allowOriginalFallback
                    )
                    .padding(2)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
