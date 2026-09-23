import SwiftUI

public struct IndexingControlBar: View {
    let isPaused: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onCancel: () -> Void

    public init(
        isPaused: Bool,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.isPaused = isPaused
        self.onPause = onPause
        self.onResume = onResume
        self.onStop = onStop
        self.onCancel = onCancel
    }

    public var body: some View {
        HStack(spacing: 10) {
            if isPaused {
                controlButton("Resume", icon: "play.fill", prominent: true, action: onResume)
            } else {
                controlButton("Pause", icon: "pause.fill", prominent: false, action: onPause)
            }
            controlButton(
                "Stop & keep",
                icon: "stop.fill",
                prominent: false,
                help: "Stop this job and keep every catalog item and thumbnail completed so far.",
                action: onStop
            )
            controlButton(
                "Cancel phase",
                icon: "xmark",
                prominent: false,
                help: "Cancel the current phase. Files already cataloged remain available.",
                action: onCancel
            )
        }
    }

    private func controlButton(
        _ title: String,
        icon: String,
        prominent: Bool,
        help: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 32)
                .contentShape(Capsule())
        }
        #if os(macOS)
        .buttonStyle(.bordered)
        .tint(prominent ? PrismTheme.accent : nil)
        #else
        .buttonStyle(.plain)
        .background(
            Capsule()
                .fill(prominent ? ColorPrismTheme.accent.opacity(0.35) : Color.white.opacity(0.1))
        )
        #endif
        .help(help ?? title)
        .prismClickable()
    }
}
