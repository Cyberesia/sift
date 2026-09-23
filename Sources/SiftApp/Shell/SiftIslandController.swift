#if os(macOS)
import AppKit
import SiftCore
import SiftDesign
import SwiftUI

@MainActor
final class SiftIslandController {
    private var panel: NSPanel?
    private var hosting: SiftNotchHostingView?
    private var installQueued = false
    private let offsetKey = "sift.notchAlongOffset"
    private let edgeKey = "sift.notchEdge"
    private var retracted = false
    private var pointerHolding = false
    private var windowObservers: [NSObjectProtocol] = []
    private var mouseMonitor: Any?
    private var globalMouseMonitor: Any?

    func install(
        jobs: BackgroundJobCenter,
        chrome: NotchChrome,
        onOpenMode: @escaping (AppMode) -> Void,
        onActivateStatus: @escaping () -> Void,
        onOpenGarden: @escaping () -> Void,
        onOpenInbox: @escaping () -> Void,
        onOpenDuplicates: @escaping () -> Void,
        onFocusSearch: @escaping () -> Void,
        onBrowseCatalog: @escaping () -> Void,
        onPreviewPlan: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onSubmitSearch: @escaping (String) -> Void,
        onQueryEdited: @escaping (String) -> Void,
        onOpenHit: @escaping (MediaAssetSummary) -> Void,
        onClearSearch: @escaping () -> Void,
        onDropURLs: @escaping ([URL]) -> Void,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        guard panel == nil, !installQueued else { return }
        installQueued = true
        // Session init runs inside a SwiftUI update. Building this panel there
        // and calling setFrame re-enters AttributeGraph and aborts.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.installQueued = false
            self.installNow(
                jobs: jobs,
                chrome: chrome,
                onOpenMode: onOpenMode,
                onActivateStatus: onActivateStatus,
                onOpenGarden: onOpenGarden,
                onOpenInbox: onOpenInbox,
                onOpenDuplicates: onOpenDuplicates,
                onFocusSearch: onFocusSearch,
                onBrowseCatalog: onBrowseCatalog,
                onPreviewPlan: onPreviewPlan,
                onStop: onStop,
                onSubmitSearch: onSubmitSearch,
                onQueryEdited: onQueryEdited,
                onOpenHit: onOpenHit,
                onClearSearch: onClearSearch,
                onDropURLs: onDropURLs,
                onPause: onPause,
                onResume: onResume,
                onQuit: onQuit
            )
        }
    }

    private func installNow(
        jobs: BackgroundJobCenter,
        chrome: NotchChrome,
        onOpenMode: @escaping (AppMode) -> Void,
        onActivateStatus: @escaping () -> Void,
        onOpenGarden: @escaping () -> Void,
        onOpenInbox: @escaping () -> Void,
        onOpenDuplicates: @escaping () -> Void,
        onFocusSearch: @escaping () -> Void,
        onBrowseCatalog: @escaping () -> Void,
        onPreviewPlan: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onSubmitSearch: @escaping (String) -> Void,
        onQueryEdited: @escaping (String) -> Void,
        onOpenHit: @escaping (MediaAssetSummary) -> Void,
        onClearSearch: @escaping () -> Void,
        onDropURLs: @escaping ([URL]) -> Void,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        guard panel == nil else { return }
        let root = SiftIslandView(
            jobs: jobs,
            chrome: chrome,
            onOpenMode: onOpenMode,
            onActivateStatus: onActivateStatus,
            onOpenGarden: onOpenGarden,
            onOpenInbox: onOpenInbox,
            onOpenDuplicates: onOpenDuplicates,
            onFocusSearch: onFocusSearch,
            onBrowseCatalog: onBrowseCatalog,
            onPreviewPlan: onPreviewPlan,
            onStop: onStop,
            onSubmitSearch: onSubmitSearch,
            onQueryEdited: onQueryEdited,
            onOpenHit: onOpenHit,
            onClearSearch: onClearSearch,
            onDropURLs: onDropURLs,
            onPause: onPause,
            onResume: onResume,
            onQuit: onQuit,
            onResize: { [weak self] showingCard in
                self?.hosting?.showsCard = showingCard
            },
            alongOffset: { [weak self] in
                self?.alongOffset ?? 0
            },
            onSetAlongOffset: { [weak self] value in
                self?.setAlongOffset(value)
            }
        )
        let hosting = SiftNotchHostingView(rootView: root)
        let panel = makePanel()
        panel.contentView = hosting
        self.hosting = hosting
        self.panel = panel
        let savedEdge = UserDefaults.standard.string(forKey: edgeKey)
        if savedEdge == nil || savedEdge == "top" {
            UserDefaults.standard.set("right", forKey: edgeKey)
        }
        applyFrame()
        panel.orderFrontRegardless()
        UserDefaults.standard.removeObject(forKey: "sift.notchWish")
        startWatchingWindows()
        startWatchingMouse()
        refreshVisibility()
    }

    private func startWatchingWindows() {
        guard windowObservers.isEmpty else { return }
        let names: [Notification.Name] = [
            NSWindow.didMoveNotification,
            NSWindow.didResizeNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didBecomeMainNotification,
        ]
        for name in names {
            windowObservers.append(
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    let window = note.object as? NSWindow
                    Task { @MainActor in
                        guard let self else { return }
                        if let window, window === self.panel { return }
                        self.refreshVisibility()
                    }
                }
            )
        }
    }

    private func startWatchingMouse() {
        guard mouseMonitor == nil else { return }
        for window in NSApp.windows where window.level == .normal {
            window.acceptsMouseMovedEvents = true
        }
        let note: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.notePointer()
            }
        }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { event in
            note(event)
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { event in
            note(event)
        }
    }

    /// Hidden while the app window covers the rail. Pushing the pointer to the right edge brings it back.
    private func notePointer() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? screenForNotch() else { return }
        let atRightEdge = screen.frame.maxX - mouse.x <= 2
            && mouse.y >= screen.frame.minY
            && mouse.y <= screen.frame.maxY
        let overRail = openRailRect(on: screen).insetBy(dx: -10, dy: -8).contains(mouse)
        let overCard = hosting?.showsCard == true && panel?.frame.insetBy(dx: -8, dy: -8).contains(mouse) == true
        let holding = atRightEdge || (!retracted && (overRail || overCard))
        guard holding != pointerHolding else { return }
        pointerHolding = holding
        refreshVisibility()
    }

    private func refreshVisibility() {
        let next = windowCoversRail() && !pointerHolding
        guard next != retracted else { return }
        retracted = next
        applyFrame(animated: true)
        panel?.orderFrontRegardless()
    }

    private func screenForNotch() -> NSScreen? {
        NSScreen.main
    }

    private func windowCoversRail() -> Bool {
        guard let screen = screenForNotch() else { return false }
        let rail = openRailRect(on: screen)
        for window in NSApp.windows where window !== panel && window.isVisible && !window.isMiniaturized {
            guard window.level == .normal else { continue }
            if window.styleMask.contains(.fullScreen), window.screen == screen {
                return true
            }
            if window.frame.intersects(rail) { return true }
        }
        return false
    }

    private func openRailRect(on screen: NSScreen) -> NSRect {
        let height = NotchRailMetrics.panelSize.height
        let visible = screen.visibleFrame
        let maxShift = max(0, (visible.height - height) / 2 - 8)
        let shift = min(maxShift, max(-maxShift, alongOffset))
        var y = visible.midY - height / 2 - shift
        y = min(max(y, visible.minY + 4), visible.maxY - height - 4)
        let width = NotchRailMetrics.depth
        let x = edge == "left" ? screen.frame.minX : screen.frame.maxX - width
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private var alongOffset: CGFloat {
        CGFloat(UserDefaults.standard.double(forKey: offsetKey))
    }

    private func setAlongOffset(_ value: CGFloat) {
        UserDefaults.standard.set(Double(value), forKey: offsetKey)
        applyFrame()
    }

    private var edge: String {
        UserDefaults.standard.string(forKey: edgeKey) ?? "right"
    }

    private func applyFrame(animated: Bool = false) {
        guard let panel else { return }
        let size = NotchRailMetrics.panelSize
        guard let screen = screenForNotch() else { return }
        let bezel = screen.frame
        let visible = screen.visibleFrame
        let maxShift = max(0, (visible.height - size.height) / 2 - 8)
        let shift = min(maxShift, max(-maxShift, alongOffset))
        var y = visible.midY - size.height / 2 - shift
        y = min(max(y, visible.minY + 4), visible.maxY - size.height - 4)
        let tucked = retracted ? size.width : 0
        let x = edge == "left" ? bezel.minX - tucked : bezel.maxX - size.width + tucked
        let rect = NSRect(x: x, y: y, width: size.width, height: size.height)
        guard panel.frame != rect else { return }
        panel.setFrame(rect, display: animated, animate: animated)
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 52),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.isMovable = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        return panel
    }

}

/// The panel keeps a constant frame, so hover never moves the rail beneath the
/// pointer. While no card is shown, the transparent area passes clicks through.
private final class SiftNotchHostingView: NSHostingView<SiftIslandView> {
    var showsCard = false
    private var railCursorArea: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? {
        let railStart = bounds.maxX - NotchRailMetrics.depth
        guard showsCard || point.x >= railStart else { return nil }
        return super.hitTest(point)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let railCursorArea {
            removeTrackingArea(railCursorArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        railCursorArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        updateRailCursor(event)
        super.mouseEntered(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        updateRailCursor(event)
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        super.mouseExited(with: event)
    }

    private func updateRailCursor(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let railStart = bounds.maxX - NotchRailMetrics.depth
        let gripHeight = NotchRailMetrics.bottomPadding + NotchRailMetrics.gripRowHeight
        let overGrip = point.x >= railStart && point.x < railStart + 32 && point.y <= gripHeight
        if overGrip {
            NSCursor.openHand.set()
        } else if showsCard || point.x >= railStart {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }
}
#endif
