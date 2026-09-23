import Foundation

/// Groups screenshot-like assets by shared OCR tokens (project / app / customer hints).
public enum ScreenshotProjectGrouper {
    public struct ProjectGroup: Sendable, Identifiable {
        public let id: String
        public let suggestedTitle: String
        public let assetIDs: [String]

        public init(id: String, suggestedTitle: String, assetIDs: [String]) {
            self.id = id
            self.suggestedTitle = suggestedTitle
            self.assetIDs = assetIDs
        }
    }

    public static func suggestGroups(from assets: [MediaAssetRecord], minSize: Int = 3) -> [ProjectGroup] {
        var buckets: [String: [String]] = [:]
        for asset in assets where asset.isScreenshotOrDocument || asset.textLineCount > 2 {
            let key = signature(for: asset)
            guard !key.isEmpty else { continue }
            buckets[key, default: []].append(asset.id)
        }
        return buckets
            .filter { $0.value.count >= minSize }
            .map { key, ids in
                ProjectGroup(
                    id: "project:\(key)",
                    suggestedTitle: key.capitalized,
                    assetIDs: ids
                )
            }
            .sorted { $0.assetIDs.count > $1.assetIDs.count }
    }

    private static func signature(for asset: MediaAssetRecord) -> String {
        let tokens = asset.topCategories
            .prefix(3)
            .map { $0.lowercased() }
        if tokens.isEmpty {
            return asset.textLineCount > 5 ? "documents" : ""
        }
        return tokens.joined(separator: "-")
    }
}
