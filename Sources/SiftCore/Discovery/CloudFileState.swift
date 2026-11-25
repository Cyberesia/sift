import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// Tells a file that lives on this Mac from one that only has a placeholder here (iCloud Drive,
/// "Optimize Mac Storage", or another File Provider). Reading a placeholder makes macOS download it,
/// so Sift catalogs those from metadata alone and leaves their contents in the cloud.
public enum CloudFileState {
    /// `SF_DATALESS` from <sys/stat.h>: the file's data is not on disk.
    static let datalessFlag: UInt32 = 0x4000_0000

    /// One `lstat`. Does not touch the file's data and never starts a download.
    public static func isDataless(path: String) -> Bool {
        #if canImport(Darwin)
        var info = stat()
        guard lstat(path, &info) == 0 else { return false }
        return info.st_flags & datalessFlag != 0
        #else
        return false
        #endif
    }

    public static func isDataless(_ url: URL) -> Bool {
        isDataless(path: url.path)
    }
}

/// Process-wide switch that turns "read a cloud placeholder" into an error instead of a download.
/// It is the safety net under every reader Sift has (thumbnails, Vision, CLIP, documents, rules):
/// even a code path that forgets to check `CloudFileState` cannot pull 2 TB down from iCloud.
public enum CloudMaterializationPolicy {
    // From <sys/resource.h>. Spelled out so the build does not depend on the SDK exporting them to Swift.
    private static let typeMaterializeDatalessFiles: Int32 = 3 // IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES
    private static let scopeProcess: Int32 = 0 // IOPOL_SCOPE_PROCESS
    private static let materializeOff: Int32 = 1 // IOPOL_MATERIALIZE_DATALESS_FILES_OFF

    nonisolated(unsafe) private static var applied = false

    /// Call once at launch. Returns false if the kernel refused (older systems): the per-file checks still apply.
    @discardableResult
    public static func preventDownloads() -> Bool {
        #if os(macOS)
        let result = setiopolicy_np(typeMaterializeDatalessFiles, scopeProcess, materializeOff)
        applied = result == 0
        return applied
        #else
        return false
        #endif
    }

    public static var isPreventingDownloads: Bool { applied }

    /// A download the person asked for. The File Provider daemon fetches it; this process still never
    /// materializes a placeholder by reading it, so the policy above can stay on.
    public static func requestDownload(of url: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
    }
}
