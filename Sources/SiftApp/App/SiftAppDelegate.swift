#if os(macOS)
import AppKit
import SiftCore
import SiftDesign

/// Keeps a SwiftPM-built GUI app alive and brings the window forward.
final class SiftAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Never download an iCloud placeholder by reading it. Scans catalog those from metadata only.
        CloudMaterializationPolicy.preventDownloads()
        observeForegroundState()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Task { await SiftUpdateCenter.shared.checkIfNeeded() }
    }

    /// Full speed while the person looks at Sift; efficiency cores and pauses when it is only in the menu bar.
    private func observeForegroundState() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSApplication.didBecomeActiveNotification,
            NSApplication.didResignActiveNotification,
            NSApplication.didHideNotification,
            NSApplication.didUnhideNotification,
            NSWindow.willCloseNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
        ]
        for name in names {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { Self.updateGovernorMode() }
            }
        }
        MainActor.assumeIsolated { Self.updateGovernorMode() }
    }

    @MainActor
    private static func updateGovernorMode() {
        let visible = NSApp.windows.contains { window in
            window.isVisible && !window.isMiniaturized && window.canBecomeMain
        }
        ResourceGovernor.shared.mode = (NSApp.isActive && visible) ? .foreground : .background
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
#endif
