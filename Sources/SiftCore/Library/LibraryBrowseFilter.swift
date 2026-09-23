import Foundation

/// Scope for library grid and preview carousel.
public enum LibraryBrowseScope: Equatable, Sendable {
    /// Every indexed source combined.
    case allSources
    /// The persistent catalog. This does not walk the disk.
    case entireCatalog
    /// Files still at source folders, not yet under the active destination layout.
    case inbox
    /// One added folder source (by bookmark id); optional subfolder path relative to source root.
    case source(bookmarkID: String, subfolder: String?)

    public var sourceBookmarkID: String? {
        if case .source(let id, _) = self { return id }
        return nil
    }

    public var subfolder: String? {
        if case .source(_, let sub) = self { return sub }
        return nil
    }
}

public enum LibraryAssetSort: String, CaseIterable, Sendable, Codable {
    case dateModifiedNewest
    case dateModifiedOldest
    case fileNameAZ
    case fileNameZA
    case fileSizeLargest
    case fileSizeSmallest

    public var displayName: String {
        switch self {
        case .dateModifiedNewest: "Date (newest)"
        case .dateModifiedOldest: "Date (oldest)"
        case .fileNameAZ: "Name (A–Z)"
        case .fileNameZA: "Name (Z–A)"
        case .fileSizeLargest: "Size (largest)"
        case .fileSizeSmallest: "Size (smallest)"
        }
    }
}

public enum LibraryKindFilter: String, CaseIterable, Sendable {
    case all
    case photos
    case videos
    case screenshots
    case withFaces

    public var displayName: String {
        switch self {
        case .all: "All kinds"
        case .photos: "Photos"
        case .videos: "Videos"
        case .screenshots: "Screenshots"
        case .withFaces: "With faces"
        }
    }

    public func matches(kind: MediaKind, isScreenshotOrDocument: Bool, faceCount: Int) -> Bool {
        switch self {
        case .all: true
        case .photos: kind == .image && !isScreenshotOrDocument
        case .videos: kind == .video
        case .screenshots: isScreenshotOrDocument
        case .withFaces: faceCount > 0
        }
    }
}

public enum LibraryBrowseFilter {
    /// Parent directory path relative to source root (`""` = file sits at source root).
    public static func relativeParentDirectory(fileURL: URL, sourceRoot: URL) -> String {
        let root = sourceRoot.standardizedFileURL.path
        let file = fileURL.standardizedFileURL.path
        guard file.hasPrefix(root) else { return "" }
        var remainder = String(file.dropFirst(root.count))
        if remainder.hasPrefix("/") { remainder.removeFirst() }
        let parent = (remainder as NSString).deletingLastPathComponent
        return parent == "." ? "" : parent
    }

    public static func matchesSubfolder(
        fileURL: URL,
        sourceRoot: URL,
        subfolder: String?
    ) -> Bool {
        guard let subfolder, !subfolder.isEmpty else { return true }
        let parent = relativeParentDirectory(fileURL: fileURL, sourceRoot: sourceRoot)
        return parent == subfolder || parent.hasPrefix(subfolder + "/")
    }

    public static func sortRecords(
        _ records: [MediaAssetRecord],
        by sort: LibraryAssetSort
    ) -> [MediaAssetRecord] {
        switch sort {
        case .dateModifiedNewest:
            return records.sorted { lhs, rhs in
                let l = lhs.modifiedAt ?? lhs.createdAt ?? lhs.indexedAt
                let r = rhs.modifiedAt ?? rhs.createdAt ?? rhs.indexedAt
                if l != r { return l > r }
                return lhs.fileURL.lastPathComponent.localizedStandardCompare(rhs.fileURL.lastPathComponent) == .orderedAscending
            }
        case .dateModifiedOldest:
            return records.sorted { lhs, rhs in
                let l = lhs.modifiedAt ?? lhs.createdAt ?? lhs.indexedAt
                let r = rhs.modifiedAt ?? rhs.createdAt ?? rhs.indexedAt
                if l != r { return l < r }
                return lhs.fileURL.lastPathComponent.localizedStandardCompare(rhs.fileURL.lastPathComponent) == .orderedAscending
            }
        case .fileNameAZ:
            return records.sorted {
                $0.fileURL.lastPathComponent.localizedStandardCompare($1.fileURL.lastPathComponent) == .orderedAscending
            }
        case .fileNameZA:
            return records.sorted {
                $0.fileURL.lastPathComponent.localizedStandardCompare($1.fileURL.lastPathComponent) == .orderedDescending
            }
        case .fileSizeLargest:
            return records.sorted { ($0.fileSize ?? 0) > ($1.fileSize ?? 0) }
        case .fileSizeSmallest:
            return records.sorted { ($0.fileSize ?? 0) < ($1.fileSize ?? 0) }
        }
    }

    public struct SubfolderOption: Identifiable, Hashable, Sendable {
        public let id: String
        public let title: String
        public let relativePath: String
        public let assetCount: Int

        public init(relativePath: String, assetCount: Int) {
            self.relativePath = relativePath
            self.id = relativePath.isEmpty ? "__root__" : relativePath
            self.title = relativePath.isEmpty ? "All in source" : relativePath
            self.assetCount = assetCount
        }
    }

    public static func subfolderOptions(
        records: [MediaAssetRecord],
        sourceRoot: URL
    ) -> [SubfolderOption] {
        var counts: [String: Int] = [:]
        for record in records {
            let parent = relativeParentDirectory(fileURL: record.fileURL, sourceRoot: sourceRoot)
            counts[parent, default: 0] += 1
        }
        var options = [SubfolderOption(relativePath: "", assetCount: records.count)]
        let sorted = counts.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        for path in sorted where !path.isEmpty {
            options.append(SubfolderOption(relativePath: path, assetCount: counts[path] ?? 0))
        }
        return options
    }
}
