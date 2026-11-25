import Foundation
import UniformTypeIdentifiers

public struct MediaScanner: Sendable {
    public var exclusionPolicy: ScanExclusionPolicy

    public init(exclusionPolicy: ScanExclusionPolicy = .standard) {
        self.exclusionPolicy = exclusionPolicy
    }

    /// Files are sent to `onBatch` every `batchSize` entries, so memory stays flat however large the tree is.
    /// A batch holds metadata only (path, size, dates): about 1 KB per file, even for a 4 GB video.
    public static let defaultBatchSize = 500

    private static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .isDirectoryKey,
        .contentModificationDateKey,
        .creationDateKey,
        .fileSizeKey,
        .contentTypeKey,
    ]

    /// Walks a folder and streams what it finds. Returns the number of files sent.
    @discardableResult
    public func scanFolderStreaming(
        at root: URL,
        sourceLabel: String,
        includeSubfolders: Bool = true,
        includedSubfolderPaths: [String]? = nil,
        runControl: IndexingRunControl? = nil,
        kinds: Set<MediaKind> = Set(MediaKind.allCases),
        documentExtensions: Set<String> = DocumentFormats.extensions,
        batchSize: Int = MediaScanner.defaultBatchSize,
        priority: TaskPriority = ResourceGovernor.shared.scanPriority,
        progress: (@Sendable @MainActor (Int, String) -> Void)? = nil,
        onBatch: @escaping @Sendable ([DiscoveredMedia]) async throws -> Void
    ) async throws -> Int {
        let allowed = kinds.isEmpty ? Set(MediaKind.allCases) : kinds
        let extensions = documentExtensions.isEmpty ? DocumentFormats.extensions : documentExtensions
        let size = max(1, batchSize)
        return try await Task.detached(priority: priority) { [runControl] in
            try await self.walk(
                root: root,
                sourceLabel: sourceLabel,
                includeSubfolders: includeSubfolders,
                includedSubfolderPaths: includedSubfolderPaths,
                runControl: runControl,
                kinds: allowed,
                documentExtensions: extensions,
                batchSize: size,
                progress: progress,
                onBatch: onBatch
            )
        }.value
    }

    /// Collects every file in memory. Fine for a folder; use `scanFolderStreaming` for a whole disk.
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
        let collector = BatchCollector()
        try await scanFolderStreaming(
            at: root,
            sourceLabel: sourceLabel,
            includeSubfolders: includeSubfolders,
            includedSubfolderPaths: includedSubfolderPaths,
            runControl: runControl,
            kinds: kinds,
            documentExtensions: documentExtensions,
            progress: progress
        ) { batch in
            await collector.append(batch)
        }
        return await collector.items
    }

    public func scanFolder(at root: URL, sourceLabel: String, includeSubfolders: Bool = true) throws -> [DiscoveredMedia] {
        if exclusionPolicy.isBlockedSource(root) != nil { return [] }
        var results: [DiscoveredMedia] = []
        try forEachCandidate(root: root, includeSubfolders: includeSubfolders, includedSubfolderPaths: nil) { fileURL, values in
            if let media = makeMedia(fileURL, values: values, sourceLabel: sourceLabel, kinds: Set(MediaKind.allCases), documentExtensions: DocumentFormats.extensions) {
                results.append(media)
            }
            return true
        }
        return results
    }

    private func walk(
        root: URL,
        sourceLabel: String,
        includeSubfolders: Bool,
        includedSubfolderPaths: [String]?,
        runControl: IndexingRunControl?,
        kinds: Set<MediaKind>,
        documentExtensions: Set<String>,
        batchSize: Int,
        progress: (@Sendable @MainActor (Int, String) -> Void)?,
        onBatch: @Sendable ([DiscoveredMedia]) async throws -> Void
    ) async throws -> Int {
        // The folder itself is checked once. Excluded trees below it are skipped as the walk meets them,
        // so no file walks back up to "/" looking for a .git marker.
        if exclusionPolicy.isBlockedSource(root) != nil { return 0 }

        var batch: [DiscoveredMedia] = []
        batch.reserveCapacity(batchSize)
        var sent = 0
        var seen = 0
        var lastName = root.lastPathComponent

        let urls: AnySequence<URL>
        let enumerator: FileManager.DirectoryEnumerator?
        if includeSubfolders {
            enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: Array(Self.resourceKeys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            guard let enumerator else { return 0 }
            urls = AnySequence(enumerator.lazy.compactMap { $0 as? URL })
        } else {
            enumerator = nil
            urls = AnySequence(try FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: Array(Self.resourceKeys),
                options: [.skipsHiddenFiles]
            ))
        }

        for fileURL in urls {
            try Task.checkCancellation()
            if let runControl {
                try await runControl.checkpoint()
                guard await runControl.shouldContinueScan() else { break }
            }
            let values = try? fileURL.resourceValues(forKeys: Self.resourceKeys)
            if values?.isDirectory == true {
                if let enumerator, exclusionPolicy.skipReason(forDirectory: fileURL) != nil {
                    enumerator.skipDescendants()
                    ScanStats.shared.recordSkippedTree()
                }
                continue
            }
            if includeSubfolders,
               !Self.shouldInclude(fileURL: fileURL, root: root, includedSubfolderPaths: includedSubfolderPaths) {
                continue
            }
            guard let media = makeMedia(fileURL, values: values, sourceLabel: sourceLabel, kinds: kinds, documentExtensions: documentExtensions) else { continue }

            batch.append(media)
            seen += 1
            lastName = fileURL.lastPathComponent
            if let progress, seen == 1 || seen % 50 == 0 {
                let count = seen
                let name = lastName
                await MainActor.run { progress(count, name) }
            }
            if batch.count >= batchSize {
                try await onBatch(batch)
                sent += batch.count
                batch.removeAll(keepingCapacity: true)
            }
        }
        if !batch.isEmpty {
            try await onBatch(batch)
            sent += batch.count
        }
        if let progress {
            let total = sent
            let name = root.lastPathComponent
            await MainActor.run { progress(total, name) }
        }
        return sent
    }

    /// Synchronous walk used by the in-memory helper and tests.
    private func forEachCandidate(
        root: URL,
        includeSubfolders: Bool,
        includedSubfolderPaths: [String]?,
        _ body: (URL, URLResourceValues?) throws -> Bool
    ) throws {
        if includeSubfolders {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: Array(Self.resourceKeys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return }
            while let element = enumerator.nextObject() {
                guard let fileURL = element as? URL else { continue }
                let values = try? fileURL.resourceValues(forKeys: Self.resourceKeys)
                if values?.isDirectory == true {
                    if exclusionPolicy.skipReason(forDirectory: fileURL) != nil {
                        enumerator.skipDescendants()
                        ScanStats.shared.recordSkippedTree()
                    }
                    continue
                }
                guard Self.shouldInclude(fileURL: fileURL, root: root, includedSubfolderPaths: includedSubfolderPaths) else { continue }
                if try !body(fileURL, values) { return }
            }
        } else {
            let urls = try FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: Array(Self.resourceKeys),
                options: [.skipsHiddenFiles]
            )
            for fileURL in urls {
                if try !body(fileURL, try? fileURL.resourceValues(forKeys: Self.resourceKeys)) { return }
            }
        }
    }

    /// Metadata only. `lstat` tells a cloud placeholder apart without reading (and so downloading) it.
    private func makeMedia(
        _ fileURL: URL,
        values: URLResourceValues?,
        sourceLabel: String,
        kinds: Set<MediaKind>,
        documentExtensions: Set<String>
    ) -> DiscoveredMedia? {
        guard values?.isRegularFile == true else { return nil }
        guard let kind = mediaKind(for: values?.contentType, url: fileURL, documentExtensions: documentExtensions),
              kinds.contains(kind) else { return nil }
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
            modifiedAt: modDate,
            isCloudOnly: CloudFileState.isDataless(fileURL)
        )
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
            modifiedAt: modDate,
            isCloudOnly: CloudFileState.isDataless(fileURL)
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

private actor BatchCollector {
    private(set) var items: [DiscoveredMedia] = []
    func append(_ batch: [DiscoveredMedia]) { items.append(contentsOf: batch) }
}
