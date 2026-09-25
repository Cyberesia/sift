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
    public let sourceLabel: String
    public let kind: MediaKind
    public let fileExtension: String
    public let date: Date?
    public let evidenceComplete: Bool
    public let undoneFolder: String?

    public init(
        id: String,
        path: String,
        pipelineName: String,
        sourceLabel: String = "",
        kind: MediaKind = .image,
        fileExtension: String = "",
        date: Date? = nil,
        evidenceComplete: Bool = true,
        undoneFolder: String? = nil
    ) {
        self.id = id
        self.path = path
        self.pipelineName = pipelineName
        self.sourceLabel = sourceLabel
        self.kind = kind
        self.fileExtension = CatalogSlice.normalized(fileExtension.isEmpty ? URL(fileURLWithPath: path).pathExtension : fileExtension)
        self.date = date
        self.evidenceComplete = evidenceComplete
        self.undoneFolder = undoneFolder
    }
}

public struct OrganizePlanRule: Sendable, Equatable {
    public let intent: AssistantIntent
    public let slice: CatalogSlice
    public let destinationFolder: String?
    public let grouping: AssistantGrouping?

    public init(
        intent: AssistantIntent,
        slice: CatalogSlice = .everything,
        destinationFolder: String? = nil,
        grouping: AssistantGrouping? = nil
    ) {
        self.intent = intent
        self.slice = slice
        self.destinationFolder = destinationFolder
        self.grouping = grouping
    }
}

/// The first Organize step the user still has to finish before files can be filed.
public enum OrganizeBlocker: Int, Sendable, Equatable {
    case destination = 1
    case transferChoice = 2

    public static func first(hasDestination: Bool, transferChosen: Bool) -> OrganizeBlocker? {
        if !hasDestination { return .destination }
        if !transferChosen { return .transferChoice }
        return nil
    }

    public var step: Int { rawValue }

    public var instruction: String {
        switch self {
        case .destination: "Add a destination folder in step 1"
        case .transferChoice: "Choose Move or Copy in step 2"
        }
    }
}

public enum OrganizePlanner {
    /// Dry run. Nothing is copied or moved.
    public static func preview(
        candidates: [OrganizeCandidate],
        policy: ScanExclusionPolicy = .standard,
        inDestinationPaths: Set<String> = [],
        originPaths: Set<String> = [],
        outsidePaths: Set<String> = [],
        rule: OrganizePlanRule? = nil
    ) -> [OrganizePlanItem] {
        candidates.map { candidate in
            let url = URL(fileURLWithPath: candidate.path)
            let path = url.standardizedFileURL.path
            if let rule, !rule.slice.contains(CompositionFile(
                id: candidate.id,
                sourceLabel: candidate.sourceLabel,
                fileExtension: candidate.fileExtension,
                kind: candidate.kind,
                date: candidate.date,
                isAnalyzed: candidate.evidenceComplete
            )) {
                return held(id: candidate.id, url: url, reason: "Outside the selected catalog slice")
            }
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
            if let rule {
                if rule.intent == .organizeByContent, !candidate.evidenceComplete {
                    return held(id: candidate.id, url: url, reason: "Content evidence is not ready")
                }
                if rule.intent == .organizeByDate, candidate.date == nil {
                    return held(id: candidate.id, url: url, reason: "No reliable date is available")
                }
                if rule.intent == .organizeByType, candidate.fileExtension.isEmpty {
                    return held(id: candidate.id, url: url, reason: "No file extension is available")
                }
            }
            let proposedFolder = proposedFolder(for: candidate, rule: rule)
            if candidate.undoneFolder == proposedFolder {
                return held(id: candidate.id, url: url, reason: "You undid this filing suggestion")
            }
            return OrganizePlanItem(
                id: candidate.id,
                fileName: url.lastPathComponent,
                sourcePath: url.path,
                proposedFolder: proposedFolder,
                reason: ruleReason(candidate: candidate, rule: rule),
                blocked: false,
                blockReason: nil
            )
        }
    }

    private static func proposedFolder(for candidate: OrganizeCandidate, rule: OrganizePlanRule?) -> String {
        let base = rule?.destinationFolder ?? defaultFolder(for: candidate)
        guard let grouping = rule?.grouping, let date = candidate.date else { return base }
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        guard let year = components.year else { return base }
        switch grouping {
        case .year:
            return "\(base)/\(year)"
        case .month:
            guard let month = components.month else { return "\(base)/\(year)" }
            return "\(base)/\(String(format: "%04d-%02d", year, month))"
        }
    }

    private static func defaultFolder(for candidate: OrganizeCandidate) -> String {
        switch candidate.pipelineName {
        case MediaPipeline.videos.displayName: "Videos"
        case MediaPipeline.music.displayName: "Music & Audio"
        case MediaPipeline.artifacts.displayName: "Screenshots & Documents"
        case MediaPipeline.documents.displayName: "Documents"
        default: "Photos"
        }
    }

    private static func ruleReason(candidate: OrganizeCandidate, rule: OrganizePlanRule?) -> String {
        guard let rule else { return "Classified as \(candidate.pipelineName)" }
        switch rule.intent {
        case .organizeByDate:
            return "Matches the selected date rule"
        case .organizeByContent:
            return "Matches the catalog evidence and selected destination"
        case .organizeByType:
            return "Matches .\(candidate.fileExtension) in the selected catalog slice"
        default:
            return "Matches the selected assistant rule"
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
