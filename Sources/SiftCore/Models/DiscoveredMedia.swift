import Foundation

/// Ephemeral scan result before persistence.
public struct DiscoveredMedia: Sendable, Identifiable, Hashable {
    public let id: String
    public let url: URL
    public let kind: MediaKind
    public let sourceKind: MediaSourceKind
    public let sourceLabel: String
    public let fileSize: Int64?
    public let contentHash: String
    public let createdAt: Date?
    public let modifiedAt: Date?

    public init(
        id: String,
        url: URL,
        kind: MediaKind,
        sourceKind: MediaSourceKind,
        sourceLabel: String,
        fileSize: Int64?,
        contentHash: String,
        createdAt: Date?,
        modifiedAt: Date?
    ) {
        self.id = id
        self.url = url
        self.kind = kind
        self.sourceKind = sourceKind
        self.sourceLabel = sourceLabel
        self.fileSize = fileSize
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
