import Foundation

public struct PhotoAnalysisResult: Sendable, Codable, Hashable {
    public var isScreenshotOrDocument: Bool
    public var textLineCount: Int
    public var topCategories: [String]
    public var detectedAnimals: [String]
    public var faceCount: Int
    public var featurePrintData: Data?
    public var recognizedText: [String]

    public init(
        isScreenshotOrDocument: Bool = false,
        textLineCount: Int = 0,
        topCategories: [String] = [],
        detectedAnimals: [String] = [],
        faceCount: Int = 0,
        featurePrintData: Data? = nil,
        recognizedText: [String] = []
    ) {
        self.isScreenshotOrDocument = isScreenshotOrDocument
        self.textLineCount = textLineCount
        self.topCategories = topCategories
        self.detectedAnimals = detectedAnimals
        self.faceCount = faceCount
        self.featurePrintData = featurePrintData
        self.recognizedText = recognizedText
    }
}

public struct AssetMetadata: Sendable {
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var isScreenshotCandidate: Bool
    public var captureDate: Date?

    public init(
        pixelWidth: Int,
        pixelHeight: Int,
        isScreenshotCandidate: Bool = false,
        captureDate: Date? = nil
    ) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.isScreenshotCandidate = isScreenshotCandidate
        self.captureDate = captureDate
    }
}
