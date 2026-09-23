import SiftCore
import SwiftUI

/// First-launch card shown while the visual-search weights download.
public struct ClipWeightSplash: View {
    let progress: ClipWeightProgress
    let errorMessage: String?
    let onRetry: () -> Void
    let onContinue: () -> Void

    public init(
        progress: ClipWeightProgress,
        errorMessage: String?,
        onRetry: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.progress = progress
        self.errorMessage = errorMessage
        self.onRetry = onRetry
        self.onContinue = onContinue
    }

    public var body: some View {
        ZStack {
            PrismTheme.dominant.opacity(0.94)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text("Setting up visual search")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PrismTheme.textPrimary)
                Text("Sift is downloading a local model once, about 289 MB. It matches a phrase with what is in a photo or video — “red bicycle”, “beach at sunset” — instead of only the file name.")
                    .font(.body)
                    .foregroundStyle(PrismTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("Your photos, videos, and searches stay on this Mac. This download is only the model.", systemImage: "lock.shield")
                    .font(.callout)
                    .foregroundStyle(PrismTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(PrismTheme.accentSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Continue without visual search", action: onContinue)
                            .prismClickable()
                        Spacer()
                        Button("Try again", action: onRetry)
                            .buttonStyle(.borderedProminent)
                            .prismClickable()
                    }
                } else {
                    ProgressView(value: progress.fraction)
                        .tint(PrismTheme.accent)
                        .accessibilityLabel("Visual model download")
                    Text(progress.statusLine)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(PrismTheme.textPrimary)
                    Text("You can keep this window open. Search by file name still works after the download.")
                        .font(.caption)
                        .foregroundStyle(PrismTheme.textTertiary)
                }
            }
            .padding(28)
            .frame(maxWidth: 520)
            .prismGlass(cornerRadius: 28, padding: 0)
        }
    }
}
