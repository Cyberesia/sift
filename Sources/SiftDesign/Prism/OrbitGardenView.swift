import SiftCore
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// Orbital gallery adapted from Refgarden: drag to turn, scroll to zoom, click to open.
public struct OrbitGardenView: View {
    let assets: [MediaAssetSummary]
    @Binding var directions: Set<VisualDirection>
    let hasMore: Bool
    let onLoadMore: () -> Void
    let onOpen: (MediaAssetSummary) -> Void

    @State private var yaw: Double = -8
    @State private var pitch: Double = -6
    @State private var zoom: Double = 1.35
    @State private var dragYaw: Double = -8
    @State private var dragPitch: Double = -6
    @State private var dragArmed = false
    @State private var cohortStart = 0
    @State private var cohortYawAnchor: Double = -8
    /// Starts tight. The open task waits a beat so the cluster is on screen, then springs out.
    @State private var openness: Double = 0.12
    @State private var openGeneration = 0
    @State private var hoveredAssetID: String?
    private let ringCount = 32

    public init(
        assets: [MediaAssetSummary],
        directions: Binding<Set<VisualDirection>>,
        hasMore: Bool = false,
        onLoadMore: @escaping () -> Void = {},
        onOpen: @escaping (MediaAssetSummary) -> Void
    ) {
        self.assets = assets
        _directions = directions
        self.hasMore = hasMore
        self.onLoadMore = onLoadMore
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Garden")
                        .font(.headline)
                    Text("Scroll or drag to turn · photos change after a three-quarter turn · click to inspect")
                        .font(.caption)
                        .foregroundStyle(PrismTheme.textSecondary)
                }
                Spacer()
                Button {
                    yaw = -8
                    pitch = -6
                    zoom = 1.35
                    openGeneration += 1
                } label: {
                    Label("Refocus", systemImage: "scope")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .prismClickable()
            }
            .padding(.horizontal, 4)
            orbit
            styleRow
        }
        .task(id: openGeneration) {
            openness = 0.12
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }
            openness = 1
        }
    }

    private var filteredAssets: [MediaAssetSummary] {
        assets.filter { asset in
            VisualDirectionFilter.matches(
                fileName: asset.fileName,
                categories: asset.topCategories,
                personName: asset.personDisplayName,
                directions: directions,
                animals: asset.detectedAnimals,
                faceCount: asset.faceCount,
                kind: asset.kind
            )
        }
    }

    private var visibleAssets: [MediaAssetSummary] {
        let pool = filteredAssets
        guard !pool.isEmpty else { return [] }
        if pool.count <= ringCount { return pool }
        let start = positiveModulo(cohortStart, pool.count)
        return (0..<ringCount).map { pool[(start + $0) % pool.count] }
    }

    private var orbit: some View {
        GeometryReader { geo in
            let frame = OrbitLayout.gardenFrame(viewport: geo.size, zoom: zoom)
            let cards = projected(
                radius: frame.x,
                height: geo.size.height,
                yRadius: frame.y,
                spreadSlots: max(visibleAssets.count, 8)
            )
            ZStack {
                ForEach(cards) { card in
                    Button {
                        onOpen(card.asset)
                    } label: {
                        ThumbnailImageView(path: card.asset.thumbnailPath, contentMode: .fill)
                            .frame(width: frame.card.width, height: frame.card.height)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            }
                            .overlay(alignment: .bottom) {
                                Text(GalleryDateLabel.added(card.asset.addedAt))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .frame(maxWidth: .infinity)
                                    .background(.black.opacity(0.5))
                            }
                    }
                    .buttonStyle(.plain)
                    .prismClickable()
                    .brightness(hoveredAssetID == card.asset.id ? 0.08 : 0)
                    .saturation(hoveredAssetID == card.asset.id ? 1.15 : 1)
                    .shadow(
                        color: .black.opacity(hoveredAssetID == card.asset.id ? 0.45 : 0),
                        radius: hoveredAssetID == card.asset.id ? 16 : 0,
                        y: hoveredAssetID == card.asset.id ? 8 : 0
                    )
                    .onHover { inside in
                        if inside {
                            hoveredAssetID = card.asset.id
                        } else if hoveredAssetID == card.asset.id {
                            hoveredAssetID = nil
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.82)),
                            removal: .opacity.combined(with: .scale(scale: 1.12))
                        )
                    )
                    .scaleEffect(card.projection.scale * (hoveredAssetID == card.asset.id ? 1.14 : 1))
                    .opacity(hoveredAssetID == card.asset.id ? 1 : card.projection.opacity)
                    .position(
                        x: geo.size.width / 2 + card.projection.x,
                        y: geo.size.height / 2 + card.projection.y
                    )
                    .zIndex(hoveredAssetID == card.asset.id ? 10_000 : card.projection.depth)
                }
                if visibleAssets.isEmpty {
                    Text(directions.isEmpty ? "Nothing in this view yet." : "No photos match these directions.")
                        .font(.subheadline)
                        .foregroundStyle(PrismTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.62, dampingFraction: 0.86), value: cohortStart)
            .animation(.spring(response: 1.15, dampingFraction: 0.78), value: openness)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: hoveredAssetID)
            .gesture(drag)
            .onChange(of: directions) { _, _ in
                cohortStart = 0
                cohortYawAnchor = yaw
            }
        }
        .background(PrismTheme.dominant.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        #if os(macOS)
        .background {
            OrbitWheelCatcher { deltaX, deltaY, zooming in
                if zooming {
                    zoom = min(2.2, max(0.8, zoom - Double(deltaY) * 0.008))
                } else {
                    yaw += Double(deltaX + deltaY) * 0.45
                    pitch = OrbitLayout.clampPitch(pitch - Double(deltaY) * 0.03)
                    advanceCohortIfNeeded()
                }
            }
        }
        #endif
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !dragArmed {
                    dragArmed = true
                    dragYaw = yaw
                    dragPitch = pitch
                }
                yaw = dragYaw + value.translation.width * 0.19
                pitch = OrbitLayout.clampPitch(dragPitch - value.translation.height * 0.11)
                advanceCohortIfNeeded()
            }
            .onEnded { _ in
                dragArmed = false
                dragYaw = yaw
                dragPitch = pitch
            }
    }

    private struct PlacedCard: Identifiable {
        let asset: MediaAssetSummary
        let projection: OrbitLayout.Projection
        var id: String { asset.id }
    }

    /// A three-quarter turn replaces the ring. Scroll and drag both keep turning, with no edge to hit.
    private func advanceCohortIfNeeded() {
        let pool = filteredAssets.count
        guard pool > ringCount else { return }
        let turned = yaw - cohortYawAnchor
        let steps = Int(turned / metamorphosisDegrees)
        guard steps != 0 else { return }
        let next = cohortStart + steps * ringCount
        if next + ringCount >= pool, hasMore {
            onLoadMore()
        }
        guard next < pool || !hasMore else { return }
        cohortStart = positiveModulo(next, pool)
        cohortYawAnchor += Double(steps) * metamorphosisDegrees
    }

    private let metamorphosisDegrees = 270.0

    private func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        guard modulus > 0 else { return 0 }
        let remainder = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }

    private func projected(radius: Double, height: Double, yRadius: Double, spreadSlots: Int) -> [PlacedCard] {
        visibleAssets.enumerated().map { index, asset in
            PlacedCard(
                asset: asset,
                projection: OrbitLayout.project(
                    slot: index,
                    radius: radius,
                    viewportHeight: height,
                    yawDegrees: yaw,
                    pitchDegrees: pitch,
                    zoom: zoom,
                    spreadSlots: spreadSlots,
                    yRadius: yRadius,
                    spreadScale: openness
                )
            )
        }
        .sorted { $0.projection.depth < $1.projection.depth }
    }

    private var styleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VisualDirection.allCases) { direction in
                    let on = directions.contains(direction)
                    Button {
                        if on {
                            directions.remove(direction)
                        } else {
                            directions.insert(direction)
                        }
                    } label: {
                        Text(direction.label)
                            .font(.caption.weight(on ? .semibold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                Capsule().fill(on ? PrismTheme.accentSoft : PrismTheme.surfaceMuted.opacity(0.8))
                            }
                            .overlay {
                                Capsule().strokeBorder(on ? PrismTheme.accent.opacity(0.7) : PrismTheme.borderSubtle, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .prismClickable()
                    .help(direction.detail)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

#if os(macOS)
private struct OrbitWheelCatcher: NSViewRepresentable {
    var onWheel: (CGFloat, CGFloat, Bool) -> Void

    func makeNSView(context: Context) -> WheelView {
        let view = WheelView()
        view.onWheel = onWheel
        return view
    }

    func updateNSView(_ nsView: WheelView, context: Context) {
        nsView.onWheel = onWheel
    }

    final class WheelView: NSView {
        var onWheel: ((CGFloat, CGFloat, Bool) -> Void)?
        private var monitor: Any?

        override var isOpaque: Bool { false }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window === window else { return event }
                let point = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(point) else { return event }
                let zooming = event.modifierFlags.contains(.option)
                self.onWheel?(event.scrollingDeltaX, event.scrollingDeltaY, zooming)
                return nil
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
#endif
