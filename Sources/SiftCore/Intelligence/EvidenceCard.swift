import Foundation
import UniformTypeIdentifiers

/// The text Jev sees for one file. Built only from catalog columns, never from pixels or the whole document.
public struct EvidenceCard: Sendable, Equatable {
    /// Bump when the analyzer starts writing a new column the card needs.
    public static let currentVersion = 1
    /// A Vision label under this score describes the picture too weakly to route a file.
    public static let visionFloor = 0.30
    public static let ocrLineLimit = 3

    public let fileName: String
    public let fileExtension: String
    public let kind: MediaKind
    public let sourceLabel: String
    public let fileSize: Int64?
    public let captureDate: Date?
    public let modifiedAt: Date?
    public let pixelWidth: Int?
    public let pixelHeight: Int?
    public let durationSeconds: Double?
    public let screenshotReason: String?
    public let faceCount: Int
    public let labels: [LabelScore]
    public let ocr: [String]
    public let isAnalyzed: Bool

    public init(
        fileName: String,
        fileExtension: String,
        kind: MediaKind,
        sourceLabel: String,
        fileSize: Int64? = nil,
        captureDate: Date? = nil,
        modifiedAt: Date? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        durationSeconds: Double? = nil,
        screenshotReason: String? = nil,
        faceCount: Int = 0,
        labels: [LabelScore] = [],
        rejected: [String] = [],
        ocr: [String] = [],
        isAnalyzed: Bool = false
    ) {
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.kind = kind
        self.sourceLabel = sourceLabel
        self.fileSize = fileSize
        self.captureDate = captureDate
        self.modifiedAt = modifiedAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.durationSeconds = durationSeconds
        self.screenshotReason = screenshotReason
        self.faceCount = faceCount
        self.labels = Self.decisionLabels(labels, rejected: rejected)
        self.ocr = Array(ocr.prefix(Self.ocrLineLimit))
        self.isAnalyzed = isAnalyzed
    }

    public init(record: MediaAssetRecord) {
        self.init(
            fileName: record.fileURL.lastPathComponent,
            fileExtension: record.fileExtension ?? Self.fileExtension(of: record.fileURL),
            kind: record.kind,
            sourceLabel: record.sourceLabel,
            fileSize: record.fileSize,
            captureDate: record.captureDate,
            modifiedAt: record.modifiedAt,
            pixelWidth: record.pixelWidth,
            pixelHeight: record.pixelHeight,
            durationSeconds: record.durationSeconds,
            screenshotReason: record.screenshotReason,
            faceCount: record.faceCount,
            labels: record.labelScores,
            rejected: record.rejectedLabels,
            ocr: record.recognizedTextLines,
            isAnalyzed: record.isAnalyzed
        )
    }

    /// Labels strong enough to decide with, highest first. A label the user removed never comes back.
    public static func decisionLabels(_ labels: [LabelScore], rejected: [String] = []) -> [LabelScore] {
        let refused = Set(rejected.map { $0.lowercased() })
        return labels
            .filter { !refused.contains($0.label.lowercased()) }
            .filter { $0.source != .vision || $0.score >= visionFloor }
            .sorted { $0.score == $1.score ? $0.label < $1.label : $0.score > $1.score }
    }

    /// The date a plan by date uses: capture date first, then the file date.
    public var bestDate: Date? { captureDate ?? modifiedAt }

    /// One stable line. The same catalog row always gives the same text.
    public var text: String {
        var parts = ["file \(fileName)", "ext \(fileExtension.isEmpty ? "none" : fileExtension)", "kind \(kind.rawValue)"]
        parts.append("source \(sourceLabel)")
        if let fileSize { parts.append("size \(Self.sizeText(fileSize))") }
        if let captureDate { parts.append("taken \(Self.day(captureDate))") }
        if let modifiedAt { parts.append("modified \(Self.day(modifiedAt))") }
        if let pixelWidth, let pixelHeight { parts.append("pixels \(pixelWidth)x\(pixelHeight)") }
        if let durationSeconds { parts.append("duration \(Int(durationSeconds.rounded()))s") }
        if let screenshotReason { parts.append("screenshot \(screenshotReason)") }
        if faceCount > 0 { parts.append("faces \(faceCount)") }
        if !labels.isEmpty {
            parts.append("labels " + labels.prefix(8).map { "\($0.label) \(String(format: "%.2f", $0.score))" }.joined(separator: ", "))
        }
        if !ocr.isEmpty {
            parts.append("text " + ocr.map { String($0.prefix(60)) }.joined(separator: " / "))
        }
        return parts.joined(separator: "; ")
    }

    public static func fileExtension(of url: URL) -> String {
        url.pathExtension.lowercased()
    }

    public static func uti(forExtension ext: String?) -> String? {
        guard let ext, !ext.isEmpty else { return nil }
        return UTType(filenameExtension: ext)?.identifier
    }

    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func sizeText(_ bytes: Int64) -> String {
        if bytes >= 1_000_000 { return "\(bytes / 1_000_000)MB" }
        if bytes >= 1_000 { return "\(bytes / 1_000)KB" }
        return "\(bytes)B"
    }
}

extension MediaAssetRecord {
    /// Writes the evidence columns from one analysis. Absent values keep what the row already had.
    public func applyEvidence(from result: PhotoAnalysisResult) {
        if let value = result.pixelWidth { pixelWidth = value }
        if let value = result.pixelHeight { pixelHeight = value }
        if let value = result.durationSeconds { durationSeconds = value }
        if let value = result.captureDate { captureDate = value }
        screenshotReason = result.screenshotReason
        let refused = Set(rejectedLabels)
        if let scores = result.labelScores {
            labelScores = scores
        }
        if !refused.isEmpty {
            topCategories = topCategories.filter { !refused.contains($0) }
        }
        if fileExtension == nil {
            fileExtension = EvidenceCard.fileExtension(of: fileURL)
            uti = EvidenceCard.uti(forExtension: fileExtension)
        }
        evidenceVersion = EvidenceCard.currentVersion
    }
}
