import CoreGraphics
import Foundation
import ImageIO

/// Loads images for Vision/analysis without retaining RawCamera-backed `CGImage` buffers (crash on dealloc).
public enum SafeImageLoader {
    public static let analysisMaxPixelSize = 2048
    public static let previewMaxPixelSize = 2400

    private static let rawExtensions: Set<String> = [
        "raw", "dng", "cr2", "cr3", "nef", "nrw", "arw", "orf", "rw2", "pef", "srw", "raf", "3fr", "fff",
    ]

    public static func isLikelyRAW(url: URL) -> Bool {
        rawExtensions.contains(url.pathExtension.lowercased())
    }

    /// Decodes via ImageIO thumbnail pipeline, then copies into an independent bitmap.
    public static func loadForAnalysis(from url: URL, maxPixelSize: Int = analysisMaxPixelSize) -> CGImage? {
        guard FileManager.default.fileExists(atPath: url.path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary),
           let copy = copyToIndependentBitmap(thumbnail) {
            return copy
        }

        // Never use full RAW decode — it hooks RawCamera and can crash on release.
        if isLikelyRAW(url: url) {
            return nil
        }

        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return copyToIndependentBitmap(image)
    }

    public static func loadForPreview(from url: URL, maxPixelSize: Int = previewMaxPixelSize) -> CGImage? {
        loadForAnalysis(from: url, maxPixelSize: maxPixelSize)
    }

    /// Carousel display path: thumbnail decode only, skip extra bitmap copy for non-RAW (faster browsing).
    public static func loadForCarouselDisplay(from url: URL, maxPixelSize: Int = previewMaxPixelSize) -> CGImage? {
        guard FileManager.default.fileExists(atPath: url.path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) {
            if isLikelyRAW(url: url) {
                return copyToIndependentBitmap(thumbnail) ?? thumbnail
            }
            return thumbnail
        }
        if isLikelyRAW(url: url) { return nil }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return copyToIndependentBitmap(image) ?? image
    }

    /// Reads width/height from ImageIO without decoding pixels.
    public static func pixelSize(at url: URL) -> CGSize? {
        guard FileManager.default.fileExists(atPath: url.path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    /// Deep-copies pixels so CoreImage/Vision do not hold references to provider-backed images.
    public static func copyToIndependentBitmap(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
