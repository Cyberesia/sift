import Foundation

public enum ScanSkipReason: String, Sendable, Equatable {
    case developmentProject = "Development project"
    case dependencyTree = "Dependency or build tree"
    case systemLocation = "System location"
    case package = "App or package"
}

/// Shared rules for discovery. A matching directory is not descended into.
public struct ScanExclusionPolicy: Sendable {
    public static let standard = ScanExclusionPolicy()

    public static let dependencyNames: Set<String> = [
        "node_modules", ".git", ".build", "DerivedData", "Pods", "Carthage",
        "vendor", ".swiftpm", "xcuserdata", "__pycache__", ".gradle", ".next",
        "dist", "build", ".nuxt", "target", ".turbo", ".cache",
    ]

    public static let packageExtensions: Set<String> = ["app", "bundle", "framework", "photoslibrary"]

    public var allowDevelopmentProjects: Bool

    public init(allowDevelopmentProjects: Bool = false) {
        self.allowDevelopmentProjects = allowDevelopmentProjects
    }

    public func skipReason(forDirectory url: URL) -> ScanSkipReason? {
        let name = url.lastPathComponent
        if Self.packageExtensions.contains(url.pathExtension.lowercased()) {
            return .package
        }
        if Self.isSystemLocation(url) {
            return .systemLocation
        }
        if name == ".git" || Self.dependencyNames.contains(name) {
            return name == ".git" ? .developmentProject : .dependencyTree
        }
        if !allowDevelopmentProjects, Self.containsGitMarker(url) {
            return .developmentProject
        }
        return nil
    }

    public func isBlockedSource(_ url: URL) -> ScanSkipReason? {
        var current = url.standardizedFileURL
        if current.pathExtension.isEmpty == false, !current.hasDirectoryPath {
            current.deleteLastPathComponent()
        }
        while current.path != "/" && current.path != current.deletingLastPathComponent().path {
            if let reason = skipReason(forDirectory: current) {
                return reason
            }
            current.deleteLastPathComponent()
        }
        return nil
    }

    public static func isSystemLocation(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let prefixes = ["/System", "/Library", "/usr", "/bin", "/sbin", "/private", "/Applications", "/opt"]
        return prefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    private static func containsGitMarker(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path)
    }
}

public final class ScanStats: @unchecked Sendable {
    public static let shared = ScanStats()
    private let lock = NSLock()
    private var found = 0
    private var skippedTrees = 0

    public func reset() {
        lock.lock()
        found = 0
        skippedTrees = 0
        lock.unlock()
    }

    public func recordFound(_ count: Int = 1) {
        lock.lock()
        found += count
        lock.unlock()
    }

    public func recordSkippedTree() {
        lock.lock()
        skippedTrees += 1
        lock.unlock()
    }

    public func snapshot() -> (found: Int, skippedTrees: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (found, skippedTrees)
    }
}

public enum ScanSessionStore {
    private static let key = "sift.lastScanSession"

    public struct Record: Codable, Sendable {
        public var skippedTrees: Int
        public var updatedAt: Date
    }

    public static func save(skippedTrees: Int) {
        let record = Record(skippedTrees: skippedTrees, updatedAt: Date())
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    public static func load() -> Record? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }
}

public enum MacScanLocations {
    public static var standard: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Pictures", "Downloads", "Desktop", "Movies", "Music"].map {
            home.appendingPathComponent($0, isDirectory: true)
        }
    }
}

public enum FullDiskAccessProbe {
    public static func isGranted() -> Bool {
        let home = NSHomeDirectory()
        let candidates = [
            home + "/Library/Mail",
            home + "/Library/Messages",
            home + "/Library/Safari",
        ]
        return candidates.contains { FileManager.default.isReadableFile(atPath: $0) }
    }

    public static var settingsURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
    }
}
