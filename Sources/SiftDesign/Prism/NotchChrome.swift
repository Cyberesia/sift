import SiftCore
import SwiftUI

public struct NotchLink: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String

    public init(id: String, title: String, subtitle: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

@MainActor
public final class NotchChrome: ObservableObject {
    @Published public var query = ""
    @Published public var saved: [NotchLink] = []
    @Published public var people: [NotchLink] = []
    @Published public var hits: [MediaAssetSummary] = []
    @Published public var latest: [MediaAssetSummary] = []
    @Published public var searchActive = false
    @Published public var assetCount = 0
    @Published public var folderCount = 0
    @Published public var inboxCount = 0
    @Published public var suggestionCount = 0
    @Published public var duplicateCount = 0
    @Published public var pipelineName = "All Media"
    @Published public var photoCount = 0
    @Published public var videoCount = 0
    @Published public var audioCount = 0
    @Published public var skippedTrees = 0
    @Published public var planCount = 0
    @Published public var blockedPlanCount = 0
    @Published public var fullDiskAccess = false
    @Published public var clipReady = false
    @Published public var clipEmbeddedCount = 0

    public init() {}

    public func caption(for item: NotchRailItem, progressFraction: Double?) -> String {
        switch item {
        case .index:
            if let progressFraction { return "\(Int(progressFraction * 100))%" }
            return "Ready"
        case .library: return "\(assetCount)"
        case .garden: return "Space"
        case .sources: return "\(folderCount)"
        case .inbox: return "\(inboxCount)"
        case .organize: return blockedPlanCount > 0 ? "\(blockedPlanCount) held" : "Plan"
        case .review: return "\(suggestionCount)"
        case .duplicates: return "\(duplicateCount)"
        case .search: return searchActive ? "\(hits.count)" : "Mac"
        }
    }
}
