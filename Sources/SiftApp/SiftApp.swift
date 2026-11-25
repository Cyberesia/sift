import SiftCore
import SiftDesign
import SwiftUI

#if os(macOS)
import AppKit
#endif

#if os(macOS)
@main
struct SiftApplication: App {
    @NSApplicationDelegateAdaptor(SiftAppDelegate.self) private var appDelegate
    @StateObject private var session = SiftRootSession()

    var body: some Scene {
        WindowGroup {
            PrismShellView(session: session)
                .prismAppearance()
        }
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(tr("Settings…", "Réglages…")) { session.openSettings() }
                    .keyboardShortcut(",", modifiers: .command)
                Button(tr("Run Setup…", "Configuration…")) { session.openSetup() }
            }
            CommandGroup(after: .newItem) {
                Button("Add Folder…") {
                    Task { await session.addFolder() }
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Index Photos Library") {
                    Task { await session.enablePhotosLibrary() }
                }

                Button("Rescan All Saved Folders") {
                    session.rescanAllFolderSources()
                }

                Divider()

                Button("Command Orb") {
                    NotificationCenter.default.post(name: .siftToggleCommandOrb, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        MenuBarExtra("Sift", systemImage: "sparkles.rectangle.stack") {
            MenuBarStatusView(session: session)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var session: SiftRootSession
    @ObservedObject private var bookmarks: BookmarkStore
    @ObservedObject private var destinations: DestinationStore
    @State private var recentTransfers: [TransferRecord] = []

    init(session: SiftRootSession) {
        self.session = session
        _bookmarks = ObservedObject(wrappedValue: session.bookmarkStore)
        _destinations = ObservedObject(wrappedValue: session.destinationStore)
    }

    var body: some View {
        PrismSettingsView(
            folders: bookmarks.folders,
            destinations: destinations.destinations,
            activeDestinationID: destinations.activeDestinationID,
            transferMode: transferModeBinding,
            watchSourceFolders: watchSourceFoldersBinding,
            recentTransfers: recentTransfers,
            onAddFolder: { Task { await session.addFolder() } },
            onRemoveFolder: { session.removeFolderSource(id: $0) },
            onScanFolder: session.rescanFolderSource,
            onSetIncludeSubfolders: session.setFolderIncludesSubfolders,
            onRescanSources: session.rescanAllFolderSources,
            onStartAITagging: session.startBackgroundAnalysis,
            onUndoTransfer: { record in
                Task {
                    await session.undoTransfer(record)
                    refreshTransfers()
                }
            },
            onFactoryReset: { library, settings in
                session.performFactoryReset(library: library, settings: settings)
                refreshTransfers()
            },
            intelligence: session.intelligence,
            initialPage: session.settingsPage,
            onClose: { session.showSettings = false },
            onRunSetup: { session.openSetup() }
        )
        .onAppear(perform: refreshTransfers)
    }

    private func refreshTransfers() {
        recentTransfers = (try? session.transferJournal.recent()) ?? []
    }

    private var watchSourceFoldersBinding: Binding<Bool> {
        Binding(
            get: { session.watchSourceFolders },
            set: { session.watchSourceFolders = $0 }
        )
    }

    private var transferModeBinding: Binding<FileTransferMode> {
        Binding(
            get: { session.fileTransferMode },
            set: { session.fileTransferMode = $0 }
        )
    }
}
#endif // os(macOS)
