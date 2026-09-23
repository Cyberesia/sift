import SwiftUI

#if os(macOS)
import AppKit

private struct PrismClickableModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .pointerStyle(.link)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    NSCursor.pointingHand.set()
                case .ended:
                    NSCursor.arrow.set()
                }
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
