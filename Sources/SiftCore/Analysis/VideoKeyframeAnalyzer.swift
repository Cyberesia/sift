import AVFoundation
import CoreGraphics
import Foundation

public struct VideoKeyframeAnalyzer: Sendable {
    public init() {}

    public func analyzeVideo(at url: URL) async throws -> PhotoAnalysisResult {
        let analyzer = PhotoAnalyzer()
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1024, height: 1024)

        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        let sampleTimes: [CMTime] = [
            CMTime(seconds: max(0, seconds * 0.1), preferredTimescale: 600),
            CMTime(seconds: seconds * 0.5, preferredTimescale: 600),
            CMTime(seconds: max(0, seconds * 0.9), preferredTimescale: 600),
        ].filter { CMTimeGetSeconds($0).isFinite }

        var merged = PhotoAnalysisResult()
        merged.isScreenshotOrDocument = false

        for time in sampleTimes {
            let cgImage: CGImage
            do {
                let result = try await generator.image(at: time)
                cgImage = result.image
            } catch {
                continue
            }
            let metadata = AssetMetadata(
                pixelWidth: cgImage.width,
                pixelHeight: cgImage.height
            )
            let frameResult = try await analyzer.analyzeImage(cgImage, metadata: metadata)
            merged.textLineCount = max(merged.textLineCount, frameResult.textLineCount)
            merged.faceCount = max(merged.faceCount, frameResult.faceCount)
            merged.topCategories = Array(Set(merged.topCategories + frameResult.topCategories)).prefix(5).map { $0 }
            merged.detectedAnimals = Array(Set(merged.detectedAnimals + frameResult.detectedAnimals))
            if frameResult.isScreenshotOrDocument {
                merged.isScreenshotOrDocument = true
            }
            merged.featurePrintData = frameResult.featurePrintData ?? merged.featurePrintData
        }

        return merged
    }
}
