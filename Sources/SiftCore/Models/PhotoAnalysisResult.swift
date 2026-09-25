import Foundation

/// One label with the score it was produced with, and where it came from.
public struct LabelScore: Sendable, Codable, Hashable {
    public enum Source: String, Sendable, Codable {
        case vision
        case documentKind
        case documentSubject
        case audio
    }

    public var label: String
    public var score: Double
    public var source: Source

    public init(label: String, score: Double, source: Source) {
        self.label = label
        self.score = score
        self.source = source
    }
}

public struct PhotoAnalysisResult: Sendable, Codable, Hashable {
    public var isScreenshotOrDocument: Bool
    public var textLineCount: Int
    public var topCategories: [String]
    public var detectedAnimals: [String]
    public var faceCount: Int
    public var featurePrintData: Data?
    public var recognizedText: [String]
    public var labelScores: [LabelScore]?
    public var pixelWidth: Int?
    public var pixelHeight: Int?
    public var durationSeconds: Double?
    public var captureDate: Date?
    public var screenshotReason: String?

    public init(
        isScreenshotOrDocument: Bool = false,
        textLineCount: Int = 0,
        topCategories: [String] = [],
        detectedAnimals: [String] = [],
        faceCount: Int = 0,
        featurePrintData: Data? = nil,
        recognizedText: [String] = [],
        labelScores: [LabelScore]? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        durationSeconds: Double? = nil,
        captureDate: Date? = nil,
        screenshotReason: String? = nil
    ) {
        self.isScreenshotOrDocument = isScreenshotOrDocument
        self.textLineCount = textLineCount
        self.topCategories = topCategories
        self.detectedAnimals = detectedAnimals
        self.faceCount = faceCount
        self.featurePrintData = featurePrintData
        self.recognizedText = recognizedText
        self.labelScores = labelScores
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.durationSeconds = durationSeconds
        self.captureDate = captureDate
        self.screenshotReason = screenshotReason
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
