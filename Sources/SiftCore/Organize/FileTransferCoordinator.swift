import Foundation

public enum FileTransferError: Error, LocalizedError {
    case sourceMissing
    case destinationUnavailable
    case transferFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sourceMissing: "Source file no longer exists."
        case .destinationUnavailable: "Destination folder is not accessible."
        case .transferFailed(let msg): msg
        }
    }
}

public actor FileTransferCoordinator {
    public static let suggestedCatalogFolders = [
        "Photos",
        "Videos",
        "Music & Audio",
        "Screenshots & Documents",
        "Review",
        "Duplicates",
    ]

    public init() {}

    public func ensureLayout(at destination: URL) throws {
        let fm = FileManager.default
        for bucket in StagingBucket.allCases {
            let dir = destination.appendingPathComponent(bucket.folderName, isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    public func ensureSuggestedCatalogLayout(at destination: URL, folders: [String]? = nil) throws {
        let names = folders ?? Self.suggestedCatalogFolders
        for name in names {
            let dir = try directory(in: destination, folderName: name)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// A folder name that cannot climb out of the destination.
    public static func sanitizedFolderName(_ name: String) throws -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: " & ")
            .replacingOccurrences(of: ":", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty || cleaned == "." || cleaned == ".." || cleaned.contains("..") {
            throw FileTransferError.destinationUnavailable
        }
        return cleaned
    }

    private func directory(in destinationRoot: URL, folderName: String) throws -> URL {
        let folder = try Self.sanitizedFolderName(folderName)
        let root = destinationRoot.standardizedFileURL
        let destDir = root.appendingPathComponent(folder, isDirectory: true).standardizedFileURL
        let rootPath = root.path
        let destPath = destDir.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard destPath == rootPath || destPath.hasPrefix(prefix) else {
            throw FileTransferError.destinationUnavailable
        }
        return destDir
    }

    public func transfer(
        from source: URL,
        to destinationRoot: URL,
        bucket: StagingBucket,
        mode: FileTransferMode
    ) throws -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { throw FileTransferError.sourceMissing }

        let destDir = try directory(in: destinationRoot, folderName: bucket.folderName)
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        var target = destDir.appendingPathComponent(source.lastPathComponent)
        if fm.fileExists(atPath: target.path) {
            let base = source.deletingPathExtension().lastPathComponent
            let ext = source.pathExtension
            let stamp = Int(Date().timeIntervalSince1970)
            let name = ext.isEmpty ? "\(base)-\(stamp)" : "\(base)-\(stamp).\(ext)"
            target = destDir.appendingPathComponent(name)
        }

        switch mode {
        case .move:
            try fm.moveItem(at: source, to: target)
        case .copy, .copyThenConfirmDelete:
            try fm.copyItem(at: source, to: target)
        }
        return target
    }

    public func transfer(
        from source: URL,
        to destinationRoot: URL,
        folderName: String,
        mode: FileTransferMode
    ) throws -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { throw FileTransferError.sourceMissing }
        let destDir = try directory(in: destinationRoot, folderName: folderName)
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        var target = destDir.appendingPathComponent(source.lastPathComponent)
        if fm.fileExists(atPath: target.path) {
            let base = source.deletingPathExtension().lastPathComponent
            let ext = source.pathExtension
            let stamp = Int(Date().timeIntervalSince1970)
            target = destDir.appendingPathComponent(
                ext.isEmpty ? "\(base)-\(stamp)" : "\(base)-\(stamp).\(ext)"
            )
        }
        switch mode {
        case .move:
            try fm.moveItem(at: source, to: target)
        case .copy, .copyThenConfirmDelete:
            try fm.copyItem(at: source, to: target)
        }
        return target
    }

    public struct BatchTransferResult: Sendable {
        public var succeeded: [URL]
        public var failures: [(URL, String)]

        public init(succeeded: [URL] = [], failures: [(URL, String)] = []) {
            self.succeeded = succeeded
            self.failures = failures
        }
    }

    public func transferBatch(
        sources: [URL],
        to destinationRoot: URL,
        bucket: StagingBucket,
        mode: FileTransferMode
    ) async -> BatchTransferResult {
        var succeeded: [URL] = []
        var failures: [(URL, String)] = []
        for source in sources {
            do {
                let url = try transfer(from: source, to: destinationRoot, bucket: bucket, mode: mode)
                succeeded.append(url)
            } catch {
                failures.append((source, error.localizedDescription))
            }
        }
        return BatchTransferResult(succeeded: succeeded, failures: failures)
    }
}
