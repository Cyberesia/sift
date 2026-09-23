import SiftCore
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

/// Bezel-welded icon rail. Hovering an icon opens one card inward; the rail stays put.
public struct SiftIslandView: View {
    @ObservedObject var jobs: BackgroundJobCenter
    @ObservedObject var chrome: NotchChrome
    let onOpenMode: (AppMode) -> Void
    let onActivateStatus: () -> Void
    let onOpenGarden: () -> Void
    let onOpenInbox: () -> Void
    let onOpenDuplicates: () -> Void
    let onFocusSearch: () -> Void
    let onBrowseCatalog: () -> Void
    let onPreviewPlan: () -> Void
    let onStop: () -> Void
    let onSubmitSearch: (String) -> Void
    let onQueryEdited: (String) -> Void
    let onOpenHit: (MediaAssetSummary) -> Void
    let onClearSearch: () -> Void
    let onDropURLs: ([URL]) -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onQuit: () -> Void
    let onResize: (Bool) -> Void
    let alongOffset: () -> CGFloat
    let onSetAlongOffset: (CGFloat) -> Void
    let onPullEnded: (CGFloat) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered: NotchRailItem?
    @State private var dropTargeted = false
    @State private var moveOrigin: CGFloat?
    @State private var cardHeight: CGFloat = 0

    public init(
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
        onQuit: @escaping () -> Void,
        onResize: @escaping (Bool) -> Void,
        alongOffset: @escaping () -> CGFloat,
        onSetAlongOffset: @escaping (CGFloat) -> Void,
        onPullEnded: @escaping (CGFloat) -> Void
    ) {
        self.jobs = jobs
        self.chrome = chrome
        self.onOpenMode = onOpenMode
        self.onActivateStatus = onActivateStatus
        self.onOpenGarden = onOpenGarden
        self.onOpenInbox = onOpenInbox
        self.onOpenDuplicates = onOpenDuplicates
        self.onFocusSearch = onFocusSearch
        self.onBrowseCatalog = onBrowseCatalog
        self.onPreviewPlan = onPreviewPlan
        self.onStop = onStop
        self.onSubmitSearch = onSubmitSearch
        self.onQueryEdited = onQueryEdited
        self.onOpenHit = onOpenHit
        self.onClearSearch = onClearSearch
        self.onDropURLs = onDropURLs
        self.onPause = onPause
        self.onResume = onResume
        self.onQuit = onQuit
        self.onResize = onResize
        self.alongOffset = alongOffset
        self.onSetAlongOffset = onSetAlongOffset
        self.onPullEnded = onPullEnded
    }

    public var body: some View {
        ZStack(alignment: .trailing) {
            rail
            if let hovered {
                hoverCard(hovered, tailBias: tailBias(for: hovered))
                    .padding(.trailing, NotchRailMetrics.depth + NotchRailMetrics.cardGap)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(key: NotchCardHeightKey.self, value: proxy.size.height)
                        }
                    }
                    .offset(y: cardOffset(for: hovered))
                    .transition(.opacity)
            }
        }
        .onPreferenceChange(NotchCardHeightKey.self) { cardHeight = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: hovered)
        .onHover { inside in
            if !inside {
                hovered = nil
                #if os(macOS)
                NSCursor.arrow.set()
                #endif
            }
        }
        .onChange(of: hovered) { _, item in
            onResize(item != nil)
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
            hovered = .sources
            loadDropped(providers)
            return true
        }
    }

    private var rail: some View {
        VStack(spacing: NotchRailMetrics.cellSpacing) {
            ForEach(NotchRailItem.allCases) { item in
                cell(item)
            }
            HStack(spacing: 4) {
                dragGrip
                Button(action: onQuit) {
                    Image(systemName: "power")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .frame(width: 20, height: 18)
                        .background(Color.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .prismClickable()
                .notchTooltip("Quit Sift", leading: true)
            }
        }
        .padding(.top, NotchRailMetrics.topPadding)
        .padding(.bottom, NotchRailMetrics.bottomPadding)
        .frame(width: NotchRailMetrics.depth, height: NotchRailMetrics.length)
        .overlay(alignment: .trailing) {
            if chrome.isTucked || chrome.windowCoversNotch {
                edgePull
            }
        }
        .background {
            SideNotchShape()
                .fill(.ultraThinMaterial)
                .overlay {
                    SideNotchShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    PrismTheme.surfaceElevated.opacity(0.78),
                                    PrismTheme.dominant.opacity(0.72),
                                    PrismTheme.accentSoft.opacity(0.55),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    SideNotchShape()
                        .stroke(PrismTheme.glassStrokeGradient, lineWidth: 1)
                }
                .shadow(color: PrismTheme.accentGlow.opacity(0.45), radius: 18, x: -5)
        }
    }

    private func cell(_ item: NotchRailItem) -> some View {
        let active = hovered == item
        return Button {
            perform(item)
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(active ? PrismTheme.accentSoft : Color.white.opacity(0.07))
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    active ? PrismTheme.accent : Color.white.opacity(0.30),
                                    lineWidth: active ? 1.8 : 1
                                )
                        }
                        .frame(width: 30, height: 30)
                    if item == .index, let fraction = jobs.progress.fraction {
                        Circle()
                            .trim(from: 0, to: fraction)
                            .stroke(PrismTheme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 30, height: 30)
                    }
                    Image(systemName: item.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(active ? PrismTheme.accentSecondary : Color.white)
                }
                Text(chrome.caption(for: item, progressFraction: jobs.progress.fraction))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: NotchRailMetrics.cellHeight)
        }
        .buttonStyle(.plain)
        .prismClickable()
        .onHover { inside in
            if inside { hovered = item }
        }
    }

    private var dragGrip: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.45))
            .frame(width: 28, height: 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if moveOrigin == nil { moveOrigin = alongOffset() }
                        onSetAlongOffset((moveOrigin ?? 0) + value.translation.height)
                    }
                    .onEnded { _ in moveOrigin = nil }
            )
            .help("Drag along the screen edge")
    }

    private var edgePull: some View {
        VStack {
            Spacer(minLength: 0)
            Image(systemName: chrome.isTucked ? "chevron.left" : "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 72)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(PrismTheme.accent.opacity(0.88))
                        }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 8, x: -2, y: 2)
                .help(chrome.isTucked ? "Drag left to open the notch" : "Drag right to tuck the notch away")
            Spacer(minLength: 0)
        }
        .frame(width: 28)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onEnded { value in
                    let travel = value.translation.width
                    guard abs(travel) > abs(value.translation.height) else { return }
                    onPullEnded(travel)
                }
        )
        .onHover { inside in
            #if os(macOS)
            if inside { NSCursor.resizeLeftRight.set() }
            #endif
        }
    }

    private func hoverCard(_ item: NotchRailItem, tailBias: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(PrismTheme.accent)
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(PrismTheme.textPrimary)
                Spacer()
                Circle()
                    .fill(statusColor(for: item))
                    .frame(width: 7, height: 7)
                    .shadow(color: statusColor(for: item), radius: 5)
            }
            cardBody(item)
        }
        .padding(14)
        .frame(width: NotchRailMetrics.cardWidth, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    PrismTheme.surfaceElevated.opacity(0.52),
                                    PrismTheme.dominant.opacity(0.42),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(PrismTheme.glassStrokeGradient, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
        }
        .overlay(alignment: .trailing) {
            CardTail()
                .fill(.regularMaterial)
                .overlay {
                    CardTail()
                        .fill(PrismTheme.surfaceElevated.opacity(0.58))
                }
                .overlay {
                    CardTail()
                        .stroke(PrismTheme.accent.opacity(0.35), lineWidth: 0.8)
                }
                .frame(width: 10, height: 14)
                .offset(x: 8, y: tailBias)
        }
    }

    @ViewBuilder
    private func cardBody(_ item: NotchRailItem) -> some View {
        switch item {
        case .index:
            Text(jobs.progress.subtitle.isEmpty ? jobs.progress.title : jobs.progress.subtitle)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.7))
                .lineLimit(2)
            Text("\(chrome.assetCount) found · \(chrome.skippedTrees) trees skipped")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.55))
            if let fraction = jobs.progress.fraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .tint(PrismTheme.accent)
            }
            if jobs.progress.kind != .idle {
                HStack(spacing: 8) {
                    Button("Pause", action: onPause)
                        .notchTooltip("Pause this step. Nothing already saved is lost.")
                    Button("Resume", action: onResume)
                        .notchTooltip("Continue the current step.")
                    Button("Stop", action: onStop)
                        .notchTooltip("Stop here and keep every file already cataloged.")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white)
                .buttonStyle(.plain)
                .prismClickable()
            }
        case .library:
            HStack(spacing: 7) {
                metric("\(chrome.photoCount)", "Photos")
                metric("\(chrome.videoCount)", "Videos")
                metric("\(chrome.audioCount)", "Audio")
            }
            if !chrome.latest.isEmpty {
                HStack(spacing: 6) {
                    ForEach(chrome.latest.prefix(5)) { asset in
                        Button { onOpenHit(asset) } label: {
                            ThumbnailImageView(path: asset.thumbnailPath, contentMode: .fill)
                                .frame(width: 42, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                        .prismClickable()
                    }
                }
            }
            Button("Entire Mac", action: onBrowseCatalog)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white)
                .buttonStyle(.plain)
                .prismClickable()
        case .garden:
            Text(chrome.clipReady
                 ? "CLIP on this Mac · \(chrome.clipEmbeddedCount) of \(chrome.photoCount + chrome.videoCount) embedded"
                 : "Vision labels + OCR · CLIP downloads on first launch")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.7))
            Button("Open visual Garden", action: onOpenGarden)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PrismTheme.accentSecondary)
                .buttonStyle(.plain)
                .prismClickable()
        case .sources:
            Text(dropTargeted ? "Drop to add a folder" : "\(chrome.folderCount) roots · \(chrome.fullDiskAccess ? "Full Disk Access" : "Chosen folders")")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.7))
        case .inbox:
            Text("\(chrome.inboxCount) still in source folders")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.7))
        case .organize:
            Text("\(chrome.planCount) safe · \(chrome.blockedPlanCount) held in projects")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.7))
            Button("Preview plan", action: onPreviewPlan)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white)
                .buttonStyle(.plain)
                .prismClickable()
        case .review:
            Text("\(chrome.suggestionCount) suggestions to accept")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.7))
            Button("Open review queue") { onOpenMode(.review) }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PrismTheme.accentSecondary)
                .buttonStyle(.plain)
                .prismClickable()
        case .duplicates:
            Text(chrome.duplicateCount == 0 ? "Scan for duplicates" : "\(chrome.duplicateCount) groups")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.7))
        case .search:
            searchBody
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(PrismTheme.textPrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(PrismTheme.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private func statusColor(for item: NotchRailItem) -> Color {
        switch item {
        case .index: jobs.progress.kind == .idle ? .green : PrismTheme.accent
        case .garden, .search: chrome.clipReady ? .green : .yellow
        case .sources: chrome.folderCount > 0 ? .green : .yellow
        case .organize: chrome.blockedPlanCount > 0 ? .orange : .green
        default: PrismTheme.accent
        }
    }

    private var searchBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Search", text: $chrome.query)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundStyle(Color.white)
                .onSubmit { onSubmitSearch(chrome.query) }
                .onChange(of: chrome.query) { _, query in
                    onQueryEdited(query)
                }
            Button("Entire Mac", action: onBrowseCatalog)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.8))
                .buttonStyle(.plain)
                .prismClickable()
            if !chrome.query.isEmpty {
                Button("Clear") {
                    chrome.query = ""
                    onClearSearch()
                }
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.55))
                .buttonStyle(.plain)
                .prismClickable()
            }
            if chrome.searchActive {
                if chrome.hits.isEmpty {
                    Text("No matches")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                ForEach(chrome.hits.prefix(4)) { asset in
                    Button {
                        onOpenHit(asset)
                    } label: {
                        HStack(spacing: 8) {
                            ThumbnailImageView(path: asset.thumbnailPath, contentMode: .fill)
                                .frame(width: 34, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Text(asset.fileName)
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.85))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 8))
                                .foregroundStyle(PrismTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .prismClickable()
                }
            }
        }
    }

    private func perform(_ item: NotchRailItem) {
        switch item {
        case .index: onActivateStatus()
        case .library: onOpenMode(.library)
        case .garden: onOpenGarden()
        case .sources: onOpenMode(.sources)
        case .inbox: onOpenInbox()
        case .organize: onOpenMode(.organize)
        case .review: onOpenMode(.review)
        case .duplicates: onOpenDuplicates()
        case .search: onFocusSearch()
        }
    }

    private func cardOffset(for item: NotchRailItem) -> CGFloat {
        let items = NotchRailItem.allCases
        guard let index = items.firstIndex(of: item) else { return 0 }
        return NotchRailMetrics.cardOffset(index: index, cardHeight: cardHeight)
    }

    /// Keeps the card tail on the icon when the card itself is shifted to stay on screen.
    private func tailBias(for item: NotchRailItem) -> CGFloat {
        let items = NotchRailItem.allCases
        guard let index = items.firstIndex(of: item), cardHeight > 1 else { return 0 }
        let iconCenter = NotchRailMetrics.iconCenter(index: index)
        let cardCenter = NotchRailMetrics.length / 2 + cardOffset(for: item)
        let bias = iconCenter - cardCenter
        let limit = max(0, cardHeight / 2 - 12)
        return min(limit, max(-limit, bias))
    }

    private func loadDropped(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL? = {
                    if let url = item as? URL { return url }
                    if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                        return URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    return nil
                }()
                guard let url else { return }
                Task { @MainActor in
                    onDropURLs([url])
                }
            }
        }
    }
}

private struct NotchCardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct NotchTooltipModifier: ViewModifier {
    let text: String
    let leading: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering = $0 }
            .overlay(alignment: leading ? .leading : .top) {
                if hovering {
                    Text(text)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.82), in: Capsule())
                        .fixedSize()
                        .offset(x: leading ? -132 : 0, y: leading ? 0 : -26)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .zIndex(hovering ? 20 : 0)
    }
}

private extension View {
    func notchTooltip(_ text: String, leading: Bool = false) -> some View {
        modifier(NotchTooltipModifier(text: text, leading: leading))
    }
}

private struct CardTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
