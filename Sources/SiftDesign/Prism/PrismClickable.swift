import SwiftUI

#if os(macOS)
import AppKit

/// Keeps the hand cursor while any clickable region is hovered.
/// Native controls and the hosting view reset the cursor to an arrow on their own cursor updates,
/// so the hand is applied again after each mouse event instead of once on enter.
@MainActor
final class PrismCursorController {
    static let shared = PrismCursorController()

    private var hovered: Set<UUID> = []
    private var monitor: Any?

    func enter(_ id: UUID) {
        hovered.insert(id)
        installMonitorIfNeeded()
        NSCursor.pointingHand.set()
    }

    func leave(_ id: UUID) {
        guard hovered.remove(id) != nil else { return }
        if hovered.isEmpty {
            NSCursor.arrow.set()
        }
    }

    fileprivate var isActive: Bool { !hovered.isEmpty }

    private func installMonitorIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .cursorUpdate, .leftMouseUp, .scrollWheel, .flagsChanged]
        ) { event in
            let swallow = MainActor.assumeIsolated { () -> Bool in
                let controller = PrismCursorController.shared
                guard controller.isActive else { return false }
                NSCursor.pointingHand.set()
                if event.type == .cursorUpdate { return true }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        if PrismCursorController.shared.isActive {
                            NSCursor.pointingHand.set()
                        }
                    }
                }
                return false
            }
            return swallow ? nil : event
        }
    }
}

private struct PrismClickableModifier: ViewModifier {
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .pointerStyle(.link)
            .onHover { inside in
                if inside {
                    PrismCursorController.shared.enter(id)
                } else {
                    PrismCursorController.shared.leave(id)
                }
            }
            .onDisappear {
                PrismCursorController.shared.leave(id)
            }
    }
}

public extension View {
    /// Hand cursor on hover (macOS). Apply to every tappable control including `Button`.
    func prismClickable() -> some View {
        modifier(PrismClickableModifier())
    }
}

/// Plain button style that always shows the hand cursor.
public struct PrismHandButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.88 : 1)
            .prismClickable()
    }
}
#else
public extension View {
    func prismClickable() -> some View { self }
}

public struct PrismHandButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.88 : 1)
    }
}
#endif
