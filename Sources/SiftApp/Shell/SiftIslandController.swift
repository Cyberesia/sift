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
    private let wishKey = "sift.notchWish"
    private var retracted = false
    private var windowObservers: [NSObjectProtocol] = []
    private var notchChrome: NotchChrome?
    /// Wide enough that the pull tab stays fully on screen.
    private let tuckedReveal: CGFloat = 32

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
        notchChrome = chrome
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
            },
            onPullEnded: { [weak self] travel in
                self?.userPulled(travel)
            }
        )
        let hosting = SiftNotchHostingView(rootView: root)
        hosting.onEdgePull = { [weak self] travel in
            self?.userPulled(travel)
        }
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
        startWatchingWindows()
        refreshWish()
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
                        self.refreshWish()
                    }
                }
            )
        }
    }

    /// `auto` follows the app window. `open` and `closed` are the user's drag.
    private func userPulled(_ travel: CGFloat) {
        if travel < -28 {
            UserDefaults.standard.set("open", forKey: wishKey)
        } else if travel > 28 {
            UserDefaults.standard.set("closed", forKey: wishKey)
        }
        refreshWish()
    }

    private func refreshWish() {
        let wish = UserDefaults.standard.string(forKey: wishKey) ?? "auto"
        let next: Bool
        switch wish {
        case "open": next = false
        case "closed": next = true
        default: next = windowCoversRail()
        }
        let covers = windowCoversRail()
        notchChrome?.windowCoversNotch = covers
        notchChrome?.isTucked = next
        hosting?.acceptsEdgePull = next || covers
        hosting?.tuckedForPull = next
        if covers {
            panel?.orderFrontRegardless()
        }
        guard next != retracted else { return }
        retracted = next
        applyFrame(animated: true)
        panel?.orderFrontRegardless()
    }

    private func windowCoversRail() -> Bool {
        guard let screen = NSScreen.main else { return false }
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
        guard let screen = NSScreen.main else { return }
        let bezel = screen.frame
        let visible = screen.visibleFrame
        let maxShift = max(0, (visible.height - size.height) / 2 - 8)
        let shift = min(maxShift, max(-maxShift, alongOffset))
        var y = visible.midY - size.height / 2 - shift
        y = min(max(y, visible.minY + 4), visible.maxY - size.height - 4)
        let tucked = retracted ? size.width - tuckedReveal : 0
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
    var onEdgePull: ((CGFloat) -> Void)?
    var acceptsEdgePull = false
    var tuckedForPull = false
    private var railCursorArea: NSTrackingArea?
    private var pullStart: NSPoint?

    override func hitTest(_ point: NSPoint) -> NSView? {
        let railStart = bounds.maxX - NotchRailMetrics.depth
        let onPullTab = point.x >= bounds.maxX - 32
        guard showsCard || point.x >= railStart || onPullTab else { return nil }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if acceptsEdgePull, point.x >= bounds.maxX - 32 {
            pullStart = NSEvent.mouseLocation
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard pullStart != nil else {
            super.mouseDragged(with: event)
            return
        }
        NSCursor.resizeLeftRight.set()
    }

    override func mouseUp(with event: NSEvent) {
        guard let pullStart else {
            super.mouseUp(with: event)
            return
        }
        let travel = NSEvent.mouseLocation.x - pullStart.x
        self.pullStart = nil
        if abs(travel) > 12 {
            onEdgePull?(travel)
        } else {
            onEdgePull?(tuckedForPull ? -40 : 40)
        }
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
        if acceptsEdgePull, point.x >= bounds.maxX - 32 {
            NSCursor.resizeLeftRight.set()
        } else if overGrip {
            NSCursor.openHand.set()
        } else if showsCard || point.x >= railStart {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }
}
#endif
