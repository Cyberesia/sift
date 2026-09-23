import Foundation

public struct SubfolderNode: Identifiable, Sendable, Hashable {
    public let id: String
    public let relativePath: String
    public let displayName: String
    public var imageCount: Int
    public var videoCount: Int
    public var children: [SubfolderNode]

    public var mediaCount: Int { imageCount + videoCount }

    public init(
        id: String,
        relativePath: String,
        displayName: String,
        imageCount: Int = 0,
        videoCount: Int = 0,
        children: [SubfolderNode] = []
    ) {
        self.id = id
        self.relativePath = relativePath
        self.displayName = displayName
        self.imageCount = imageCount
        self.videoCount = videoCount
        self.children = children
    }
}

public struct FolderTreeEstimate: Sendable {
    public let rootName: String
    public let rootImages: Int
    public let rootVideos: Int
    public let totalImages: Int
    public let totalVideos: Int
    public let totalBytes: Int64
    public let nodes: [SubfolderNode]

    public var totalMedia: Int { totalImages + totalVideos }
    public var rootMedia: Int { rootImages + rootVideos }
    public var hasRootMedia: Bool { rootMedia > 0 }

    public init(
        rootName: String,
        rootImages: Int = 0,
        rootVideos: Int = 0,
        totalImages: Int,
        totalVideos: Int,
        totalBytes: Int64,
        nodes: [SubfolderNode]
    ) {
        self.rootName = rootName
        self.rootImages = rootImages
        self.rootVideos = rootVideos
        self.totalImages = totalImages
        self.totalVideos = totalVideos
        self.totalBytes = totalBytes
        self.nodes = nodes
    }
}

public enum FolderTreeScanner {
    public static func estimate(at root: URL) async throws -> FolderTreeEstimate {
        try await Task.detached(priority: .utility) {
            try estimateWhileAccessActive(at: root)
        }.value
    }

    private static func estimateWhileAccessActive(at root: URL) throws -> FolderTreeEstimate {
        var dirStats: [String: (images: Int, videos: Int, bytes: Int64)] = [:]
        var rootImages = 0
        var rootVideos = 0
        var rootBytes: Int64 = 0

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentTypeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return FolderTreeEstimate(
                rootName: root.lastPathComponent,
                totalImages: 0,
                totalVideos: 0,
                totalBytes: 0,
                nodes: []
            )
        }

        while let element = enumerator.nextObject() {
            guard let fileURL = element as? URL else { continue }
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), isDir.boolValue,
               ScanExclusionPolicy.standard.skipReason(forDirectory: fileURL) != nil {
                enumerator.skipDescendants()
                ScanStats.shared.recordSkippedTree()
                continue
            }
            let values = try? fileURL.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            guard let kind = scannerMediaKind(for: values?.contentType, url: fileURL) else { continue }

            let bytes = Int64(values?.fileSize ?? 0)
            let dir = MediaScanner.relativeDirectoryPath(fileURL: fileURL, root: root)
            if dir.isEmpty {
                if kind == .image { rootImages += 1 } else { rootVideos += 1 }
                rootBytes += bytes
            } else {
                var entry = dirStats[dir] ?? (0, 0, 0)
                if kind == .image { entry.images += 1 } else { entry.videos += 1 }
                entry.bytes += bytes
                dirStats[dir] = entry
            }
        }

        var nodes = buildTree(from: dirStats)
        if rootImages > 0 || rootVideos > 0 {
            nodes.insert(
                SubfolderNode(
                    id: "",
                    relativePath: "",
                    displayName: "This folder",
                    imageCount: rootImages,
                    videoCount: rootVideos
                ),
                at: 0
            )
        }

        let totals = dirStats.values.reduce((rootImages, rootVideos, rootBytes)) { partial, item in
            (partial.0 + item.images, partial.1 + item.videos, partial.2 + item.bytes)
        }

        return FolderTreeEstimate(
            rootName: root.lastPathComponent,
            rootImages: rootImages,
            rootVideos: rootVideos,
            totalImages: totals.0,
            totalVideos: totals.1,
            totalBytes: totals.2,
            nodes: nodes
        )
    }

    private static func buildTree(from stats: [String: (images: Int, videos: Int, bytes: Int64)]) -> [SubfolderNode] {
        var nodesByPath: [String: SubfolderNode] = [:]
        let sortedPaths = stats.keys.sorted()
        for path in sortedPaths {
            let stat = stats[path]!
            let name = (path as NSString).lastPathComponent
            nodesByPath[path] = SubfolderNode(
                id: path,
                relativePath: path,
                displayName: name,
                imageCount: stat.images,
                videoCount: stat.videos
            )
        }

        var roots: [SubfolderNode] = []
        for path in sortedPaths {
            guard var node = nodesByPath[path] else { continue }
            let parentPath = (path as NSString).deletingLastPathComponent
            if parentPath.isEmpty || parentPath == path {
                roots.append(node)
            } else if var parent = nodesByPath[parentPath] {
                parent.children.append(node)
                nodesByPath[parentPath] = parent
            } else {
                roots.append(node)
            }
        }
        return roots.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func scannerMediaKind(for contentType: UTType?, url: URL) -> MediaKind? {
        if let contentType {
            if contentType.conforms(to: .image) { return .image }
            if contentType.conforms(to: .movie) || contentType.conforms(to: .video) { return .video }
            if contentType.conforms(to: .audio) { return .audio }
        }
        let ext = url.pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tif", "tiff", "bmp", "raw", "dng", "cr2", "nef", "arw"]
        let videoExts = ["mov", "mp4", "m4v", "avi", "mkv", "webm", "mts", "m2ts", "3gp"]
        let audioExts = ["mp3", "m4a", "aac", "wav", "aiff", "aif", "flac", "caf", "alac"]
        if imageExts.contains(ext) { return .image }
        if videoExts.contains(ext) { return .video }
        if audioExts.contains(ext) { return .audio }
        return nil
    }
}

import UniformTypeIdentifiers
