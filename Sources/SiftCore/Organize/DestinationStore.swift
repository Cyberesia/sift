import Foundation

#if os(macOS)
import AppKit
#endif

public enum DestinationStoreError: Error, LocalizedError {
    case bookmarkCreationFailed
    case accessDenied
    case staleBookmark

    public var errorDescription: String? {
        switch self {
        case .bookmarkCreationFailed: "Could not create security-scoped bookmark."
        case .accessDenied: "Destination folder access was denied."
        case .staleBookmark: "Destination bookmark is no longer valid."
        }
    }
}

@MainActor
public final class DestinationStore: ObservableObject {
    private let destinationsKey = "sift.destinationBookmarks"
    private let activeIDKey = "sift.activeDestinationID"
    private let legacyURLKey = "sift.legacyDestinationPath"

    @Published public private(set) var destinations: [DestinationBookmark] = []
    @Published public private(set) var activeDestinationID: String?

    public init() {
        load()
        migrateLegacyDestinationIfNeeded()
    }

    public func destination(id: String) -> DestinationBookmark? {
        destinations.first { $0.id == id }
    }

    public var activeDestination: DestinationBookmark? {
        guard let activeDestinationID else { return nil }
        return destination(id: activeDestinationID)
    }

    @discardableResult
    public func add(url: URL) throws -> DestinationBookmark {
        #if os(macOS)
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started { url.stopAccessingSecurityScopedResource() }
        }
        #endif

        let normalizedPath = url.standardizedFileURL.path

        if let index = destinations.firstIndex(where: { dest in
            (try? resolve(dest).standardizedFileURL.path) == normalizedPath
        }) {
            let existing = destinations[index]
            setActive(id: existing.id)
            return existing
        }

        let data: Data
        do {
            #if os(macOS)
            data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #else
            data = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #endif
        } catch {
            throw DestinationStoreError.bookmarkCreationFailed
        }

        let bookmark = DestinationBookmark(
            displayName: url.lastPathComponent,
            bookmarkData: data
        )
        destinations.append(bookmark)
        if activeDestinationID == nil {
            activeDestinationID = bookmark.id
        }
        persist()
        return bookmark
    }

    public func remove(id: String) {
        destinations.removeAll { $0.id == id }
        if activeDestinationID == id {
            activeDestinationID = destinations.first?.id
        }
        persist()
    }

    public func removeAll() {
        destinations = []
        activeDestinationID = nil
        UserDefaults.standard.removeObject(forKey: destinationsKey)
        UserDefaults.standard.removeObject(forKey: activeIDKey)
    }

    public func setActive(id: String) {
        guard destinations.contains(where: { $0.id == id }) else { return }
        activeDestinationID = id
        UserDefaults.standard.set(id, forKey: activeIDKey)
    }

    public func resolve(_ bookmark: DestinationBookmark) throws -> URL {
        var isStale = false
        let url: URL
        do {
            #if os(macOS)
            url = try URL(
                resolvingBookmarkData: bookmark.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            #else
            url = try URL(
                resolvingBookmarkData: bookmark.bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            #endif
        } catch {
            throw DestinationStoreError.staleBookmark
        }
        if isStale {
            throw DestinationStoreError.staleBookmark
        }
        return url
    }

    public func resolveActiveURL() throws -> URL? {
        guard let active = activeDestination else { return nil }
        return try resolvedDirectory(for: active)
    }

    /// The folder the user named. If the bookmark resolves to the parent, and a child with the saved name exists, that child is used.
    public func resolvedDirectory(for bookmark: DestinationBookmark) throws -> URL {
        let bookmarked = try resolve(bookmark)
        #if os(macOS)
        let started = bookmarked.startAccessingSecurityScopedResource()
        defer {
            if started { bookmarked.stopAccessingSecurityScopedResource() }
        }
        #endif
        return Self.preferredDirectory(bookmarked, named: bookmark.displayName)
    }

    nonisolated public static func preferredDirectory(_ url: URL, named displayName: String) -> URL {
        let standardized = url.standardizedFileURL
        if isDirectory(standardized), sameName(standardized.lastPathComponent, displayName) {
            return standardized
        }
        let child = standardized.appendingPathComponent(displayName, isDirectory: true)
        if isDirectory(child) {
            return child.standardizedFileURL
        }
        return standardized
    }

    nonisolated private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    nonisolated private static func sameName(_ lhs: String, _ rhs: String) -> Bool {
        lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }

    public func withSecurityScopedAccess<T>(
        _ bookmark: DestinationBookmark,
        _ body: (URL) throws -> T
    ) throws -> T {
        let bookmarked = try resolve(bookmark)
        #if os(macOS)
        let started = bookmarked.startAccessingSecurityScopedResource()
        defer {
            if started { bookmarked.stopAccessingSecurityScopedResource() }
        }
        guard started else { throw DestinationStoreError.accessDenied }
        #endif
        let directory = Self.preferredDirectory(bookmarked, named: bookmark.displayName)
        return try body(directory)
    }

    public func withSecurityScopedAccessAsync<T: Sendable>(
        _ bookmark: DestinationBookmark,
        _ operation: @MainActor @Sendable (URL) async throws -> T
    ) async throws -> T {
        let bookmarked = try resolve(bookmark)
        #if os(macOS)
        let started = bookmarked.startAccessingSecurityScopedResource()
        defer {
            if started { bookmarked.stopAccessingSecurityScopedResource() }
        }
        guard started else { throw DestinationStoreError.accessDenied }
        #endif
        let directory = Self.preferredDirectory(bookmarked, named: bookmark.displayName)
        return try await operation(directory)
    }

    #if os(macOS)
    @MainActor
    public static func pickFolder() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose the folder files should go inside. Sift will not put them in the folder above it."
        panel.prompt = "Use this folder"
        let response = await panel.begin()
        guard response == .OK, let url = panel.url else { return nil }
        return url
    }
    #endif

    private func load() {
        if let data = UserDefaults.standard.data(forKey: destinationsKey),
           let decoded = try? JSONDecoder().decode([DestinationBookmark].self, from: data) {
            destinations = decoded
        }
        activeDestinationID = UserDefaults.standard.string(forKey: activeIDKey)
        if let activeDestinationID,
           !destinations.contains(where: { $0.id == activeDestinationID }) {
            self.activeDestinationID = destinations.first?.id
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(destinations) {
            UserDefaults.standard.set(data, forKey: destinationsKey)
        }
        if let activeDestinationID {
            UserDefaults.standard.set(activeDestinationID, forKey: activeIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeIDKey)
        }
    }

    private func migrateLegacyDestinationIfNeeded() {
        guard destinations.isEmpty,
              let path = UserDefaults.standard.string(forKey: legacyURLKey) else { return }
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            _ = try? add(url: url)
        }
        UserDefaults.standard.removeObject(forKey: legacyURLKey)
    }

    /// Stores a resolved path for one-time migration from older builds that only kept URL in memory.
    public static func recordLegacyDestinationPath(_ path: String) {
        UserDefaults.standard.set(path, forKey: "sift.legacyDestinationPath")
    }
}
