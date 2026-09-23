import Foundation

public enum DuplicateGroupKind: String, Sendable {
    case exact
    case near
}

public struct DuplicateGroup: Identifiable, Sendable {
    public let id: String
    public let kind: DuplicateGroupKind
    public let memberIDs: [String]
    public let suggestedKeepID: String
    public let reclaimableBytes: Int64
    /// Thumbnail paths keyed by asset id. Empty when the scan had no preview yet.
    public let thumbnailPaths: [String: String]

    public init(
        id: String = UUID().uuidString,
        kind: DuplicateGroupKind,
        memberIDs: [String],
        suggestedKeepID: String,
        reclaimableBytes: Int64,
        thumbnailPaths: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.memberIDs = memberIDs
        self.suggestedKeepID = suggestedKeepID
        self.reclaimableBytes = reclaimableBytes
        self.thumbnailPaths = thumbnailPaths
    }

    public var extraIDs: [String] {
        memberIDs.filter { $0 != suggestedKeepID }
    }
}
