import SiftCore
import SwiftUI

#if os(macOS)
@preconcurrency import AppKit
#endif

public struct AssetPreviewCarousel: View {
    let assets: [MediaAssetSummary]
    @Binding var selectionIndex: Int
    @Binding var isFullscreen: Bool
    let panelSize: CGSize
    let windowSize: CGSize
    let mediaAccessRoot: (MediaAssetSummary) -> URL?
    let onClose: () -> Void
    let onRevealInFinder: (URL) -> Void
    let onCopyPath: (String) -> Void
    let onMoveToPhotos: (() -> Void)?
    let onMoveToVideos: (() -> Void)?
    let onMoveToGather: (() -> Void)?
    let onPersonLabelCommit: (String) -> Void

    @State private var displayImage: PlatformPreviewImage?
    @State private var imagePixelSize: CGSize?
    @State private var isLoadingHighRes = false
    @State private var showInspector = true
    @State private var loadToken = UUID()
    @State private var videoPlaying = true
    @State private var scopedAccessURL: URL?

    private let previewMaxPixelSize = 1920

    public init(
        assets: [MediaAssetSummary],
        selectionIndex: Binding<Int>,
        isFullscreen: Binding<Bool>,
        panelSize: CGSize,
        windowSize: CGSize,
        mediaAccessRoot: @escaping (MediaAssetSummary) -> URL? = { _ in nil },
        onClose: @escaping () -> Void,
        onRevealInFinder: @escaping (URL) -> Void,
        onCopyPath: @escaping (String) -> Void,
        onMoveToPhotos: (() -> Void)? = nil,
        onMoveToVideos: (() -> Void)? = nil,
        onMoveToGather: (() -> Void)? = nil,
        onPersonLabelCommit: @escaping (String) -> Void = { _ in }
    ) {
        self.assets = assets
        _selectionIndex = selectionIndex
        _isFullscreen = isFullscreen
        self.panelSize = panelSize
        self.windowSize = windowSize
        self.mediaAccessRoot = mediaAccessRoot
        self.onClose = onClose
        self.onRevealInFinder = onRevealInFinder
        self.onCopyPath = onCopyPath
        self.onMoveToPhotos = onMoveToPhotos
        self.onMoveToVideos = onMoveToVideos
        self.onMoveToGather = onMoveToGather
        self.onPersonLabelCommit = onPersonLabelCommit
    }

    private var currentAsset: MediaAssetSummary? {
        guard selectionIndex >= 0, selectionIndex < assets.count else { return nil }
        return assets[selectionIndex]
    }

    private var effectiveSize: CGSize {
        isFullscreen
            ? CGSize(width: max(windowSize.width, 800), height: max(windowSize.height, 600))
            : panelSize
    }

    private var inspectorWidth: CGFloat { 300 }
    private var topBarHeight: CGFloat { 58 }
    private var thumbnailStripHeight: CGFloat { 88 }

    private var stageContentWidth: CGFloat {
        let inspector = (showInspector && !isFullscreen) ? inspectorWidth : 0
        return max(effectiveSize.width - inspector - 24, 200)
    }

    /// Stage height follows image aspect ratio so portrait shots don't leave a dead zone above the filmstrip.
    private var stageAreaHeight: CGFloat {
        let maxStage = max(effectiveSize.height - topBarHeight - thumbnailStripHeight, 180)
        let aspect: CGSize = {
            if currentAsset?.kind == .video {
                return imagePixelSize ?? CGSize(width: 16, height: 9)
            }
            return imagePixelSize ?? CGSize(width: 3, height: 2)
        }()
        let natural = stageContentWidth * aspect.height / max(aspect.width, 1)
        return min(maxStage, max(natural, 160))
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(isFullscreen ? 0.92 : 0.68)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            carouselPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            clampSelection()
            beginMediaAccess()
            scheduleLoad()
        }
        .onChange(of: selectionIndex) { _, _ in
            beginMediaAccess()
            scheduleLoad()
        }
        .onChange(of: assets.count) { _, _ in clampSelection() }
        .onDisappear { endMediaAccess() }
        .onExitCommand(perform: onClose)
        #if os(macOS)
        .background(
            CarouselKeyboardMonitor(
                onLeft: { step(-1) },
                onRight: { step(1) },
                onFullscreen: { toggleFullscreen() },
                onToggleInspector: { toggleInspector() }
            )
        )
        #endif
        .focusable()
        .onKeyPress(.leftArrow) {
            step(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            step(1)
            return .handled
        }
        .onKeyPress("f") {
            toggleFullscreen()
            return .handled
        }
    }

    private var carouselPanel: some View {
        VStack(spacing: 0) {
            topBar
            HStack(alignment: .top, spacing: 0) {
                ZStack(alignment: .trailing) {
                    mainStage
                    if !showInspector && !isFullscreen {
                        inspectorRevealButton
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: stageAreaHeight)

                if showInspector && !isFullscreen {
                    previewInspector
                        .frame(width: inspectorWidth, height: stageAreaHeight)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            thumbnailStrip
                .frame(height: thumbnailStripHeight)
        }
        .frame(
            width: effectiveSize.width,
            height: topBarHeight + stageAreaHeight + thumbnailStripHeight
        )
        .fixedSize()
        .animation(.easeInOut(duration: 0.22), value: stageAreaHeight)
        .background(
            RoundedRectangle(cornerRadius: isFullscreen ? 0 : 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.45), radius: 40, y: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: isFullscreen ? 0 : 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.35), PrismTheme.accent.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: isFullscreen ? 0 : 28, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if let asset = currentAsset {
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(selectionIndex + 1) of \(assets.count) · \(asset.pipeline.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            toolbarIconButton(
                "sidebar.right",
                help: showInspector ? "Hide inspector (⌘I)" : "Show inspector (⌘I)",
                prominent: !showInspector
            ) {
                toggleInspector()
            }
            .opacity(isFullscreen ? 0 : 1)
            .disabled(isFullscreen)

            toolbarIconButton(
                isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                help: isFullscreen ? "Exit fullscreen (F)" : "Fullscreen (F)"
            ) {
                toggleFullscreen()
            }

            toolbarIconButton("xmark.circle.fill", help: "Close (Esc)", action: onClose)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var inspectorRevealButton: some View {
        Button(action: { toggleInspector() }) {
            VStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3.weight(.semibold))
                Text("Info")
                    .font(.caption2.weight(.bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.35), radius: 8, x: -2, y: 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(PrismTheme.accent.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 10)
        .padding(.top, 48)
        .prismClickable()
        .help("Show inspector panel")
    }

    private var mainStage: some View {
        ZStack {
            Color.black.opacity(0.35)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            #if os(macOS)
            if let asset = currentAsset, asset.kind == .video {
                PrismVideoPlayer(url: asset.fileURL, isPlaying: $videoPlaying)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(6)
                    .id(asset.id)
            } else if let asset = currentAsset, asset.kind == .audio || asset.kind == .document {
                GalleryInlinePreview(asset: asset, expanded: true)
                    .padding(6)
                    .id(asset.id)
            } else if let displayImage {
                Image(nsImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                    .id(selectionIndex)
                    .padding(6)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
            #else
            ProgressView()
            #endif

            if isLoadingHighRes, currentAsset?.kind != .video {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                            .padding(8)
                            .background(Capsule().fill(.black.opacity(0.5)))
                            .padding(16)
                    }
                }
            }

            VStack {
                HStack {
                    metadataPill
                    Spacer()
                }
                .padding(16)
                Spacer()
            }

            HStack {
                carouselNavControl(direction: .previous)
                Spacer()
                carouselNavControl(direction: .next)
            }
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        #if os(macOS)
        .onTapGesture(count: 2) { toggleFullscreen() }
        #endif
    }

    private var metadataPill: some View {
        Group {
            if let asset = currentAsset {
                let sizeText: String = {
                    if let imagePixelSize {
                        return "\(Int(imagePixelSize.width))×\(Int(imagePixelSize.height))"
                    }
                    return asset.kind.displayName
                }()
                Text("\(sizeText) · \(asset.kind.displayName)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.black.opacity(0.55)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
            }
        }
    }

    private var previewInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let asset = currentAsset {
                    PrismSettingRow(
                        title: "File",
                        icon: "doc",
                        description: "Loaded from this path on disk (source folder until you move/copy to a destination)."
                    ) {
                        EmptyView()
                    } content: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(asset.fileName)
                                .font(.caption.weight(.semibold))
                            Text(asset.fileURL.path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        }
                    }

                    PrismSettingRow(
                        title: "Pipeline",
                        icon: "square.grid.2x2",
                        description: "How Sift classified this item."
                    ) {
                        Text(asset.pipeline.displayName)
                            .font(.caption.weight(.semibold))
                    }

                    PrismSettingRow(title: "Source", icon: "folder") {
                        Text(asset.sourceLabel)
                            .font(.caption)
                            .lineLimit(1)
                    }

                    if let size = imagePixelSize {
                        PrismSettingRow(title: "Dimensions", icon: "viewfinder") {
                            Text("\(Int(size.width)) × \(Int(size.height)) px")
                                .font(.caption.monospacedDigit())
                        }
                    }

                    if asset.faceCount > 0 || asset.pipeline == .people {
                        PrismPersonTagRow(
                            faceCount: max(asset.faceCount, 1),
                            initialName: asset.personDisplayName ?? "",
                            onCommit: onPersonLabelCommit
                        )
                    }

                    if !asset.topCategories.isEmpty {
                        PrismSettingRow(title: "Tags", icon: "tag") {
                            FlowLayout(spacing: 6) {
                                ForEach(asset.topCategories.prefix(8), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(.white.opacity(0.12)))
                                }
                            }
                        }
                    }

                    PrismSettingRow(
                        title: "Actions",
                        icon: "hand.tap",
                        description: "Organize and reveal on disk."
                    ) {
                        EmptyView()
                    } content: {
                        VStack(spacing: 8) {
                            inspectorAction("Show in Finder", icon: "folder") {
                                onRevealInFinder(asset.fileURL)
                            }
                            inspectorAction("Copy path", icon: "doc.on.doc") {
                                onCopyPath(asset.fileURL.path)
                            }
                            if let onMoveToPhotos {
                                inspectorAction("Move to Photos", icon: "photo", action: onMoveToPhotos)
                            }
                            if let onMoveToVideos {
                                inspectorAction("Move to Videos", icon: "film", action: onMoveToVideos)
                            }
                            if let onMoveToGather {
                                inspectorAction("Move to Gather", icon: "tray", action: onMoveToGather)
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(.black.opacity(0.25))
    }

    private var thumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(Array(assets.enumerated()), id: \.element.id) { index, asset in
                        thumbnailCell(asset: asset, index: index)
                            .id(index)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .frame(maxHeight: .infinity)
            .background(.black.opacity(0.35))
            .onChange(of: selectionIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(selectionIndex, anchor: .center)
            }
        }
    }

    private func toolbarIconButton(
        _ systemName: String,
        help: String,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        #if os(macOS)
        .buttonStyle(.borderless)
        #else
        .buttonStyle(.plain)
        #endif
        .help(help)
        .foregroundStyle(prominent ? PrismTheme.accent : Color.primary)
        .prismClickable()
    }

    private func thumbnailCell(asset: MediaAssetSummary, index: Int) -> some View {
        let isSelected = index == selectionIndex
        return Button {
            guard index != selectionIndex else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                selectionIndex = index
            }
        } label: {
            ThumbnailStripTile(asset: asset, size: isSelected ? 72 : 58, allowOriginalFallback: true)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? PrismTheme.accent : .clear, lineWidth: 2)
                }
                .scaleEffect(isSelected ? 1.05 : 1)
                .shadow(color: isSelected ? PrismTheme.accent.opacity(0.4) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .prismClickable()
    }

    private enum CarouselNavDirection {
        case previous, next

        var icon: String {
            switch self {
            case .previous: "arrow.left"
            case .next: "arrow.right"
            }
        }

        var help: String {
            switch self {
            case .previous: "Previous (←)"
            case .next: "Next (→)"
            }
        }
    }

    @ViewBuilder
    private func carouselNavControl(direction: CarouselNavDirection) -> some View {
        let enabled: Bool = {
            switch direction {
            case .previous: selectionIndex > 0
            case .next: selectionIndex < assets.count - 1
            }
        }()
        Button {
            step(direction == .previous ? -1 : 1)
        } label: {
            Image(systemName: direction.icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(enabled ? 0.95 : 0.4))
                .frame(width: 40, height: 64)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(enabled ? 0.45 : 0.15),
                                            PrismTheme.accent.opacity(enabled ? 0.35 : 0.08),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .help(direction.help)
        .prismClickable()
    }

    private func inspectorAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .prismClickable()
    }

    private func toggleInspector() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showInspector.toggle()
        }
    }

    private func toggleFullscreen() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isFullscreen.toggle()
        }
    }

    private func step(_ delta: Int) {
        guard !assets.isEmpty else { return }
        let next = min(max(selectionIndex + delta, 0), assets.count - 1)
        guard next != selectionIndex else { return }
        selectionIndex = next
    }

    private func clampSelection() {
        guard !assets.isEmpty else {
            selectionIndex = 0
            return
        }
        selectionIndex = min(max(selectionIndex, 0), assets.count - 1)
    }

    private func beginMediaAccess() {
        endMediaAccess()
        guard let asset = currentAsset, let root = mediaAccessRoot(asset) else { return }
        if root.startAccessingSecurityScopedResource() {
            scopedAccessURL = root
        }
    }

    private func endMediaAccess() {
        if let scopedAccessURL {
            scopedAccessURL.stopAccessingSecurityScopedResource()
            self.scopedAccessURL = nil
        }
    }

    private func scheduleLoad() {
        let token = UUID()
        loadToken = token
        guard let asset = currentAsset else {
            displayImage = nil
            imagePixelSize = nil
            isLoadingHighRes = false
            return
        }

        if asset.kind == .video {
            displayImage = nil
            isLoadingHighRes = false
            videoPlaying = true
            let url = asset.fileURL
            Task { @MainActor in
                let size = await Task.detached(priority: .utility) {
                    SafeImageLoader.pixelSize(at: url)
                }.value
                if loadToken == token {
                    imagePixelSize = size
                }
            }
            return
        }

        let url = asset.fileURL
        Task { @MainActor in
            let instant = await PreviewImageCache.shared.instantThumbnail(for: asset)
            guard loadToken == token else { return }
            displayImage = instant
            isLoadingHighRes = instant == nil

            let neighbors = neighborAssets(around: selectionIndex)
            #if os(macOS)
            let thumbPaths = ([asset] + neighbors).compactMap(\.thumbnailPath)
            await ThumbnailImageLoader.shared.prefetch(paths: thumbPaths)
            #endif
            await PreviewImageCache.shared.prefetch(neighbors, maxPixelSize: previewMaxPixelSize)

            async let dimensions = Task.detached(priority: .utility) {
                SafeImageLoader.pixelSize(at: url)
            }.value
            async let preview = PreviewImageCache.shared.image(for: asset, maxPixelSize: previewMaxPixelSize)

            if let size = await dimensions, loadToken == token {
                imagePixelSize = size
            }
            let result = await preview
            guard loadToken == token else { return }
            if let image = result.image {
                displayImage = image
                if let size = result.pixelSize { imagePixelSize = size }
            }
            isLoadingHighRes = false
        }
    }

    private func neighborAssets(around index: Int) -> [MediaAssetSummary] {
        var list: [MediaAssetSummary] = []
        if index > 0 { list.append(assets[index - 1]) }
        if index + 1 < assets.count { list.append(assets[index + 1]) }
        if index + 2 < assets.count { list.append(assets[index + 2]) }
        if index - 2 >= 0 { list.append(assets[index - 2]) }
        return list
    }
}

// MARK: - Flow layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

#if os(macOS)
/// Local key monitor so ←/→ work even when a nested control (filmstrip, inspector) has focus.
private struct CarouselKeyboardMonitor: NSViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void
    let onFullscreen: () -> Void
    let onToggleInspector: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.start(
            onLeft: onLeft,
            onRight: onRight,
            onFullscreen: onFullscreen,
            onToggleInspector: onToggleInspector
        )
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.updateHandlers(
            onLeft: onLeft,
            onRight: onRight,
            onFullscreen: onFullscreen,
            onToggleInspector: onToggleInspector
        )
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        private var monitor: Any?
        private var onLeft: (() -> Void)?
        private var onRight: (() -> Void)?
        private var onFullscreen: (() -> Void)?
        private var onToggleInspector: (() -> Void)?

        func start(
            onLeft: @escaping () -> Void,
            onRight: @escaping () -> Void,
            onFullscreen: @escaping () -> Void,
            onToggleInspector: @escaping () -> Void
        ) {
            updateHandlers(
                onLeft: onLeft,
                onRight: onRight,
                onFullscreen: onFullscreen,
                onToggleInspector: onToggleInspector
            )
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                let consumed = self.handleKeyDown(
                    keyCode: event.keyCode,
                    characters: event.charactersIgnoringModifiers?.lowercased(),
                    commandDown: event.modifierFlags.contains(.command)
                )
                return consumed ? nil : event
            }
        }

        func updateHandlers(
            onLeft: @escaping () -> Void,
            onRight: @escaping () -> Void,
            onFullscreen: @escaping () -> Void,
            onToggleInspector: @escaping () -> Void
        ) {
            self.onLeft = onLeft
            self.onRight = onRight
            self.onFullscreen = onFullscreen
            self.onToggleInspector = onToggleInspector
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        /// Local monitors run on the main thread; returns true when the carousel consumed the key.
        private func handleKeyDown(
            keyCode: UInt16,
            characters: String?,
            commandDown: Bool
        ) -> Bool {
            guard let window = NSApp.keyWindow else { return false }

            if let responder = window.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return false
            }

            if let ch = characters {
                switch ch {
                case "f":
                    onFullscreen?()
                    return true
                case "i" where commandDown:
                    onToggleInspector?()
                    return true
                default:
                    break
                }
            }

            switch keyCode {
            case 123:
                onLeft?()
                return true
            case 124:
                onRight?()
                return true
            default:
                return false
            }
        }
    }
}
#endif
