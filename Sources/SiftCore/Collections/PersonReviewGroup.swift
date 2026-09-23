import Foundation

public struct PersonReviewPreview: Sendable, Hashable, Identifiable {
    public let id: String
    public let thumbnailPath: String?

    public init(id: String, thumbnailPath: String?) {
        self.id = id
        self.thumbnailPath = thumbnailPath
    }
}

/// Face group built from `personClusterID`, so review can show photos even when the collection relationship is empty.
public struct PersonReviewGroup: Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let assetIDs: [String]
    public let previews: [PersonReviewPreview]
    public let count: Int

    public init(
        id: String,
        title: String,
        assetIDs: [String],
        previews: [PersonReviewPreview],
        count: Int
    ) {
        self.id = id
        self.title = title
        self.assetIDs = assetIDs
        self.previews = previews
        self.count = count
    }
}
