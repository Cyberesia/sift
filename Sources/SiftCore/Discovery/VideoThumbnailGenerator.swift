import AVFoundation
import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#endif

public enum VideoThumbnailGenerator {
    private static let videoExtensions: Set<String> = [
        "mov", "mp4", "m4v", "avi", "mkv", "webm", "mpg", "mpeg", "3gp",
    ]

    public static func isVideoFile(_ url: URL) -> Bool {
        videoExtensions.contains(url.pathExtension.lowercased())
    }

    public static func generatePosterSync(
        for fileURL: URL,
        maxPixelSize: Int = 480,
        atSeconds: Double = 0.5
    ) -> CGImage? {
        let asset = AVURLAsset(url: fileURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: CGFloat(maxPixelSize), height: CGFloat(maxPixelSize))
        let time = CMTime(seconds: atSeconds, preferredTimescale: 600)
        return try? generator.copyCGImage(at: time, actualTime: nil)
    }

    public static func generatePoster(
        for fileURL: URL,
        maxPixelSize: Int = 480,
        atSeconds: Double = 0.5
    ) async -> CGImage? {
        await Task.detached(priority: .utility) {
            generatePosterSync(for: fileURL, maxPixelSize: maxPixelSize, atSeconds: atSeconds)
        }.value
    }

    #if canImport(AppKit)
    public static func posterImage(for fileURL: URL, maxPixelSize: Int = 480) async -> NSImage? {
        guard let cg = await generatePoster(for: fileURL, maxPixelSize: maxPixelSize) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
    #endif
}
