import SiftCore
import SwiftUI

public struct IndexingOverlay: View {
    let phase: IndexingCoordinator.Phase
    let assetCount: Int
    let isPaused: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onCancel: () -> Void

    public init(
        phase: IndexingCoordinator.Phase,
        assetCount: Int,
        isPaused: Bool,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.phase = phase
        self.assetCount = assetCount
        self.isPaused = isPaused
        self.onPause = onPause
        self.onResume = onResume
        self.onStop = onStop
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 20) {
            if isPaused {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.yellow)
            } else {
                ProgressView()
                    .controlSize(.large)
            }

            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if assetCount > 0 {
                Text("\(assetCount) items in library")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(PrismTheme.accent)
            }

            IndexingControlBar(
                isPaused: isPaused,
                onPause: onPause,
                onResume: onResume,
                onStop: onStop,
                onCancel: onCancel
            )
        }
        .padding(32)
        .frame(maxWidth: 420)
        .prismGlass(cornerRadius: 28, padding: 0)
    }

    private var title: String {
        if isPaused { return "Indexing paused" }
        switch phase {
        case .scanning(let folder, _):
            return "Scanning \(folder)"
        case .analyzing(let current, let total, _):
            return "Analyzing \(current) / \(total)"
        case .clustering:
            return "Organizing collections"
        case .stopped:
            return "Indexing stopped"
        case .cancelled:
            return "Indexing cancelled"
        default:
            return "Indexing…"
        }
    }

    private var subtitle: String {
        if isPaused {
            return "Paused — resume to continue, Stop to keep what’s indexed, or Cancel to abort."
        }
        switch phase {
        case .scanning(_, let count):
            return "\(count) media files found so far. The grid updates as items are saved."
        case .analyzing:
            return "On-device Vision: scenes, faces, text, and similarity."
        case .clustering:
            return "Clustering trips and people locally."
        case .stopped:
            return "Kept all assets indexed so far. You can start again anytime."
        case .cancelled:
            return "Operation aborted. Indexed assets remain in your library."
        default:
            return "Working…"
        }
    }
}
