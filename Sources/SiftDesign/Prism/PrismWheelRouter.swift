#if os(macOS)
import AppKit
import SwiftUI

enum PrismWheelDecision {
    /// Handled here; the app never sees the event.
    case consume
    /// Stop routing and let the app handle the event normally, for example a native scroll view.
    case deliver
    /// Not for this region; try the region underneath.
    case skip
}

/// One scroll-wheel monitor for the whole app. Regions on a higher layer are asked first, so the
/// preview overlay keeps the wheel instead of the Garden stage underneath it.
@MainActor
final class PrismWheelRouter {
    static let shared = PrismWheelRouter()

    private struct Entry {
        let id: ObjectIdentifier
        weak var view: NSView?
        let layer: Int
        let order: Int
        let handler: (NSEvent) -> PrismWheelDecision
    }

    private var entries: [Entry] = []
    private var counter = 0
    private var monitor: Any?

    func register(_ view: NSView, layer: Int, handler: @escaping (NSEvent) -> PrismWheelDecision) {
        entries.removeAll { $0.id == ObjectIdentifier(view) || $0.view == nil }
        counter += 1
        entries.append(Entry(id: ObjectIdentifier(view), view: view, layer: layer, order: counter, handler: handler))
        installMonitorIfNeeded()
    }

    func unregister(_ view: NSView) {
        entries.removeAll { $0.id == ObjectIdentifier(view) || $0.view == nil }
        if entries.isEmpty, let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func installMonitorIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            let consumed = MainActor.assumeIsolated { PrismWheelRouter.shared.route(event) }
            return consumed ? nil : event
        }
    }

    private func route(_ event: NSEvent) -> Bool {
        let ordered = entries.sorted { ($0.layer, $0.order) > ($1.layer, $1.order) }
        for entry in ordered {
            guard let view = entry.view, let window = view.window, event.window === window, !view.isHiddenOrHasHiddenAncestor else {
                continue
            }
            let point = view.convert(event.locationInWindow, from: nil)
            guard view.bounds.contains(point) else { continue }
            switch entry.handler(event) {
            case .consume: return true
            case .deliver: return false
            case .skip: continue
            }
        }
        return false
    }
}

/// A transparent region that receives wheel events through `PrismWheelRouter`.
struct PrismWheelRegion: NSViewRepresentable {
    var layer: Int = 0
    var onWheel: (NSEvent) -> PrismWheelDecision

    func makeNSView(context: Context) -> RegionView {
        let view = RegionView()
        view.wheelLayer = layer
        view.onWheel = onWheel
        return view
    }

    func updateNSView(_ nsView: RegionView, context: Context) {
        nsView.onWheel = onWheel
    }

    static func dismantleNSView(_ nsView: RegionView, coordinator: ()) {
        PrismWheelRouter.shared.unregister(nsView)
    }

    final class RegionView: NSView {
        var onWheel: ((NSEvent) -> PrismWheelDecision)?
        var wheelLayer = 0

        override var isOpaque: Bool { false }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                PrismWheelRouter.shared.unregister(self)
            } else {
                PrismWheelRouter.shared.register(self, layer: wheelLayer) { [weak self] event in
                    self?.onWheel?(event) ?? .skip
                }
            }
        }
    }
}
#endif
