import Foundation

#if os(macOS)
import CoreServices

/// Watches source folder bookmarks and triggers incremental rescans.
@MainActor
public final class SourceFolderWatcher {
    public var onFoldersChanged: (([FolderBookmark], [String]) -> Void)?

    private let bookmarkStore: BookmarkStore
    private var stream: FSEventStreamRef?
    private var debounceTask: Task<Void, Never>?
    private var pathToBookmarkID: [String: String] = [:]
    private var suppressUntil = Date.distantPast
    private let debounceNanoseconds: UInt64 = 1_500_000_000
    /// Launch attaches the stream and macOS reports the folders it just opened. Those are not new files.

    public init(bookmarkStore: BookmarkStore) {
        self.bookmarkStore = bookmarkStore
    }

    public func start() {
        stop()
        rebuildPathMap()
        let paths = Array(pathToBookmarkID.keys)
        guard !paths.isEmpty else { return }

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
        )
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        stream = FSEventStreamCreate(
            nil,
            { _, info, _, paths, _, _ in
                guard let info else { return }
                let watcher = Unmanaged<SourceFolderWatcher>.fromOpaque(info).takeUnretainedValue()
                let pathList = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
                Task { @MainActor in
                    watcher.handleEvents(paths: pathList)
                }
            },
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            flags
        )

        guard let stream else { return }
        suppressUntil = Date().addingTimeInterval(12)
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    public func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
    }

    public func refreshBookmarkPaths() {
        let wasRunning = stream != nil
        if wasRunning {
            start()
        } else {
            rebuildPathMap()
        }
    }

    private func rebuildPathMap() {
        pathToBookmarkID = [:]
        for bookmark in bookmarkStore.folders {
            guard let url = try? bookmarkStore.resolve(bookmark) else { continue }
            pathToBookmarkID[url.standardizedFileURL.path] = bookmark.id
        }
    }

    private func handleEvents(paths eventPaths: [String]) {
        guard Date() >= suppressUntil else { return }
        guard !eventPaths.isEmpty else { return }
        let meaningful = eventPaths.contains { path in
            let name = (path as NSString).lastPathComponent
            if name.hasPrefix(".") { return false }
            if name == ".DS_Store" { return false }
            return true
        }
        guard meaningful else { return }

        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.debounceNanoseconds ?? 1_500_000_000)
            guard let self, !Task.isCancelled else { return }
            self.fireChangedBookmarks(for: eventPaths)
        }
    }

    private func fireChangedBookmarks(for eventPaths: [String]) {
        rebuildPathMap()
        var bookmarkIDs = Set<String>()
        for path in eventPaths {
            let std = URL(fileURLWithPath: path).standardizedFileURL.path
            if let id = pathToBookmarkID[std] {
                bookmarkIDs.insert(id)
                continue
            }
            for (root, id) in pathToBookmarkID where std.hasPrefix(root + "/") || std == root {
                bookmarkIDs.insert(id)
            }
        }
        guard !bookmarkIDs.isEmpty else { return }
        let bookmarks = bookmarkStore.folders.filter { bookmarkIDs.contains($0.id) }
        guard !bookmarks.isEmpty else { return }
        onFoldersChanged?(bookmarks, eventPaths)
    }
}
#endif
