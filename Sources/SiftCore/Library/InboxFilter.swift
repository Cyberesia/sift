import Foundation

/// Assets still at source folders and not yet under an organize destination.
public enum InboxFilter {
    public static func isInbox(
        assetURL: URL,
        sourceRoots: [URL],
        destinationRoot: URL?
    ) -> Bool {
        let path = assetURL.standardizedFileURL.path
        guard isUnderAnyRoot(path: path, roots: sourceRoots) else { return false }
        return !isUnderDestination(path: path, destinationRoot: destinationRoot)
    }

    public static func isUnderAnyRoot(path: String, roots: [URL]) -> Bool {
        for root in roots {
            let rootPath = root.standardizedFileURL.path
            if path == rootPath || path.hasPrefix(rootPath + "/") {
                return true
            }
        }
        return false
    }

    public static func isUnderDestination(path: String, destinationRoot: URL?) -> Bool {
        guard let destinationRoot else { return false }
        let destPath = destinationRoot.standardizedFileURL.path
        guard !destPath.isEmpty, path.hasPrefix(destPath) else { return false }
        return true
    }

    public static func filterInbox(
        _ records: [MediaAssetRecord],
        sourceRoots: [URL],
        destinationRoot: URL?
    ) -> [MediaAssetRecord] {
        guard !sourceRoots.isEmpty else {
            return records.filter { !isUnderDestination(path: $0.fileURL.path, destinationRoot: destinationRoot) }
        }
        return records.filter {
            isInbox(assetURL: $0.fileURL, sourceRoots: sourceRoots, destinationRoot: destinationRoot)
        }
    }
}
