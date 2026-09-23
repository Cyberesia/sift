#if os(macOS)
import AppKit
import SiftDesign

/// Keeps a SwiftPM-built GUI app alive and brings the window forward.
final class SiftAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Task { await SiftUpdateCenter.shared.checkIfNeeded() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
#endif
