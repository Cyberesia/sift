import Foundation
import UniformTypeIdentifiers

public struct MediaScanner: Sendable {
    public var exclusionPolicy: ScanExclusionPolicy

    public init(exclusionPolicy: ScanExclusionPolicy = .standard) {
        self.exclusionPolicy = exclusionPolicy
    }

    public func scanFolder(
        at root: URL,
        sourceLabel: String,
        includeSubfolders: Bool = true,
        includedSubfolderPaths: [String]? = nil,
        runControl: IndexingRunControl? = nil,
        kinds: Set<MediaKind> = Set(MediaKind.allCases),
        documentExtensions: Set<String> = DocumentFormats.extensions,
        progress: (@Sendable @MainActor (Int, String) -> Void)? = nil
    ) async throws -> [DiscoveredMedia] {
        let allowed = kinds.isEmpty ? Set(MediaKind.allCases) : kinds
        let extensions = documentExtensions.isEmpty ? DocumentFormats.extensions : documentExtensions
        return try await Task.detached(priority: .userInitiated) { [runControl] in
            try await self.scanFolderWhileAccessActive(
                at: root,
                sourceLabel: sourceLabel,
                includeSubfolders: includeSubfolders,
                includedSubfolderPaths: includedSubfolderPaths,
                runControl: runControl,
                kinds: allowed,
                documentExtensions: extensions,
                progress: progress
            )
        }.value
    }

    private func scanFolderWhileAccessActive(
        at root: URL,
        sourceLabel: String,
        includeSubfolders: Bool,
        includedSubfolderPaths: [String]?,
        runControl: IndexingRunControl?,
        kinds: Set<MediaKind>,
        documentExtensions: Set<String>,
        progress: (@Sendable @MainActor (Int, String) -> Void)?
    ) async throws -> [DiscoveredMedia] {
        if !includeSubfolders {
            return try await scanFolderRootOnly(
                at: root,
                sourceLabel: sourceLabel,
                runControl: runControl,
                kinds: kinds,
                documentExtensions: documentExtensions,
                progress: progress
            )
        }
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .creationDateKey,
            .fileSizeKey,
            .contentTypeKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [DiscoveredMedia] = []
        var filesSeen = 0

        while let element = enumerator.nextObject() {
            try Task.checkCancellation()
            if let runControl {
                try await runControl.checkpoint()
                guard await runControl.shouldContinueScan() else { break }
            }

            guard let fileURL = element as? URL else { continue }
            if Self.excludedTree(fileURL, enumerator: enumerator, policy: exclusionPolicy) {
                continue
            }
            guard Self.shouldInclude(
                fileURL: fileURL,
                root: root,
                includedSubfolderPaths: includedSubfolderPaths
            ) else { continue }

            let values = try? fileURL.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            guard let kind = mediaKind(for: values?.contentType, url: fileURL, documentExtensions: documentExtensions),
                  kinds.contains(kind) else { continue }
            if exclusionPolicy.isBlockedSource(fileURL) != nil { continue }

            filesSeen += 1
            if filesSeen == 1 || filesSeen % 20 == 0 {
                let count = filesSeen
                let name = fileURL.lastPathComponent
                if let progress {
                    await MainActor.run { progress(count, name) }
                }
            }

            let modDate = values?.contentModificationDate
            let created = values?.creationDate
            let hash = contentHash(path: fileURL.path, modified: modDate)

            results.append(DiscoveredMedia(
                id: stableID(for: fileURL),
                url: fileURL,
                kind: kind,
                sourceKind: .folder,
                sourceLabel: sourceLabel,
                fileSize: values?.fileSize.map { Int64($0) },
                contentHash: hash,
                createdAt: created,
                modifiedAt: modDate
            ))
        }

        if let progress {
            let total = results.count
            await MainActor.run { progress(total, root.lastPathComponent) }
        }
        return results
    }

    private func scanFolderRootOnly(
        at root: URL,
        sourceLabel: String,
        runControl: IndexingRunControl?,
        kinds: Set<MediaKind>,
        documentExtensions: Set<String>,
        progress: (@Sendable @MainActor (Int, String) -> Void)?
    ) async throws -> [DiscoveredMedia] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .creationDateKey,
            .fileSizeKey,
            .contentTypeKey,
        ]
        let urls = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )
        var results: [DiscoveredMedia] = []
        var filesSeen = 0
        for fileURL in urls {
            try Task.checkCancellation()
            if let runControl {
                try await runControl.checkpoint()
                guard await runControl.shouldContinueScan() else { break }
            }
            let values = try? fileURL.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            guard let kind = mediaKind(for: values?.contentType, url: fileURL, documentExtensions: documentExtensions),
                  kinds.contains(kind) else { continue }
            if exclusionPolicy.isBlockedSource(fileURL) != nil { continue }
            filesSeen += 1
            if filesSeen == 1 || filesSeen % 20 == 0, let progress {
                let count = filesSeen
                let name = fileURL.lastPathComponent
                await MainActor.run { progress(count, name) }
            }
            let modDate = values?.contentModificationDate
            results.append(DiscoveredMedia(
                id: stableID(for: fileURL),
                url: fileURL,
                kind: kind,
                sourceKind: .folder,
                sourceLabel: sourceLabel,
                fileSize: values?.fileSize.map { Int64($0) },
                contentHash: contentHash(path: fileURL.path, modified: modDate),
                createdAt: values?.creationDate,
                modifiedAt: modDate
            ))
        }
        if let progress {
            let total = results.count
            await MainActor.run { progress(total, root.lastPathComponent) }
        }
        return results
    }

    public func scanFolder(at root: URL, sourceLabel: String, includeSubfolders: Bool = true) throws -> [DiscoveredMedia] {
        if !includeSubfolders {
            return try scanFolderRootOnlySync(at: root, sourceLabel: sourceLabel)
        }
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .creationDateKey,
            .fileSizeKey,
            .contentTypeKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [DiscoveredMedia] = []
        while let element = enumerator.nextObject() {
            guard let fileURL = element as? URL else { continue }
            if Self.excludedTree(fileURL, enumerator: enumerator, policy: exclusionPolicy) {
                continue
            }
            let values = try? fileURL.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            guard let kind = mediaKind(for: values?.contentType, url: fileURL) else { continue }
            if exclusionPolicy.isBlockedSource(fileURL) != nil { continue }
            let modDate = values?.contentModificationDate
            results.append(DiscoveredMedia(
                id: stableID(for: fileURL),
                url: fileURL,
                kind: kind,
                sourceKind: .folder,
                sourceLabel: sourceLabel,
                fileSize: values?.fileSize.map { Int64($0) },
                contentHash: contentHash(path: fileURL.path, modified: modDate),
                createdAt: values?.creationDate,
                modifiedAt: modDate
            ))
        }
        return results
    }

    private func scanFolderRootOnlySync(at root: URL, sourceLabel: String) throws -> [DiscoveredMedia] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .creationDateKey,
            .fileSizeKey,
            .contentTypeKey,
        ]
        let urls = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )
        var results: [DiscoveredMedia] = []
        for fileURL in urls {
            let values = try? fileURL.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            guard let kind = mediaKind(for: values?.contentType, url: fileURL) else { continue }
            if exclusionPolicy.isBlockedSource(fileURL) != nil { continue }
            let modDate = values?.contentModificationDate
            results.append(DiscoveredMedia(
                id: stableID(for: fileURL),
                url: fileURL,
                kind: kind,
                sourceKind: .folder,
                sourceLabel: sourceLabel,
                fileSize: values?.fileSize.map { Int64($0) },
                contentHash: contentHash(path: fileURL.path, modified: modDate),
                createdAt: values?.creationDate,
                modifiedAt: modDate
            ))
        }
        return results
    }

    /// One file, no directory walk. Used when a watched folder reports a change.
    public func classifyFile(
        at fileURL: URL,
        sourceLabel: String,
        kinds: Set<MediaKind> = Set(MediaKind.allCases),
        documentExtensions: Set<String> = DocumentFormats.extensions
    ) -> DiscoveredMedia? {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else {
            return nil
        }
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .contentModificationDateKey, .creationDateKey, .fileSizeKey, .contentTypeKey,
        ]
        let values = try? fileURL.resourceValues(forKeys: keys)
        guard values?.isRegularFile != false else { return nil }
        let allowed = kinds.isEmpty ? Set(MediaKind.allCases) : kinds
        let extensions = documentExtensions.isEmpty ? DocumentFormats.extensions : documentExtensions
        guard let kind = mediaKind(for: values?.contentType, url: fileURL, documentExtensions: extensions),
              allowed.contains(kind) else { return nil }
        if exclusionPolicy.isBlockedSource(fileURL) != nil { return nil }
        let modDate = values?.contentModificationDate
        return DiscoveredMedia(
            id: stableID(for: fileURL),
            url: fileURL,
            kind: kind,
            sourceKind: .folder,
            sourceLabel: sourceLabel,
            fileSize: values?.fileSize.map { Int64($0) },
            contentHash: contentHash(path: fileURL.path, modified: modDate),
            createdAt: values?.creationDate,
            modifiedAt: modDate
        )
    }

    private func mediaKind(for contentType: UTType?, url: URL, documentExtensions: Set<String> = DocumentFormats.extensions) -> MediaKind? {
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
        if DocumentFormats.isDocument(url: url, allowed: documentExtensions) { return .document }
        return nil
    }

    private static func excludedTree(
        _ url: URL,
        enumerator: FileManager.DirectoryEnumerator,
        policy: ScanExclusionPolicy
    ) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        guard policy.skipReason(forDirectory: url) != nil else { return false }
        enumerator.skipDescendants()
        ScanStats.shared.recordSkippedTree()
        return true
    }

    private func stableID(for url: URL) -> String {
        "file:" + url.path
    }

    private func contentHash(path: String, modified: Date?) -> String {
        let mod = modified.map { String($0.timeIntervalSince1970) } ?? "0"
        return "\(path)|\(mod)"
    }

    static func relativeDirectoryPath(fileURL: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return "" }
        var remainder = String(filePath.dropFirst(rootPath.count))
        if remainder.hasPrefix("/") { remainder.removeFirst() }
        if remainder.isEmpty { return "" }
        return (remainder as NSString).deletingLastPathComponent
    }

    static func shouldInclude(fileURL: URL, root: URL, includedSubfolderPaths: [String]?) -> Bool {
        guard let includedSubfolderPaths else { return true }
        if includedSubfolderPaths.isEmpty { return false }
        let dir = relativeDirectoryPath(fileURL: fileURL, root: root)
        if dir.isEmpty {
            return includedSubfolderPaths.contains("")
        }
        return includedSubfolderPaths.contains { selected in
            dir == selected || dir.hasPrefix(selected + "/")
        }
    }
}
