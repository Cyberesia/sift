import SiftCore
import Testing

@Test func pipelineClassifierRoutesVideo() {
    let analysis = PhotoAnalysisResult()
    let meta = AssetMetadata(pixelWidth: 1920, pixelHeight: 1080)
    let pipeline = PipelineClassifier.classify(kind: .video, analysis: analysis, metadata: meta)
    #expect(pipeline == .videos)
}

@Test func pipelineClassifierDetectsArtifacts() {
    let analysis = PhotoAnalysisResult(isScreenshotOrDocument: true, textLineCount: 8)
    let meta = AssetMetadata(pixelWidth: 1170, pixelHeight: 2532, isScreenshotCandidate: true)
    #expect(PipelineClassifier.isArtifact(analysis: analysis, metadata: meta))
}
