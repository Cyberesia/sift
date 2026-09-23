import SiftCore
import SwiftUI

public struct IndexDock: View {
    let phase: IndexingCoordinator.Phase
    let assetCount: Int
    let analyzedCount: Int
    let inboxCount: Int
    let sourceFolderCount: Int
    let isPaused: Bool
    let showsTransportControls: Bool
    let showsRecoveryControls: Bool
    let pendingAnalysisCount: Int
    let scanDetail: String
    let onAddSourceFolder: () -> Void
    let onRescanSources: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onCancel: () -> Void
    let onContinueIndexing: () -> Void
    let onResetAI: () -> Void
    @State private var confirm: SiftConfirm?
    let onDismissStatus: () -> Void
    @State private var isExpanded = false

    public init(
        phase: IndexingCoordinator.Phase,
        assetCount: Int,
        analyzedCount: Int,
        inboxCount: Int = 0,
        sourceFolderCount: Int = 0,
        isPaused: Bool = false,
        showsTransportControls: Bool = false,
        showsRecoveryControls: Bool = false,
        pendingAnalysisCount: Int = 0,
        scanDetail: String = "",
        onAddSourceFolder: @escaping () -> Void = {},
        onRescanSources: @escaping () -> Void = {},
        onPause: @escaping () -> Void = {},
        onResume: @escaping () -> Void = {},
        onStop: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {},
        onContinueIndexing: @escaping () -> Void = {},
        onResetAI: @escaping () -> Void = {},
        onDismissStatus: @escaping () -> Void = {}
    ) {
        self.phase = phase
        self.assetCount = assetCount
        self.analyzedCount = analyzedCount
        self.inboxCount = inboxCount
        self.sourceFolderCount = sourceFolderCount
        self.isPaused = isPaused
        self.showsTransportControls = showsTransportControls
        self.showsRecoveryControls = showsRecoveryControls
        self.pendingAnalysisCount = pendingAnalysisCount
        self.scanDetail = scanDetail
        self.onAddSourceFolder = onAddSourceFolder
        self.onRescanSources = onRescanSources
        self.onPause = onPause
        self.onResume = onResume
        self.onStop = onStop
        self.onCancel = onCancel
        self.onContinueIndexing = onContinueIndexing
        self.onResetAI = onResetAI
        self.onDismissStatus = onDismissStatus
    }

    private var isIdle: Bool {
        if case .idle = phase { return true }
        return false
    }

    public var body: some View {
        Group {
            if isIdle && !isExpanded {
                compactIdleButton
            } else {
                expandedDock
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
    }

    private var expandedDock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                progressOrb
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(statusTitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(PrismTheme.textPrimary)
                            .lineLimit(1)
                        if let stageLabel {
                            Text(stageLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(PrismTheme.textTertiary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.06), in: Capsule())
                        }
                        Spacer(minLength: 8)
                        if let progress = progressFraction, !isIdle {
                            Text("\(Int((progress * 100).rounded()))%")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(PrismTheme.accentSecondary)
                        }
                    }
                    if let progress = progressFraction, !isIdle {
                        luminousTrack(progress)
                    }
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundStyle(PrismTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if !isIdle {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(assetCount)")
                            .font(.caption.weight(.bold).monospacedDigit())
                        Text("\(analyzedCount) read")
                            .font(.caption2)
                            .foregroundStyle(PrismTheme.textTertiary)
                    }
                }
            }

            if isIdle {
                HStack {
                    idleActions
                    Spacer()
                    Button {
                        isExpanded = false
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PrismTheme.textTertiary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("Collapse discovery controls")
                    .prismClickable()
                }
            } else if showsTransportControls {
                HStack(spacing: 8) {
                    transportButton(
                        isPaused ? "Resume" : "Pause",
                        icon: isPaused ? "play.fill" : "pause.fill",
                        help: isPaused ? "Resume indexing" : "Pause without losing progress",
                        action: isPaused ? onResume : onPause
                    )
                    transportButton(
                        "Stop",
                        icon: "stop.fill",
                        help: "Stop here and keep every file already cataloged",
                        action: {
                            confirm = SiftConfirm(
                                title: "Stop indexing?",
                                message: "Indexing stops here. Files already in the catalog stay.",
                                confirmTitle: "Stop",
                                destructive: false,
                                run: onStop
                            )
                        }
                    )
                    transportButton(
                        "Cancel",
                        icon: "xmark",
                        help: "Cancel this phase. Cataloged files remain available",
                        action: {
                            confirm = SiftConfirm(
                                title: "Cancel this phase?",
                                message: "This phase stops. Files already cataloged remain available.",
                                confirmTitle: "Cancel phase",
                                destructive: false,
                                run: onCancel
                            )
                        }
                    )
                    Spacer()
                }
            } else if showsRecoveryControls {
                IndexingRecoveryBar(
                    phaseLabel: recoveryPhaseLabel,
                    pendingAnalysisCount: pendingAnalysisCount,
                    onContinue: onContinueIndexing,
                    onResetAI: onResetAI,
                    onDismiss: onDismissStatus
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 760)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [PrismTheme.accent.opacity(0.16), .clear, PrismTheme.accentSecondary.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(PrismTheme.glassStrokeGradient, lineWidth: 1)
        }
        .shadow(color: PrismTheme.accent.opacity(isIdle ? 0 : 0.18), radius: 22, y: 10)
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .siftConfirming($confirm)
    }

    private var progressOrb: some View {
        ZStack {
            Circle()
                .stroke(PrismTheme.borderSubtle, lineWidth: 3)
            if let progress = progressFraction, !isIdle {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        PrismTheme.accentGradient,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: PrismTheme.accentGlow, radius: 6)
            }
            Image(systemName: orbSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isPaused ? Color.yellow : PrismTheme.accent)
        }
        .frame(width: 42, height: 42)
    }

    private func luminousTrack(_ progress: Double) -> some View {
        GeometryReader { geo in
            Capsule()
                .fill(.white.opacity(0.08))
            Capsule()
                .fill(isPaused ? AnyShapeStyle(Color.yellow) : AnyShapeStyle(PrismTheme.accentGradient))
                .frame(width: max(8, geo.size.width * progress))
                .shadow(color: isPaused ? .yellow.opacity(0.35) : PrismTheme.accentGlow, radius: 7)
        }
        .frame(height: 5)
    }

    private func transportButton(
        _ title: String,
        icon: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.06), in: Capsule())
                .overlay { Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .help(help)
        .prismClickable()
    }

    private var compactIdleButton: some View {
        Button {
            isExpanded = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "sparkle.magnifyingglass")
                    .foregroundStyle(PrismTheme.accent)
                Text(sourceFolderCount > 0 ? "Find or update media" : "Find media")
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.up")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PrismTheme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(PrismTheme.glassStrokeGradient, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .prismClickable()
    }

    private var idleActions: some View {
        HStack(spacing: 8) {
            Button(action: onAddSourceFolder) {
                Label("Find media", systemImage: "sparkle.magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 4)
                    .frame(height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderedProminent)
            .help("Open discovery: scan this Mac or choose locations")
            .prismClickable()

            if sourceFolderCount > 0 {
                Button {
                    confirm = SiftConfirm(
                        title: "Update the catalog?",
                        message: "Sift walks the saved folders again. Files stay where they are.",
                        confirmTitle: "Update",
                        destructive: false,
                        run: onRescanSources
                    )
                } label: {
                    Label("Update", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 4)
                        .frame(height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .help("Rescan all saved source folders")
                .prismClickable()
            }
        }
    }

    private var progressFraction: Double? {
        switch phase {
        case .analyzing(let current, let total, _),
             .embedding(let current, let total, _),
             .thumbnailing(let current, let total, _):
            guard total > 0 else { return nil }
            return Double(current) / Double(total)
        case .scanning(_, let filesFound):
            return filesFound > 0 ? min(1, Double(filesFound) / Double(filesFound + 50)) : 0.05
        case .clustering:
            return 0.95
        case .paused:
            return nil
        default:
            return nil
        }
    }

    private var orbSymbol: String {
        if isPaused { return "pause.fill" }
        switch phase {
        case .scanning: return "internaldrive"
        case .thumbnailing: return "photo"
        case .analyzing: return "sparkles"
        case .embedding: return "circle.hexagongrid"
        case .clustering: return "person.2"
        case .complete: return "checkmark"
        case .failed: return "exclamationmark.triangle"
        default: return "sparkle.magnifyingglass"
        }
    }

    private var statusTitle: String {
        if isPaused { return "Paused" }
        switch phase {
        case .idle:
            return sourceFolderCount > 0 ? "Ready to rescan" : "Ready to add sources"
        case .scanning(let folder, let count):
            return "Scanning \(folder) · \(count) files"
        case .thumbnailing(let current, let total, _):
            return "Previews \(current) / \(total)"
        case .analyzing(let current, let total, _):
            return "Reading \(current) of \(total)"
        case .embedding(let current, let total, _):
            return "Learning content \(current) of \(total)"
        case .clustering: return "Building collections…"
        case .paused: return "Indexing paused"
        case .stopped: return "Stopped · kept library catalog"
        case .cancelled: return "Cancelled"
        case .complete: return "Index complete"
        case .failed: return "Indexing failed"
        }
    }

    private var stageLabel: String? {
        switch phase {
        case .thumbnailing: "Step 1 of 3"
        case .analyzing: "Step 2 of 3"
        case .embedding: "Step 3 of 3"
        case .clustering: "Finalizing"
        default: nil
        }
    }

    private var statusSubtitle: String {
        if isPaused { return "Resume, Stop, or Cancel" }
        switch phase {
        case .idle:
            if sourceFolderCount > 0 {
                return "Use + to add another source, ↻ to rescan \(sourceFolderCount) folder(s)"
            }
            return "Use + to add your first source folder"
        case .failed(let message): return "\(message) — Continue or Reset AI below"
        case .paused: return "Resume, Stop, or Cancel"
        case .stopped: return "Use Continue to resume, Reset AI to clear tags, or Clear to dismiss"
        case .cancelled: return "Indexing was cancelled — Continue or Reset AI below"
        case .complete:
            if pendingAnalysisCount > 0 {
                return "\(pendingAnalysisCount) items still need AI tagging"
            }
            if inboxCount > 0 {
                return "\(inboxCount) items still at source — open Inbox in Library"
            }
            return "All processing finished on-device"
        case .scanning: return scanDetail.isEmpty ? "Looking through the selected folders…" : scanDetail
        case .thumbnailing(_, _, let name): return name
        case .analyzing(_, _, let name): return name.isEmpty ? "Scenes, faces, and text stay on this Mac" : name
        case .embedding(_, _, let name): return name.isEmpty ? "Building the visual search index" : name
        case .clustering: return "Grouping trips, people, and places"
        }
    }

    private var recoveryPhaseLabel: String {
        switch phase {
        case .stopped: return "Stopped"
        case .cancelled: return "Cancelled"
        case .failed: return "Failed"
        case .complete: return "Incomplete AI"
        default: return "Indexing"
        }
    }

}
