import Foundation

/// Where Sift keeps its state. A demo run (`-siftDemo YES` or `SIFT_DEMO=1`) gets its own settings,
/// catalog, thumbnails and rules, so a screen recording never shows the person's real files
/// and never changes their real setup.
public enum SiftRuntime {
    public static let isDemo: Bool = {
        let info = ProcessInfo.processInfo
        if info.environment["SIFT_DEMO"] == "1" { return true }
        if let index = info.arguments.firstIndex(of: "-siftDemo"), index + 1 < info.arguments.count {
            return ["yes", "1", "true"].contains(info.arguments[index + 1].lowercased())
        }
        return false
    }()

    /// Use this instead of `UserDefaults.standard` everywhere in Sift.
    public nonisolated(unsafe) static let defaults: UserDefaults = isDemo
        ? (UserDefaults(suiteName: "ai.cyclones.sift.demo") ?? .standard)
        : .standard

    /// `~/Library/Application Support/Sift` (or `SiftDemo`).
    public static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(isDemo ? "SiftDemo" : "Sift", isDirectory: true)
    }

    /// The SwiftData store name.
    public static var catalogStoreName: String { isDemo ? "SiftDemoIndex-v4" : "SiftIndex-v4" }
}
