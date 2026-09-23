import Foundation

#if os(macOS)
import AppKit
#endif

public struct FolderBookmark: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let bookmarkData: Data
    public let includeSubfolders: Bool
    /// Relative subfolder paths to include; nil means all subfolders.
    public let includedSubfolderPaths: [String]?

    public init(
        id: String = UUID().uuidString,
        displayName: String,
        bookmarkData: Data,
        includeSubfolders: Bool = true,
        includedSubfolderPaths: [String]? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.includeSubfolders = includeSubfolders
        self.includedSubfolderPaths = includedSubfolderPaths
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, bookmarkData, includeSubfolders, includedSubfolderPaths
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        bookmarkData = try c.decode(Data.self, forKey: .bookmarkData)
        includeSubfolders = try c.decodeIfPresent(Bool.self, forKey: .includeSubfolders) ?? true
        includedSubfolderPaths = try c.decodeIfPresent([String].self, forKey: .includedSubfolderPaths)
    }
}

public enum BookmarkStoreError: Error, LocalizedError {
    case bookmarkCreationFailed
    case accessDenied
    case staleBookmark

    public var errorDescription: String? {
        switch self {
        case .bookmarkCreationFailed: "Could not create security-scoped bookmark."
        case .accessDenied: "Folder access was denied."
        case .staleBookmark: "Folder bookmark is no longer valid."
        }
    }
}

@MainActor
public final class BookmarkStore: ObservableObject {
    private let defaultsKey = "sift.folderBookmarks"

    @Published public private(set) var folders: [FolderBookmark] = []

    public init() {
        load()
    }

    public func allBookmarks() -> [FolderBookmark] {
        folders
    }

    @discardableResult
    public func add(
        url: URL,
        includeSubfolders: Bool = true,
        includedSubfolderPaths: [String]? = nil
    ) throws -> FolderBookmark {
        #if os(macOS)
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started { url.stopAccessingSecurityScopedResource() }
        }
        #endif

        let normalizedPath = url.standardizedFileURL.path

        if let index = folders.firstIndex(where: { bookmark in
            (try? resolve(bookmark).standardizedFileURL.path) == normalizedPath
        }) {
            let updated = FolderBookmark(
                id: folders[index].id,
                displayName: url.lastPathComponent,
                bookmarkData: folders[index].bookmarkData,
                includeSubfolders: includeSubfolders,
                includedSubfolderPaths: includedSubfolderPaths
            )
            folders[index] = updated
            persist()
            return updated
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
            throw BookmarkStoreError.bookmarkCreationFailed
        }

        let bookmark = FolderBookmark(
            displayName: url.lastPathComponent,
            bookmarkData: data,
            includeSubfolders: includeSubfolders,
            includedSubfolderPaths: includedSubfolderPaths
        )
        folders.append(bookmark)
        persist()
        return bookmark
    }

    public func bookmark(id: String) -> FolderBookmark? {
        folders.first { $0.id == id }
    }

    public func remove(id: String) {
        folders.removeAll { $0.id == id }
        persist()
    }

    public func removeAll() {
        folders = []
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    public func resolve(_ bookmark: FolderBookmark) throws -> URL {
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
            throw BookmarkStoreError.staleBookmark
        }
        if isStale {
            throw BookmarkStoreError.staleBookmark
        }
        return url
    }

    public func withSecurityScopedAccess<T>(
        _ bookmark: FolderBookmark,
        _ body: (URL) throws -> T
    ) throws -> T {
        let url = try resolve(bookmark)
        #if os(macOS)
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started { url.stopAccessingSecurityScopedResource() }
        }
        guard started else { throw BookmarkStoreError.accessDenied }
        #endif
        return try body(url)
    }

    public func withSecurityScopedAccessAsync<T: Sendable>(
        _ bookmark: FolderBookmark,
        _ operation: @MainActor @Sendable (URL) async throws -> T
    ) async throws -> T {
        let url = try resolve(bookmark)
        #if os(macOS)
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started { url.stopAccessingSecurityScopedResource() }
        }
        guard started else { throw BookmarkStoreError.accessDenied }
        #endif
        return try await operation(url)
    }

    #if os(macOS)
    @MainActor
    public static func pickFolder() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to collect photos and videos"
        let response = await panel.begin()
        guard response == .OK, let url = panel.url else { return nil }
        return url
    }

    @MainActor
    public static func pickFolders() async -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Choose folders or volumes to catalog. Nothing is moved."
        panel.prompt = "Choose"
        let response = await panel.begin()
        guard response == .OK else { return [] }
        return panel.urls
    }

    @MainActor
    public static func pickDestinationFolder(canCreate: Bool = true) async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = canCreate
        panel.message = "Choose where to organize your media"
        panel.prompt = "Choose"
        let response = await panel.begin()
        guard response == .OK, let url = panel.url else { return nil }
        return url
    }
    #endif

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([FolderBookmark].self, from: data) else { return }
        folders = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
