import Foundation

public struct OrganizePlanItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let fileName: String
    public let sourcePath: String
    public let proposedFolder: String
    public let reason: String
    public let blocked: Bool
    public let blockReason: String?

    public init(
        id: String,
        fileName: String,
        sourcePath: String,
        proposedFolder: String,
        reason: String,
        blocked: Bool,
        blockReason: String?
    ) {
        self.id = id
        self.fileName = fileName
        self.sourcePath = sourcePath
        self.proposedFolder = proposedFolder
        self.reason = reason
        self.blocked = blocked
        self.blockReason = blockReason
    }
}

public struct OrganizeCandidate: Sendable {
    public let id: String
    public let path: String
    public let pipelineName: String

    public init(id: String, path: String, pipelineName: String) {
        self.id = id
        self.path = path
        self.pipelineName = pipelineName
    }
}

public enum OrganizePlanner {
    /// Dry run. Nothing is copied or moved.
    public static func preview(
        candidates: [OrganizeCandidate],
        policy: ScanExclusionPolicy = .standard,
        inDestinationPaths: Set<String> = [],
        originPaths: Set<String> = [],
        outsidePaths: Set<String> = []
    ) -> [OrganizePlanItem] {
        candidates.map { candidate in
            let url = URL(fileURLWithPath: candidate.path)
            let path = url.standardizedFileURL.path
            if inDestinationPaths.contains(path) {
                return held(id: candidate.id, url: url, reason: "Already inside the destination")
            }
            if outsidePaths.contains(path) {
                return held(id: candidate.id, url: url, reason: "Already filed outside the destination")
            }
            if originPaths.contains(path) {
                return held(id: candidate.id, url: url, reason: "Still in the original folder. A copy is already filed.")
            }
            if let reason = policy.isBlockedSource(url) {
                return OrganizePlanItem(
                    id: candidate.id,
                    fileName: url.lastPathComponent,
                    sourcePath: url.path,
                    proposedFolder: "",
                    reason: "Left in place",
                    blocked: true,
                    blockReason: reason.rawValue
                )
            }
            let proposedFolder: String = switch candidate.pipelineName {
            case MediaPipeline.videos.displayName: "Videos"
            case MediaPipeline.music.displayName: "Music & Audio"
            case MediaPipeline.artifacts.displayName: "Screenshots & Documents"
            case MediaPipeline.documents.displayName: "Documents"
            default: "Photos"
            }
            return OrganizePlanItem(
                id: candidate.id,
                fileName: url.lastPathComponent,
                sourcePath: url.path,
                proposedFolder: proposedFolder,
                reason: "Classified as \(candidate.pipelineName)",
                blocked: false,
                blockReason: nil
            )
        }
    }

    private static func held(id: String, url: URL, reason: String) -> OrganizePlanItem {
        OrganizePlanItem(
            id: id,
            fileName: url.lastPathComponent,
            sourcePath: url.path,
            proposedFolder: "",
            reason: reason,
            blocked: true,
            blockReason: reason
        )
    }
}
