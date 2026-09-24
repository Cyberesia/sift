import Foundation
import ImageIO

#if os(macOS)
@preconcurrency import AppKit

private struct ThumbnailBox: @unchecked Sendable {
    let image: NSImage
}
#endif

/// Decodes small on-disk thumbnails off the main thread with an in-memory LRU cache.
public actor ThumbnailImageLoader {
    public static let shared = ThumbnailImageLoader()

    #if os(macOS)
    /// NSCache is thread-safe, so a hit can be read synchronously while the view is built.
    private nonisolated(unsafe) let cache = NSCache<NSString, NSImage>()
    private var inflight: [String: Task<ThumbnailBox?, Never>] = [:]
    #endif

    private init() {
        #if os(macOS)
        cache.countLimit = 160
        cache.totalCostLimit = 48 * 1024 * 1024
        #endif
    }

    #if os(macOS)
    public nonisolated func cachedImage(at path: String) -> NSImage? {
        cache.object(forKey: path as NSString)
    }

    public func image(at path: String, priority: TaskPriority = .utility) async -> NSImage? {
        let key = path as NSString
        if let hit = cache.object(forKey: key) {
            return hit
        }
        if let task = inflight[path] {
            return await task.value?.image
        }
        let task = Task.detached(priority: priority) { () -> ThumbnailBox? in
            guard !Task.isCancelled,
                  let source = CGImageSourceCreateWithURL(
                    URL(fileURLWithPath: path) as CFURL,
                    [kCGImageSourceShouldCache: false] as CFDictionary
                  ),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(
                    source,
                    0,
                    [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: 512,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceShouldCacheImmediately: true,
                    ] as CFDictionary
                  ),
                  !Task.isCancelled else {
                return nil
            }
            return ThumbnailBox(image: NSImage(cgImage: cgImage, size: .zero))
        }
        inflight[path] = task
        let loaded = await task.value?.image
        inflight[path] = nil
        if let loaded {
            let cost = Int(loaded.size.width * loaded.size.height * 4)
            cache.setObject(loaded, forKey: key, cost: cost)
        }
        return loaded
    }

    public func prefetch(paths: [String]) {
        for path in paths {
            guard cache.object(forKey: path as NSString) == nil, inflight[path] == nil else { continue }
            Task { _ = await image(at: path) }
        }
    }

    public func clear() {
        cache.removeAllObjects()
        inflight.removeAll()
    }
    #endif
}
