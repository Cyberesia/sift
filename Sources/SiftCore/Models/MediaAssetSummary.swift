import Foundation

/// Lightweight, UI-safe snapshot of an indexed asset (not a SwiftData model).
public struct MediaAssetSummary: Sendable, Identifiable, Hashable {
    public let id: String
    public let fileName: String
    public let fileURL: URL
    public let kind: MediaKind
    public let pipeline: MediaPipeline
    public let thumbnailPath: String?
    /// Width divided by height of the thumbnail (portrait below 1, landscape above 1).
    public let aspectRatio: CGFloat
    public let sourceLabel: String
    public let faceCount: Int
    public let topCategories: [String]
    public let detectedAnimals: [String]
    /// User-assigned name for the person group this photo belongs to.
    public let personDisplayName: String?
    /// When this file entered the catalog.
    public let addedAt: Date

    public init(record: MediaAssetRecord, personDisplayName: String? = nil) {
        self.id = record.id
        self.fileName = record.fileURL.lastPathComponent
        self.fileURL = record.fileURL
        self.kind = record.kind
        self.pipeline = record.pipeline
        self.thumbnailPath = record.thumbnailPath
        self.aspectRatio = ThumbnailMetadata.cachedAspectRatio(thumbnailPath: record.thumbnailPath)
        self.sourceLabel = record.sourceLabel
        self.faceCount = record.faceCount
        self.topCategories = record.topCategories
        self.detectedAnimals = record.detectedAnimals
        self.personDisplayName = personDisplayName
        self.addedAt = record.indexedAt
    }
}

public enum GalleryDateLabel {
    public static func added(_ date: Date) -> String {
        "Added \(date.formatted(date: .abbreviated, time: .omitted))"
    }
}
