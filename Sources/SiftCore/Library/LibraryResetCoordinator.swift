import Foundation

@MainActor
public enum LibraryResetCoordinator {
    public static func resetAll(
        indexStore: MediaIndexStore,
        bookmarkStore: BookmarkStore,
        destinationStore: DestinationStore
    ) throws {
        try indexStore.wipeCatalog()
        bookmarkStore.removeAll()
        destinationStore.removeAll()
        let keys = [
            "sift.folderBookmarks",
            "sift.destinationBookmarks",
            "sift.activeDestinationID",
            "sift.dismissedCollectionIDs",
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let thumbs = support?.appendingPathComponent("Sift/thumbnails", isDirectory: true) {
            try? FileManager.default.removeItem(at: thumbs)
        }
    }
}
