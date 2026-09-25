import Foundation

public enum PipelineClassifier: Sendable {
    public static func classify(
        kind: MediaKind,
        analysis: PhotoAnalysisResult,
        metadata: AssetMetadata
    ) -> MediaPipeline {
        if kind == .document { return .documents }
        if kind == .video { return .videos }
        if analysis.isScreenshotOrDocument { return .artifacts }
        if analysis.faceCount >= 1 && !analysis.isScreenshotOrDocument { return .people }
        if let place = analysis.topCategories.first(where: isPlaceCategory) {
            _ = place
            return .places
        }
        return .photography
    }

    public static func isArtifact(
        analysis: PhotoAnalysisResult,
        metadata: AssetMetadata
    ) -> Bool {
        artifactReason(analysis: analysis, metadata: metadata) != nil
    }

    /// Why a picture counts as a screenshot or document: `screen-size`, `text`, or `ratio+text`. Nil otherwise.
    public static func artifactReason(
        analysis: PhotoAnalysisResult,
        metadata: AssetMetadata
    ) -> String? {
        if metadata.isScreenshotCandidate { return "screen-size" }
        if analysis.textLineCount > 5 || analysis.isScreenshotOrDocument { return "text" }
        let ratio = Double(metadata.pixelWidth) / Double(max(metadata.pixelHeight, 1))
        let commonScreenshotRatios = [9.0 / 16.0, 9.0 / 19.5, 3.0 / 4.0]
        if commonScreenshotRatios.contains(where: { abs($0 - ratio) < 0.05 }) && analysis.textLineCount > 2 {
            return "ratio+text"
        }
        return nil
    }

    private static func isPlaceCategory(_ label: String) -> Bool {
        let lowered = label.lowercased()
        return ["landscape", "beach", "mountain", "city", "architecture", "outdoor", "sky", "ocean", "forest"]
            .contains { lowered.contains($0) }
    }
}
