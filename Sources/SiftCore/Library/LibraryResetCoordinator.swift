import Foundation

@MainActor
public enum LibraryResetCoordinator {
    /// Library clears the catalog. Settings forgets folders and choices. Neither deletes files on disk.
    public static func reset(
        library: Bool,
        settings: Bool,
        indexStore: MediaIndexStore,
        bookmarkStore: BookmarkStore,
        destinationStore: DestinationStore
    ) throws {
        guard library || settings else { return }
        if library {
            try indexStore.wipeCatalog()
            try? FileManager.default.removeItem(at: SiftRuntime.supportDirectory.appendingPathComponent("thumbnails", isDirectory: true))
        }
        if settings {
            bookmarkStore.removeAll()
            destinationStore.removeAll()
            let keys = [
                "sift.folderBookmarks",
                "sift.destinationBookmarks",
                "sift.activeDestinationID",
                "sift.legacyDestinationPath",
                "sift.dismissedCollectionIDs",
                "sift.fileTransferMode",
                "sift.fileTransferModeChosen",
                "sift.scan.kinds",
                "sift.scan.documentExtensions",
                "sift.watchSourceFolders",
                "sift.lastScanSession",
                "sift.organizeRules",
                "sift.autoApplyOrganizeRules",
                "sift.skipAITaggingPrompt",
            ]
            for key in keys {
                SiftRuntime.defaults.removeObject(forKey: key)
            }
        }
    }
}
