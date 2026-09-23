import CoreGraphics
import Foundation
import ImageIO

public enum ThumbnailMetadata {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cachedRatios: [String: CGFloat] = [:]

    /// Cached ratio only. Launch must not open every thumbnail on the main thread.
    public static func cachedAspectRatio(thumbnailPath: String?) -> CGFloat {
        guard let path = thumbnailPath else { return 1 }
        lock.lock()
        defer { lock.unlock() }
        return cachedRatios[path] ?? 1
    }

    public static func warmAspectRatios(paths: [String]) {
        for path in paths {
            _ = aspectRatio(thumbnailPath: path)
        }
    }

    /// Width divided by height from the cached thumbnail file.
    public static func aspectRatio(thumbnailPath: String?) -> CGFloat {
        guard let path = thumbnailPath else { return 1 }
        lock.lock()
        if let cached = cachedRatios[path] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let ratio: CGFloat
        if let size = pixelSize(at: path), size.height > 0 {
            ratio = min(max(CGFloat(size.width) / CGFloat(size.height), 0.45), 2.4)
        } else {
            ratio = 1
        }
        lock.lock()
        cachedRatios[path] = ratio
        lock.unlock()
        return ratio
    }

    public static func pixelSize(at path: String) -> (width: Int, height: Int)? {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0 else {
            return nil
        }
        return (w, h)
    }
}
