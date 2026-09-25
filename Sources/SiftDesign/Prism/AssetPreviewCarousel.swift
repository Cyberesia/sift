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
    let onRejectLabel: (String) -> Void

    @State private var displayImage: PlatformPreviewImage?
    @State private var imagePixelSize: CGSize?
    @State private var isLoadingHighRes = false
    @State private var showInspector = true
    @State private var loadToken = UUID()
    @State private var videoPlaying = true
    @State private var scopedAccessURL: URL?
    @State private var stripPosition = ScrollPosition(idType: Int.self)
    @State private var stripProbe = StripScrollProbe()
    /// The asset whose image is currently in `displayImage`, so a later load for it only sharpens it.
    @State private var displayedAssetID: String?
    @State private var stageHovered = false

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
        onPersonLabelCommit: @escaping (String) -> Void = { _ in },
        onRejectLabel: @escaping (String) -> Void = { _ in }
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
        self.onRejectLabel = onRejectLabel
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

    /// Fades run when the photo changes or first appears; the sharp version replaces its thumbnail in place.
    private var stageImageKey: String {
        "\(displayedAssetID ?? "")-\(displayImage != nil)"
    }

    /// The stage keeps one height for every photo, so switching photos never re-lays out the viewer.
    private var stageAreaHeight: CGFloat {
        max(effectiveSize.height - topBarHeight - thumbnailStripHeight, 180)
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
        .background {
            PrismWheelRegion(layer: 10) { _ in .deliver }
        }
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
        .animation(.smooth(duration: 0.24), value: stageAreaHeight)
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
                    .interpolation(.medium)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(6)
                    .id(displayedAssetID ?? "")
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.16)),
                        removal: .opacity.animation(.easeIn(duration: 0.1))
                    ))
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
            .padding(.horizontal, 16)
        }
        .animation(.easeOut(duration: 0.16), value: stageImageKey)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        .onHover { stageHovered = $0 }
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
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(.caption2.weight(.medium))
                                        Button {
                                            onRejectLabel(tag)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 8, weight: .bold))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Remove this label from future suggestions")
                                    }
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
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(Array(assets.enumerated()), id: \.element.id) { index, asset in
                    thumbnailCell(asset: asset, index: index)
                        .id(index)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .scrollPosition($stripPosition)
        .onScrollGeometryChange(for: StripGeometry.self) { geometry in
            StripGeometry(
                offset: geometry.contentOffset.x,
                maxOffset: max(0, geometry.contentSize.width - geometry.containerSize.width)
            )
        } action: { _, geometry in
            stripProbe.offset = geometry.offset
            stripProbe.maxOffset = geometry.maxOffset
        }
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.35))
        #if os(macOS)
        .background {
            PrismWheelRegion(layer: 11) { event in
                scrollStrip(with: event)
            }
        }
        #endif
        .onChange(of: selectionIndex) { _, newIndex in
            withAnimation(.easeInOut(duration: 0.2)) {
                stripPosition.scrollTo(id: newIndex, anchor: .center)
            }
        }
        .onAppear {
            stripPosition.scrollTo(id: selectionIndex, anchor: .center)
        }
    }

    #if os(macOS)
    /// A vertical wheel or swipe scrolls the strip sideways. Horizontal swipes keep the native scrolling.
    private func scrollStrip(with event: NSEvent) -> PrismWheelDecision {
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY
        guard abs(deltaY) > abs(deltaX) else { return .deliver }
        let step = event.hasPreciseScrollingDeltas ? deltaY : deltaY * 12
        let target = min(max(stripProbe.offset - step, 0), stripProbe.maxOffset)
        stripProbe.offset = target
        stripPosition.scrollTo(x: target)
        return .consume
    }
    #endif

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
        .prismClickable()
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
            select(index)
        } label: {
            ThumbnailStripTile(asset: asset, size: 60, allowOriginalFallback: true)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? PrismTheme.accent : .clear, lineWidth: 2)
                }
                .scaleEffect(isSelected ? 1.14 : 1)
                .animation(.easeOut(duration: 0.16), value: isSelected)
        }
        .buttonStyle(.plain)
        .prismClickable()
    }

    private enum CarouselNavDirection {
        case previous, next

        var icon: String {
            switch self {
            case .previous: "chevron.left"
            case .next: "chevron.right"
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 34, height: 34)
                .background(Circle().fill(.black.opacity(stageHovered ? 0.42 : 0.26)))
                .overlay { Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? (stageHovered ? 1 : 0.55) : 0)
        .allowsHitTesting(enabled)
        .animation(.easeOut(duration: 0.18), value: stageHovered)
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
        select(min(max(selectionIndex + delta, 0), assets.count - 1))
    }

    /// Switches photo in one short crossfade. The best cached image is shown in the same frame,
    /// so the fade never runs on the previous photo or an empty stage.
    private func select(_ index: Int) {
        guard index != selectionIndex, assets.indices.contains(index) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            selectionIndex = index
            applyCachedImage(for: assets[index])
        }
    }

    /// Returns true when the full preview was already cached.
    @discardableResult
    private func applyCachedImage(for asset: MediaAssetSummary) -> Bool {
        #if os(macOS)
        guard asset.kind != .video else { return false }
        if let cached = PreviewImageCache.shared.cachedImage(for: asset, maxPixelSize: previewMaxPixelSize) {
            if displayImage !== cached.image { displayImage = cached.image }
            imagePixelSize = cached.pixelSize
            displayedAssetID = asset.id
            return true
        }
        if let path = asset.thumbnailPath, let thumb = ThumbnailImageLoader.shared.cachedImage(at: path) {
            if displayImage !== thumb, displayedAssetID != asset.id { displayImage = thumb }
        } else if displayedAssetID != asset.id {
            displayImage = nil
        }
        if displayedAssetID != asset.id { imagePixelSize = nil }
        displayedAssetID = asset.id
        #endif
        return false
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
            displayedAssetID = nil
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
        let neighbors = neighborAssets(around: selectionIndex)
        if applyCachedImage(for: asset) {
            isLoadingHighRes = false
            prefetchNeighbors(neighbors)
            return
        }
        Task { @MainActor in
            if displayImage == nil {
                let instant = await PreviewImageCache.shared.instantThumbnail(for: asset)
                guard loadToken == token else { return }
                if let instant { displayImage = instant }
            }
            isLoadingHighRes = true

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
            prefetchNeighbors(neighbors)
        }
    }

    /// Neighbours load after the current photo, so they never delay it.
    private func prefetchNeighbors(_ neighbors: [MediaAssetSummary]) {
        let size = previewMaxPixelSize
        Task {
            #if os(macOS)
            await ThumbnailImageLoader.shared.prefetch(paths: neighbors.compactMap(\.thumbnailPath))
            #endif
            await PreviewImageCache.shared.prefetch(neighbors, maxPixelSize: size)
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

private struct StripGeometry: Equatable {
    var offset: CGFloat
    var maxOffset: CGFloat
}

/// Strip scroll offset kept outside SwiftUI state, so scrolling does not re-render the whole viewer.
private final class StripScrollProbe {
    var offset: CGFloat = 0
    var maxOffset: CGFloat = 0
}

// MARK: - Flow layout

struct FlowLayout: Layout {
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
