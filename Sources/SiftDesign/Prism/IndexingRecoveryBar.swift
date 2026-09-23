import SwiftUI

public struct IndexingRecoveryBar: View {
    let phaseLabel: String
    let pendingAnalysisCount: Int
    let onContinue: () -> Void
    let onResetAI: () -> Void
    let onDismiss: () -> Void

    public init(
        phaseLabel: String,
        pendingAnalysisCount: Int,
        onContinue: @escaping () -> Void,
        onResetAI: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.phaseLabel = phaseLabel
        self.pendingAnalysisCount = pendingAnalysisCount
        self.onContinue = onContinue
        self.onResetAI = onResetAI
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 10) {
            recoveryButton(
                continueTitle,
                icon: "play.fill",
                prominent: true,
                action: onContinue
            )
            recoveryButton("Reset AI tags", icon: "arrow.counterclockwise", prominent: false, action: onResetAI)
            recoveryButton("Clear", icon: "xmark", prominent: false, action: onDismiss)
        }
    }

    private var continueTitle: String {
        if pendingAnalysisCount > 0 {
            return "Continue AI (\(pendingAnalysisCount))"
        }
        return "Continue"
    }

    private func recoveryButton(
        _ title: String,
        icon: String,
        prominent: Bool,
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
        #endif
        .prismClickable()
    }
}
