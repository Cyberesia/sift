import CoreGraphics
import Foundation
import ImageIO

#if os(macOS)
@preconcurrency import AppKit

private struct LoadedPreview: @unchecked Sendable {
    let image: NSImage?
    let pixelSize: CGSize?
}
#endif

/// In-memory preview cache + fast metadata reads for carousel browsing.
public actor PreviewImageCache {
    public static let shared = PreviewImageCache()

    private struct Entry {
        let image: PlatformPreviewImage
        let pixelSize: CGSize
    }

    private var storage: [String: Entry] = [:]
    private var order: [String] = []
    private let maxEntries = 16

    private init() {}

    public func image(
        for asset: MediaAssetSummary,
        maxPixelSize: Int = 1920
    ) async -> (image: PlatformPreviewImage?, pixelSize: CGSize?) {
        let key = cacheKey(assetID: asset.id, maxPixelSize: maxPixelSize)
        if let hit = storage[key] {
            touch(key)
            return (hit.image, hit.pixelSize)
        }

        let url = asset.fileURL
        #if os(macOS)
        let loadedBox = await Task.detached(priority: .userInitiated) { () -> LoadedPreview in
            let size = SafeImageLoader.pixelSize(at: url)
            if asset.kind == .video {
                if let cg = await VideoThumbnailGenerator.generatePoster(for: url, maxPixelSize: maxPixelSize) {
                    let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                    return LoadedPreview(image: img, pixelSize: size ?? CGSize(width: cg.width, height: cg.height))
                }
            } else if let cg = SafeImageLoader.loadForCarouselDisplay(from: url, maxPixelSize: maxPixelSize) {
                let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                return LoadedPreview(image: img, pixelSize: size ?? CGSize(width: cg.width, height: cg.height))
            }
            if let path = asset.thumbnailPath,
               FileManager.default.fileExists(atPath: path),
               let thumb = NSImage(contentsOfFile: path) {
                return LoadedPreview(image: thumb, pixelSize: size)
            }
            return LoadedPreview(image: nil, pixelSize: size)
        }.value
        let loaded: (PlatformPreviewImage?, CGSize?) = (loadedBox.image, loadedBox.pixelSize)
        #else
        let loaded: (PlatformPreviewImage?, CGSize?) = (nil, nil)
        #endif

        if let image = loaded.0 {
            store(key: key, entry: Entry(image: image, pixelSize: loaded.1 ?? image.size))
        }
        return loaded
    }

    public func instantThumbnail(for asset: MediaAssetSummary) async -> PlatformPreviewImage? {
        #if os(macOS)
        if let path = asset.thumbnailPath, FileManager.default.fileExists(atPath: path) {
            return await ThumbnailImageLoader.shared.image(at: path)
        }
        return nil
        #else
        return nil
        #endif
    }

    public func prefetch(_ assets: [MediaAssetSummary], maxPixelSize: Int = 1920) {
        for asset in assets {
            let key = cacheKey(assetID: asset.id, maxPixelSize: maxPixelSize)
            guard storage[key] == nil else { continue }
            Task { [asset] in
                _ = await self.image(for: asset, maxPixelSize: maxPixelSize)
            }
        }
    }

    public func clear() {
        storage.removeAll()
        order.removeAll()
    }

    private func cacheKey(assetID: String, maxPixelSize: Int) -> String {
        "\(assetID)-\(maxPixelSize)"
    }

    private func store(key: String, entry: Entry) {
        storage[key] = entry
        touch(key)
        while order.count > maxEntries, let evict = order.first {
            order.removeFirst()
            storage.removeValue(forKey: evict)
        }
    }

    private func touch(_ key: String) {
        order.removeAll { $0 == key }
        order.append(key)
    }
}

#if os(macOS)
public typealias PlatformPreviewImage = NSImage
#else
public typealias PlatformPreviewImage = Never
#endif
