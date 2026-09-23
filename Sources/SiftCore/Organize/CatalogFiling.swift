import Foundation

public struct CatalogFile: Sendable, Equatable {
    public let id: String
    public let path: String
    public let contentHash: String

    public init(id: String, path: String, contentHash: String) {
        self.id = id
        self.path = path
        self.contentHash = contentHash
    }
}

public struct CatalogTransfer: Sendable, Equatable {
    public let sourcePath: String
    public let destinationPath: String

    public init(sourcePath: String, destinationPath: String) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
    }
}

public struct CatalogFilingSummary: Sendable, Equatable {
    public var inDestination: Int
    public var stillAtOrigin: Int
    public var filedOutside: Int
    public var untouched: Int
    public var inDestinationPaths: Set<String>
    public var originPaths: Set<String>
    public var outsidePaths: Set<String>

    public init(
        inDestination: Int = 0,
        stillAtOrigin: Int = 0,
        filedOutside: Int = 0,
        untouched: Int = 0,
        inDestinationPaths: Set<String> = [],
        originPaths: Set<String> = [],
        outsidePaths: Set<String> = []
    ) {
        self.inDestination = inDestination
        self.stillAtOrigin = stillAtOrigin
        self.filedOutside = filedOutside
        self.untouched = untouched
        self.inDestinationPaths = inDestinationPaths
        self.originPaths = originPaths
        self.outsidePaths = outsidePaths
    }

    public static let empty = CatalogFilingSummary()

    public var hasSplit: Bool {
        inDestination > 0 || stillAtOrigin > 0 || filedOutside > 0
    }

    public func line(folderName: String) -> String {
        guard hasSplit else { return "" }
        let name = folderName.isEmpty ? "your folder" : folderName
        if filedOutside > 0 {
            return "\(filedOutside) files were placed next to “\(name)”, not inside it. \(stillAtOrigin) are still in the original folders."
        }
        var parts = ["\(inDestination) already inside “\(name)”", "\(stillAtOrigin) still in the original folders"]
        if untouched > 0 {
            parts.append("\(untouched) not filed yet")
        }
        return parts.joined(separator: " · ")
    }
}

public enum CatalogFilingClassifier {
    public static func summarize(
        files: [CatalogFile],
        destinationRoots: [String],
        transfers: [CatalogTransfer]
    ) -> CatalogFilingSummary {
        let roots = destinationRoots.map(normalize).filter { !$0.isEmpty }
        let filedDestinations = Set(transfers.map { normalize($0.destinationPath) })
        let filedSources = Set(transfers.map { normalize($0.sourcePath) })

        var filedHashes = Set<String>()
        for file in files {
            let path = normalize(file.path)
            let hash = file.contentHash
            guard !hash.isEmpty else { continue }
            if isInside(path, roots: roots) || filedDestinations.contains(path) {
                filedHashes.insert(hash)
            }
        }

        var inDestinationPaths = Set<String>()
        var originPaths = Set<String>()
        var outsidePaths = Set<String>()
        var untouched = 0

        for file in files {
            let path = normalize(file.path)
            if isInside(path, roots: roots) {
                inDestinationPaths.insert(path)
            } else if filedDestinations.contains(path) {
                outsidePaths.insert(path)
            } else if filedSources.contains(path) || (!file.contentHash.isEmpty && filedHashes.contains(file.contentHash)) {
                originPaths.insert(path)
            } else {
                untouched += 1
            }
        }

        return CatalogFilingSummary(
            inDestination: inDestinationPaths.count,
            stillAtOrigin: originPaths.count,
            filedOutside: outsidePaths.count,
            untouched: untouched,
            inDestinationPaths: inDestinationPaths,
            originPaths: originPaths,
            outsidePaths: outsidePaths
        )
    }

    public static func normalize(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func isInside(_ path: String, roots: [String]) -> Bool {
        for root in roots {
            if path == root { return true }
            let prefix = root.hasSuffix("/") ? root : root + "/"
            if path.hasPrefix(prefix) { return true }
        }
        return false
    }
}

public enum ScanActivityCopy {
    public static func lookingFor(_ kinds: Set<MediaKind>) -> String {
        let names = MediaKind.allCases.filter { kinds.contains($0) }.map(noun)
        switch names.count {
        case 0: return "Looking through the selected folders…"
        case 1: return "Looking for \(names[0])…"
        case 2: return "Looking for \(names[0]) and \(names[1])…"
        default:
            let head = names.dropLast().joined(separator: ", ")
            return "Looking for \(head), and \(names[names.count - 1])…"
        }
    }

    private static func noun(_ kind: MediaKind) -> String {
        switch kind {
        case .image: "photos"
        case .video: "videos"
        case .audio: "audio"
        case .document: "documents"
        }
    }
}
