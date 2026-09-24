import SiftCore
import SwiftUI

#if os(macOS)
import AppKit
#endif

enum GardenStage: String, CaseIterable, Identifiable {
    case orbit
    case spiral
    case depth
    case drift

    var id: String { rawValue }

    var label: String {
        switch self {
        case .orbit: "Orbit"
        case .spiral: "Spiral"
        case .depth: "Depth"
        case .drift: "Drift"
        }
    }

    var caption: String {
        switch self {
        case .orbit:
            "Scroll or drag to turn · photos change after a three-quarter turn · click to inspect"
        case .spiral:
            "Photos rise and grow through the funnel · drag or scroll to move it · click a photo"
        case .depth:
            "Cards recede in depth · drag, scroll, or the arrows · click the front photo"
        case .drift:
            "Columns drift · move the pointer to tilt the wall · click a photo"
        }
    }
}

struct GardenMediaCard: View {
    let asset: MediaAssetSummary
    var corner: CGFloat = 12
    var revealDelay: Double = 0

    /// The card takes the size it is offered; a filled thumbnail is cropped to it instead of overflowing.
    var body: some View {
        Color.clear
            .overlay {
                ThumbnailImageView(path: asset.thumbnailPath, contentMode: .fill, revealDelay: revealDelay)
            }
            .overlay {
                if asset.kind == .video {
                    Image(systemName: "play.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(.black.opacity(0.45)))
                }
            }
            .overlay(alignment: .bottom) {
                if GalleryDateLabel.showsAddedDate(for: asset.kind) {
                    Text(GalleryDateLabel.added(asset.addedAt))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity)
                        .background(.black.opacity(0.5))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
            }
    }
}

/// Width over height for a Garden card, from the thumbnail when it is already cached.
func gardenAspect(_ asset: MediaAssetSummary) -> Double {
    #if os(macOS)
    if let path = asset.thumbnailPath,
       let image = ThumbnailImageLoader.shared.cachedImage(at: path),
       image.size.width > 0, image.size.height > 0 {
        return gardenClamp(Double(image.size.width / image.size.height), 0.6, 1.8)
    }
    #endif
    let ratio = Double(asset.aspectRatio)
    return ratio > 0 ? gardenClamp(ratio, 0.6, 1.8) : 1
}

// MARK: - Spiral

struct GardenSpiralView: View {
    let assets: [MediaAssetSummary]
    var hasMore: Bool = false
    var onLoadMore: () -> Void = {}
    var onHover: (MediaAssetSummary?) -> Void = { _ in }
    let onOpen: (MediaAssetSummary) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Drawn position. It follows `target` with an exponential ease, like the original render loop.
    @State private var progress: Double = 0
    @State private var target: Double = 0
    @State private var autoSpeed: Double = 0
    @State private var hovering = false
    @State private var dragging = false
    @State private var dragDistance: CGFloat = 0
    @State private var suppressOpenUntil: Date?
    @State private var hoveredSlot: Int?

    private let speed = 0.55
    private let vortex = TornadoLayout()

    var body: some View {
        GeometryReader { geo in
            let unit = vortex.unitSize(for: geo.size)
            ZStack {
                if assets.isEmpty {
                    gardenEmpty
                } else {
                    ForEach(spiralItems) { item in
                        let placed = item.halo
                            ? vortex.placeHalo(rise: item.rise, unit: unit)
                            : vortex.place(rise: item.rise, start: item.start, unit: unit, in: geo.size)
                        let aspect = gardenAspect(item.asset)
                        // At the focus a portrait takes the full card width, like a landscape photo.
                        let fitsWidth = aspect >= placed.side / placed.height
                        let fittedWidth = fitsWidth ? placed.side : placed.height * aspect
                        let width = fittedWidth + (placed.side - fittedWidth) * placed.focus
                        let height = width / aspect
                        let fittedHeight = fitsWidth ? placed.side / aspect : placed.height
                        Button {
                            open(item.asset)
                        } label: {
                            GardenMediaCard(
                                asset: item.asset,
                                corner: 10,
                                revealDelay: min(abs(vortex.focus - item.rise), 12) * 0.04
                            )
                            .frame(width: width, height: height)
                        }
                        .buttonStyle(.plain)
                        .prismClickable()
                        .onHover { inside in
                            hover(slot: item.id, asset: item.asset, inside: inside)
                        }
                        .scaleEffect(
                            fittedZoom(placed.zoom, height: height, top: geo.size.height / 2 + placed.y - fittedHeight / 2, stage: geo.size.height),
                            anchor: .top
                        )
                        .shadow(color: Color(red: 0.03, green: 0.024, blue: 0.07).opacity(0.35 * placed.opacity), radius: 16, y: 10)
                        .blur(radius: placed.blur)
                        .opacity(placed.opacity)
                        .position(
                            x: geo.size.width / 2 + placed.x,
                            y: geo.size.height / 2 + placed.y + (height - fittedHeight) / 2
                        )
                        .zIndex(placed.depth + Double(item.id % 1000) * 0.001)
                        .allowsHitTesting(placed.opacity > 0.25)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .drawingGroup()
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .gesture(spiralDrag)
        }
        .background(PrismTheme.dominant.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background {
            GardenClock(paused: isAtRest) { delta in
                tick(delta)
            }
        }
        .onChange(of: Int(progress)) { _, value in
            requestMoreIfNeeded(origin: value)
        }
        #if os(macOS)
        .background {
            GardenWheelCatcher { deltaY in
                let step = Double(deltaY) / 120
                target -= gardenClamp(step, -1.5, 1.5)
            }
        }
        #endif
    }

    private var motionPaused: Bool {
        reduceMotion || dragging || hovering
    }

    /// The zoomed card grows downward from its top and always stays inside the stage.
    private func fittedZoom(_ zoom: Double, height: Double, top: Double, stage: CGFloat) -> Double {
        guard zoom > 1, height > 0 else { return zoom }
        let room = Double(stage) - 10 - max(top, 0)
        return max(1, min(zoom, room / height))
    }

    /// The clock stops only once the motion has eased out completely.
    private var isAtRest: Bool {
        motionPaused && abs(autoSpeed) < 0.0005 && abs(target - progress) < 0.0005
    }

    /// Automatic speed eases toward its goal, and the drawn position eases toward the target.
    /// Hovering therefore glides to a stop instead of freezing.
    private func tick(_ delta: Double) {
        let desired = motionPaused ? 0 : speed
        autoSpeed += (desired - autoSpeed) * (1 - exp(-delta * 7))
        target += autoSpeed * delta
        let follow = 1 - exp(-delta * (dragging ? 22 : 11))
        progress += (target - progress) * follow
    }

    /// Dragging up lifts the cards up the funnel.
    private var spiralDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if !dragging {
                    target = progress
                }
                let delta = value.translation.height - dragDistance
                target -= Double(delta) / 70
                dragging = true
                dragDistance = value.translation.height
            }
            .onEnded { value in
                if abs(value.translation.height) > 8 {
                    suppressOpenUntil = Date().addingTimeInterval(0.2)
                }
                dragging = false
                dragDistance = 0
            }
    }

    private func hover(slot: Int, asset: MediaAssetSummary, inside: Bool) {
        if inside {
            hoveredSlot = slot
            onHover(asset)
        } else if hoveredSlot == slot {
            hoveredSlot = nil
            onHover(nil)
        }
    }

    private func open(_ asset: MediaAssetSummary) {
        if let until = suppressOpenUntil, until > Date() { return }
        onOpen(asset)
    }

    private func requestMoreIfNeeded(origin: Int) {
        let total = assets.count
        guard hasMore, total > 0 else { return }
        if gardenMod(origin, total) > total - 24 {
            onLoadMore()
        }
    }

    /// Each card keeps its photo; only its rise along the funnel changes, so thumbnails are never reassigned.
    /// A small library loops once through the top of the funnel. A large one draws a window of slots.
    private var spiralItems: [SpiralItem] {
        let n = assets.count
        guard n > 0 else { return [] }
        if n == 1 {
            return [SpiralItem(id: 0, asset: assets[0], rise: vortex.focus, start: vortex.entry)]
        }
        let span = vortex.exit - vortex.entry
        if Double(n) < span {
            let start = vortex.exit - Double(n)
            return assets.enumerated().map { index, asset in
                let raw = progress - Double(index)
                let rise = vortex.exit - gardenModulo(vortex.exit - raw, Double(n))
                return SpiralItem(id: index, asset: asset, rise: rise, start: start)
            }
        }
        let base = Int(floor(progress))
        let low = base - Int(ceil(vortex.exit)) - 1
        let high = base - Int(floor(vortex.entry)) + 1
        let funnel = (low...high).map { slot in
            SpiralItem(
                id: slot,
                asset: assets[gardenMod(slot, n)],
                rise: progress - Double(slot),
                start: vortex.entry
            )
        }
        return funnel + haloItems(count: n, base: base)
    }

    /// The halo shows photos from the other half of the library, so it never repeats the funnel.
    private func haloItems(count n: Int, base: Int) -> [SpiralItem] {
        guard n > Int(vortex.exit - vortex.entry) + 8 else { return [] }
        let reach = Int(ceil(vortex.haloSpan)) + 2
        let center = base - Int(vortex.focus.rounded())
        return ((center - reach)...(center + reach)).map { slot in
            SpiralItem(
                id: SpiralItem.haloIDOffset + slot,
                asset: assets[gardenMod(slot + n / 2, n)],
                rise: progress - Double(slot),
                start: vortex.focus - vortex.haloSpan - 1,
                halo: true
            )
        }
    }
}

/// A funnel: cards enter small and blurred at the bottom and grow steadily as they climb a widening helix.
/// Only the card at the focus, at the lower edge of the top third, is sharp; it zooms in smoothly as it
/// arrives. Above it the cards shrink while the funnel keeps widening, so the top holds more photos per turn.
/// The climb is steep where the helix turns sideways and gentle at the front and back, where neighbours
/// are already apart. Everything is a smooth function of the position, so the motion never jerks.
private struct TornadoLayout {
    /// Positions along the funnel, counted upward. Cards appear at `entry` and are gone at `exit`.
    let entry = -11.0
    let exit = 12.0
    /// The sharpest card.
    var focus: Double { exit - 7 }
    /// Size multiplier per position below the focus, and above it.
    let growth = 1.11
    let shrink = 0.9
    /// Extra widening per position above the focus.
    let spread = 1.05
    /// Helix radius at the focus, as a share of the card width.
    let radius = 2.6
    let cardsPerTurn = 5.0
    /// Zoom of the card in focus, and how many positions it lasts.
    let focusZoom = 0.75
    let zoomWidth = 0.9
    /// Card height as a share of its width budget. Portraits are fitted inside the same box.
    let boxHeight = 0.72
    /// Extra drawing scale for the card in focus, and how many positions the zoom lasts.
    let highlightZoom = 1.25
    let highlightWidth = 0.55
    /// Climb per position as a share of the card size: `flatPitch` at the front and back, plus `sidePitch` at the sides.
    let flatPitch = 0.15
    let sidePitch = 1.0

    private struct Tables {
        let start: Double
        let step: Double
        let angle: [Double]
        let x: [Double]
        let perspective: [Double]
        let lift: [Double]
        let top: Double
        let bottom: Double
        let width: Double
    }

    private static let tables = TornadoLayout().buildTables()

    private func baseSize(_ rise: Double) -> Double {
        rise < focus ? pow(growth, rise - focus) : pow(shrink, rise - focus)
    }

    private func relativeSize(_ rise: Double) -> Double {
        let offset = (rise - focus) / zoomWidth
        return baseSize(rise) * (1 + focusZoom * exp(-offset * offset))
    }

    private func helixRadius(_ rise: Double) -> Double {
        radius * pow(growth, rise - focus) * pow(spread, max(0, rise - focus))
    }

    private func buildTables() -> Tables {
        let step = 0.01
        let start = entry - 3
        let count = Int((exit + 2 - start) / step) + 1
        let rises = (0..<count).map { start + Double($0) * step }

        // Constant spacing along each row: where the funnel is wide relative to the cards, more cards fit per turn.
        var angle = [Double](repeating: 0, count: count)
        for i in 1..<count {
            let rise = rises[i]
            let ratio = radius / (helixRadius(rise) / baseSize(rise))
            angle[i] = angle[i - 1] + step * (2 * .pi / cardsPerTurn) * gardenClamp(ratio, 0.35, 1.8)
        }
        let focusAngle = angle[Int((focus - start) / step)]
        angle = angle.map { $0 - focusAngle }

        let x = (0..<count).map { helixRadius(rises[$0]) * sin(angle[$0]) }
        let perspective = angle.map { 1 + 0.1 * cos($0) }

        var lift = [Double](repeating: 0, count: count)
        for i in 1..<count {
            let sideways = sin(angle[i]) * sin(angle[i])
            lift[i] = lift[i - 1] + step * relativeSize(rises[i]) * (flatPitch + sidePitch * sideways)
        }

        func sample(_ values: [Double], _ rise: Double) -> Double {
            let position = (rise - start) / step
            let index = min(max(Int(position), 0), count - 2)
            let fraction = gardenClamp(position - Double(index), 0, 1)
            return values[index] + (values[index + 1] - values[index]) * fraction
        }
        let top = sample(lift, exit - 1) + relativeSize(exit - 1) * boxHeight / 2
        let bottom = sample(lift, entry + 1) - relativeSize(entry + 1) * boxHeight / 2
        let width = stride(from: exit - 5, through: exit - 1, by: 0.1)
            .map { abs(sample(x, $0)) + relativeSize($0) * 0.55 }
            .max() ?? 1
        return Tables(
            start: start, step: step, angle: angle, x: x, perspective: perspective, lift: lift,
            top: top, bottom: bottom, width: width
        )
    }

    private func sample(_ values: [Double], _ rise: Double) -> Double {
        let tables = Self.tables
        let position = (rise - tables.start) / tables.step
        let index = min(max(Int(position), 0), values.count - 2)
        let fraction = gardenClamp(position - Double(index), 0, 1)
        return values[index] + (values[index + 1] - values[index]) * fraction
    }

    /// Card width at the focus, before its zoom, chosen so the visible funnel fits the stage.
    func unitSize(for size: CGSize) -> Double {
        let tables = Self.tables
        let byHeight = Double(size.height) / max(tables.top - tables.bottom, 0.1)
        let byWidth = Double(size.width) * 0.49 / max(tables.width, 0.1)
        return max(16, min(byHeight, byWidth, 110))
    }

    /// The halo turns around the sharp band, wider than the funnel and behind all of it.
    /// Its cards blur more the further they are from the center, and may pass behind the sharp card.
    let haloSpan = 3.5
    let haloRadius = 1.2
    let haloSize = 0.75
    let haloClimb = 0.3
    let haloCardsPerTurn = 7.0

    func placeHalo(rise: Double, unit: Double) -> TornadoPlacement {
        let tables = Self.tables
        let offset = rise - focus
        let angle = offset * (2 * .pi / haloCardsPerTurn) + .pi / haloCardsPerTurn
        let front = cos(angle)
        let ring = haloRadius * radius * unit
        let x = sin(angle) * ring
        let focusLift = sample(tables.lift, focus) - (tables.top + tables.bottom) / 2
        let y = -(focusLift + offset * haloClimb) * unit
        let side = haloSize * unit * (1 + 0.12 * front)
        let back = (1 - front) / 2
        let fade = gardenSmoothstep(focus - haloSpan - 1, focus - haloSpan + 0.2, rise)
            * (1 - gardenSmoothstep(focus + haloSpan - 0.2, focus + haloSpan + 1, rise))
        return TornadoPlacement(
            x: x,
            y: y,
            side: side,
            height: side * boxHeight,
            opacity: fade * (0.75 - 0.25 * back),
            blur: 2.5 + 4 * gardenSmoothstep(0, 1, abs(x) / max(ring, 1)) + 3 * back,
            depth: -2000 + ((front + 1) / 2 * 1000).rounded(),
            zoom: 1,
            focus: 0
        )
    }

    func place(rise: Double, start: Double, unit: Double, in size: CGSize) -> TornadoPlacement {
        let tables = Self.tables
        let angle = sample(tables.angle, rise)
        let front = cos(angle)
        let side = unit * relativeSize(rise) * sample(tables.perspective, rise)
        let x = sample(tables.x, rise) * unit
        let y = -(sample(tables.lift, rise) - (tables.top + tables.bottom) / 2) * unit

        // 0 at the front of the helix, 1 at the back.
        let back = (1 - front) / 2
        let fadeIn = gardenSmoothstep(start, start + 1.2, rise)
        let fadeOut = 1 - gardenSmoothstep(exit - 1.2, exit, rise)
        // Sharp only at the focus; the blur grows a little with every position away from it.
        let fromFocus = rise - focus
        let blur = (fromFocus < 0 ? 6 * gardenSmoothstep(0, 4, -fromFocus) : 5 * gardenSmoothstep(0, 3.5, fromFocus))
            + 3 * pow(back, 1.4)

        // Drawn larger only; the layout keeps its size, so the neighbours do not move.
        let nearFocus = exp(-pow(fromFocus / highlightWidth, 2))

        return TornadoPlacement(
            x: x,
            y: y,
            side: side,
            height: side * boxHeight,
            opacity: fadeIn * fadeOut * (1 - 0.3 * back),
            blur: blur,
            depth: ((front + 1) / 2 * 1000).rounded() + (nearFocus * 2000).rounded(),
            zoom: 1 + highlightZoom * nearFocus,
            focus: nearFocus
        )
    }
}

private struct TornadoPlacement {
    let x: Double
    let y: Double
    /// Width budget of the card.
    let side: Double
    /// Height budget of the card.
    let height: Double
    let opacity: Double
    let blur: Double
    let depth: Double
    /// Drawing scale on top of the layout size.
    let zoom: Double
    /// 1 at the focus, fading to 0 around it.
    let focus: Double
}

private struct SpiralItem: Identifiable {
    let id: Int
    let asset: MediaAssetSummary
    /// Position along the funnel, counted upward.
    let rise: Double
    /// Where this card fades in. The bottom of the funnel, or higher for a small library.
    let start: Double
    /// A card of the wider blurred ring that turns behind the sharp band.
    var halo = false

    static let haloIDOffset = 1_000_000
}

// MARK: - Depth

struct GardenDepthView: View {
    let assets: [MediaAssetSummary]
    var hasMore: Bool = false
    var onLoadMore: () -> Void = {}
    var onHover: (MediaAssetSummary?) -> Void = { _ in }
    let onOpen: (MediaAssetSummary) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Unbounded rail position. Slot k always shows assets[k mod n], so each card keeps its identity while it travels.
    @State private var position: Double = 0
    @State private var dragStart: Double?
    @State private var hovering = false
    @State private var suppressOpenUntil: Date?
    @State private var wheelGeneration = 0
    @State private var hoveredSlot: Int?

    private let rail = DepthRail.Config()
    private let duration = 1.0
    private let autoplaySeconds = 4.2

    var body: some View {
        GeometryReader { geo in
            let n = assets.count
            let scale = rail.fitScale(for: geo.size)
            ZStack {
                if n == 0 {
                    gardenEmpty
                } else {
                    ForEach(slotRange(count: n), id: \.self) { slot in
                        let asset = assets[gardenMod(slot, n)]
                        Button {
                            tap(slot: slot, asset: asset)
                        } label: {
                            GardenMediaCard(
                                asset: asset,
                                corner: rail.radius,
                                revealDelay: max(0, Double(slot) - position) * 0.09
                            )
                            .frame(
                                width: rail.cardHeight * CGFloat(min(gardenAspect(asset), 1.6)),
                                height: rail.cardHeight
                            )
                        }
                        .buttonStyle(.plain)
                        .prismClickable()
                        .onHover { inside in
                            if inside {
                                hoveredSlot = slot
                                onHover(asset)
                            } else if hoveredSlot == slot {
                                hoveredSlot = nil
                                onHover(nil)
                            }
                        }
                        .modifier(DepthRail(position: position, slot: slot, scale: scale, config: rail))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(drag(scale: scale))
            .onHover { hovering = $0 }
            .overlay {
                if n > 1 {
                    depthControls(count: n)
                }
            }
        }
        .background(PrismTheme.dominant.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .task(id: autoplayID) {
            guard !reduceMotion, assets.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(autoplaySeconds))
                guard !Task.isCancelled, !hovering, dragStart == nil else { continue }
                nudge(1)
            }
        }
        .onChange(of: Int(position.rounded())) { _, value in
            let n = assets.count
            guard hasMore, n > 0, gardenMod(value, n) > n - 6 else { return }
            onLoadMore()
        }
        #if os(macOS)
        .background {
            GardenWheelCatcher { deltaY in
                guard assets.count > 1, deltaY != 0 else { return }
                let step = gardenClamp(-Double(deltaY) / Double(rail.cardWidth * 2.4), -0.25, 0.25)
                place(position + step)
                wheelGeneration += 1
                let token = wheelGeneration
                Task {
                    try? await Task.sleep(for: .milliseconds(130))
                    guard token == wheelGeneration else { return }
                    settle(to: Int(position.rounded()))
                }
            }
        }
        #endif
    }

    private func slotRange(count: Int) -> ClosedRange<Int> {
        guard count > 1 else { return 0...0 }
        let base = Int(floor(position))
        return (base - 1)...(base + rail.visibleCards + 1)
    }

    private var autoplayID: String {
        "\(assets.count)-\(hovering)-\(reduceMotion)"
    }

    /// One pill under the stack: small arrows on its sides, a sliding window of dots, and the position.
    private func depthControls(count: Int) -> some View {
        let base = Int(position.rounded())
        let compact = count <= 7
        let dots = compact ? Array(0..<count) : Array((base - 3)...(base + 3))
        return VStack {
            Spacer()
            HStack(spacing: 6) {
                depthArrow("chevron.left", help: "Previous") { nudge(-1) }
                HStack(spacing: 6) {
                    ForEach(dots, id: \.self) { dot in
                        let active = compact ? dot == activeIndex(count) : dot == base
                        let size: CGFloat = !compact && abs(dot - base) >= 3 ? 4 : 6
                        Capsule()
                            .fill(Color.white.opacity(active ? 0.95 : 0.38))
                            .frame(width: active ? 18 : size, height: active ? 6 : size)
                            .frame(height: 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if compact {
                                    focus(index: dot, count: count)
                                } else {
                                    settle(to: dot)
                                }
                            }
                            .prismClickable()
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.36, dampingFraction: 0.82), value: base)
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 1, height: 12)
                    .padding(.horizontal, 2)
                Text("\(activeIndex(count) + 1) / \(count)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.82))
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.25), value: base)
                depthArrow("chevron.right", help: "Next") { nudge(1) }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(.black.opacity(0.42), in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1) }
            .padding(.bottom, 14)
        }
    }

    private func depthArrow(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .prismClickable()
        .help(help)
    }

    private func drag(scale: Double) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard assets.count > 1 else { return }
                let start = dragStart ?? position
                dragStart = start
                place(start - Double(value.translation.width) / stepPixels(scale))
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                dragStart = nil
                if abs(value.translation.width) > 6 {
                    suppressOpenUntil = Date().addingTimeInterval(0.25)
                }
                let fling = Double(value.predictedEndTranslation.width - value.translation.width) * 0.35
                let travelled = Double(value.translation.width) + fling
                settle(to: Int((start - travelled / stepPixels(scale)).rounded()))
            }
    }

    /// Pixels of drag for one card. Larger than the original so the rail moves more slowly.
    private func stepPixels(_ scale: Double) -> Double {
        max(Double(rail.cardWidth) * 0.9 * scale, 60)
    }

    private func tap(slot: Int, asset: MediaAssetSummary) {
        if let until = suppressOpenUntil, until > Date() { return }
        if slot == Int(position.rounded()) {
            onOpen(asset)
        } else {
            settle(to: slot)
        }
    }

    private func activeIndex(_ count: Int) -> Int {
        gardenMod(Int(position.rounded()), count)
    }

    private func nudge(_ delta: Int) {
        guard delta != 0 else { return }
        settle(to: Int(position.rounded()) + delta)
    }

    private func focus(index: Int, count: Int) {
        let base = Int(position.rounded())
        var delta = index - gardenMod(base, count)
        if delta > count / 2 { delta -= count }
        if delta < -count / 2 { delta += count }
        settle(to: base + delta)
    }

    private func place(_ value: Double) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            position = value
        }
    }

    private func settle(to slot: Int) {
        guard !assets.isEmpty else { return }
        withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: reduceMotion ? 0 : duration)) {
            position = Double(slot)
        }
    }
}

/// The DepthCarousel layout, evaluated on every animation frame from the interpolated rail position.
private struct DepthRail: ViewModifier, Animatable {
    struct Config {
        let cardWidth: CGFloat = 300
        let cardHeight: CGFloat = 380
        let radius: CGFloat = 18
        let depth: Double = 220
        let spread: Double = 90
        let tilt: Double = 22
        let perspective: Double = 1400
        let visibleCards = 4
        let falloff: Double = 0.2
        let blur: Double = 6

        func fitScale(for size: CGSize) -> Double {
            let byWidth = Double(size.width) / (Double(cardWidth) + spread * 2 + 120)
            let byHeight = Double(size.height) / (Double(cardHeight) + 110)
            return gardenClamp(min(byWidth, byHeight), 0.4, 1)
        }
    }

    var position: Double
    let slot: Int
    let scale: Double
    let config: Config

    nonisolated var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    func body(content: Content) -> some View {
        let d = Double(slot) - position
        let back = max(0, d)
        let shown = abs(d) <= Double(config.visibleCards) + 0.5
        let opacity = shown ? (d < 0 ? max(0, 1 + d) : 1) : 0
        let brightness = max(0.15, 1 - back * config.falloff)
        let blur = min(config.blur, back / Double(max(1, config.visibleCards)) * config.blur)
        let tz = -config.depth * d
        let projection = config.perspective / max(config.perspective - tz, 1)
        let tint = gardenClamp(back * config.falloff * 1.25, 0, 0.86)
        return content
            .overlay {
                RoundedRectangle(cornerRadius: config.radius, style: .continuous)
                    .fill(Color(red: 0.02, green: 0.024, blue: 0.04).opacity(tint))
                    .allowsHitTesting(false)
            }
            .colorMultiply(Color(white: brightness))
            .shadow(color: .black.opacity(0.5 * opacity), radius: 26, y: 18)
            .rotation3DEffect(
                .degrees(config.tilt * gardenClamp(d, 0, 1)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.6
            )
            .scaleEffect(scale * projection)
            .offset(x: config.spread * d * scale * projection)
            .blur(radius: blur)
            .opacity(opacity)
            .zIndex(2000 - d * 20)
            .allowsHitTesting(opacity > 0.05)
    }
}

// MARK: - Drift

struct GardenDriftView: View {
    let assets: [MediaAssetSummary]
    var hasMore: Bool = false
    var onLoadMore: () -> Void = {}
    var onHover: (MediaAssetSummary?) -> Void = { _ in }
    let onOpen: (MediaAssetSummary) -> Void

    var body: some View {
        Group {
            if assets.isEmpty {
                gardenEmpty
            } else {
                DriftWallCanvas(assets: Array(assets.prefix(40)), onHover: onHover, onOpen: onOpen)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PrismTheme.dominant.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onAppear {
            if hasMore { onLoadMore() }
        }
    }
}

#if os(macOS)
/// Columns move by layer translation only. The photos are not rebuilt each frame.
private struct DriftWallCanvas: NSViewRepresentable {
    var assets: [MediaAssetSummary]
    var onHover: (MediaAssetSummary?) -> Void
    var onOpen: (MediaAssetSummary) -> Void

    func makeNSView(context: Context) -> DriftWallNSView {
        let view = DriftWallNSView()
        view.onOpen = onOpen
        view.onHover = onHover
        view.setAssets(assets)
        return view
    }

    func updateNSView(_ nsView: DriftWallNSView, context: Context) {
        nsView.onOpen = onOpen
        nsView.onHover = onHover
        nsView.setAssets(assets)
    }
}

private final class DriftWallNSView: NSView {
    var onOpen: ((MediaAssetSummary) -> Void)?
    var onHover: ((MediaAssetSummary?) -> Void)?
    private var assets: [MediaAssetSummary] = []
    private var assetIDs: [String] = []
    private var columns: [DriftColumn] = []
    private var laidOutSize: CGSize = .zero
    private var pointer = CGPoint.zero
    private var hoveredColumn = -1
    private weak var hoveredTile: CALayer?
    private var lastPointerPoint: CGPoint?
    /// Tiles keep drifting under a still pointer, so the hovered tile is checked again on a short timer.
    private var hoverTimer: Timer?
    private let plane = CALayer()
    private let fadeMask = CAGradientLayer()
    private let columnCount = 5
    private let tileWidth: CGFloat = 200
    private let tileHeight: CGFloat = 132
    private let gap: CGFloat = 18

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        layer?.masksToBounds = true
        plane.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer?.addSublayer(plane)
        fadeMask.colors = [
            NSColor.clear.cgColor,
            NSColor.black.cgColor,
            NSColor.black.cgColor,
            NSColor.clear.cgColor
        ]
        fadeMask.locations = [0, 0.14, 0.86, 1]
        fadeMask.startPoint = CGPoint(x: 0.5, y: 0)
        fadeMask.endPoint = CGPoint(x: 0.5, y: 1)
        layer?.mask = fadeMask
    }

    required init?(coder: NSCoder) { nil }

    func setAssets(_ next: [MediaAssetSummary]) {
        let ids = next.map(\.id)
        guard ids != assetIDs else { return }
        assets = next
        assetIDs = ids
        laidOutSize = .zero
        needsLayout = true
    }

    override func layout() {
        super.layout()
        fadeMask.frame = bounds
        guard bounds.width > 1, bounds.height > 1 else { return }
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        rebuild()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else {
            stopHoverTimer()
            return
        }
        updateTrackingAreas()
        startColumnAnimations()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        pointer = CGPoint(
            x: point.x / max(bounds.width, 1) - 0.5,
            y: point.y / max(bounds.height, 1) - 0.5
        )
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.24)
        plane.transform = planeTransform(
            tilt: 16 - pointer.y * 4.8,
            turn: -14 + pointer.x * 4.8
        )
        CATransaction.commit()
        lastPointerPoint = point
        startHoverTimer()
        refreshHover()
    }

    @objc private func refreshHover() {
        guard let point = lastPointerPoint else { return }
        let hit = layer?.presentation()?.hitTest(point) ?? layer?.hitTest(point)
        let tile = tileLayer(from: hit)
        guard tile !== hoveredTile else { return }
        setHovered(tile)
    }

    private func startHoverTimer() {
        guard hoverTimer == nil else { return }
        let timer = Timer(timeInterval: 0.12, target: self, selector: #selector(refreshHover), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func stopHoverTimer() {
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    override func mouseExited(with event: NSEvent) {
        lastPointerPoint = nil
        stopHoverTimer()
        pointer = .zero
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.36)
        plane.transform = planeTransform(tilt: 16, turn: -14)
        CATransaction.commit()
        setHovered(nil)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let hit = layer?.presentation()?.hitTest(point) ?? layer?.hitTest(point)
        guard let tile = tileLayer(from: hit),
              let id = tile.name,
              let asset = assets.first(where: { $0.id == id }) else { return }
        onOpen?(asset)
    }

    private func rebuild() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        columns.forEach { $0.clip.removeFromSuperlayer() }
        columns.removeAll()
        hoveredTile = nil
        hoveredColumn = -1

        var perspective = CATransform3DIdentity
        perspective.m34 = -1.0 / 1200
        layer?.sublayerTransform = perspective
        plane.frame = bounds
        plane.position = CGPoint(x: bounds.midX, y: bounds.midY)

        let pool = assets
        let totalWidth = CGFloat(columnCount) * tileWidth + CGFloat(columnCount - 1) * gap
        let originX = (bounds.width - totalWidth) / 2
        let unit = tileHeight + gap

        for index in 0..<columnCount {
            var items = stride(from: index, to: pool.count, by: columnCount).map { pool[$0] }
            if items.isEmpty, let first = pool.first { items = [first] }
            let count = max(items.count, 1)
            let copyHeight = unit * CGFloat(count)
            let copies = max(2, Int(ceil((bounds.height * 1.6) / copyHeight)) + 1)
            let column = DriftColumn(index: index)
            column.copyHeight = copyHeight
            column.baseSpeed = columnSpeed(index)
            column.offset = copyHeight * CGFloat((Double(index) * 0.37).truncatingRemainder(dividingBy: 1))
            column.clip.frame = CGRect(
                x: originX + CGFloat(index) * (tileWidth + gap),
                y: 0,
                width: tileWidth,
                height: bounds.height
            )
            column.clip.masksToBounds = true
            column.track.frame = CGRect(x: 0, y: 0, width: tileWidth, height: copyHeight * CGFloat(copies))
            column.clip.addSublayer(column.track)
            plane.addSublayer(column.clip)

            for copy in 0..<copies {
                for (itemIndex, asset) in items.enumerated() {
                    let slot = copy * count + itemIndex
                    let order = abs(index - columnCount / 2) + slot
                    let tile = makeTile(asset, column: index, revealDelay: min(Double(order) * 0.05, 1.2))
                    tile.frame = CGRect(x: 0, y: CGFloat(slot) * unit, width: tileWidth, height: tileHeight)
                    column.track.addSublayer(tile)
                }
            }
            columns.append(column)
        }
        plane.transform = planeTransform(tilt: 16, turn: -14)
        CATransaction.commit()
        startColumnAnimations()
    }

    /// Core Animation moves only the tracks. It does not rebuild or decode any photo per frame.
    private func startColumnAnimations() {
        guard window != nil else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for column in columns {
            column.track.removeAnimation(forKey: "drift")
            guard !reduceMotion else {
                column.track.setAffineTransform(
                    CGAffineTransform(translationX: 0, y: -column.offset)
                )
                continue
            }

            let upward = column.baseSpeed >= 0
            let from = upward
                ? -column.offset
                : -(column.copyHeight + column.offset)
            let to = upward
                ? -(column.copyHeight + column.offset)
                : -column.offset
            column.track.setAffineTransform(
                CGAffineTransform(translationX: 0, y: from)
            )

            let animation = CABasicAnimation(keyPath: "transform.translation.y")
            animation.fromValue = from
            animation.toValue = to
            animation.duration = CFTimeInterval(
                column.copyHeight / max(abs(column.baseSpeed), 1)
            )
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            column.track.add(animation, forKey: "drift")
        }
        CATransaction.commit()
    }

    private func makeTile(_ asset: MediaAssetSummary, column: Int, revealDelay: Double) -> CALayer {
        let tile = CALayer()
        tile.name = asset.id
        tile.setValue(column, forKey: "driftColumn")
        tile.backgroundColor = NSColor(calibratedWhite: 0.05, alpha: 1).cgColor
        tile.cornerRadius = 14
        tile.masksToBounds = true
        tile.contentsScale = window?.backingScaleFactor ?? 2

        let image = CALayer()
        image.frame = CGRect(x: 0, y: 0, width: tileWidth, height: tileHeight)
        image.contentsGravity = .resizeAspectFill
        image.masksToBounds = true
        image.contentsScale = tile.contentsScale
        tile.addSublayer(image)

        let veil = CALayer()
        veil.name = "veil"
        veil.frame = image.frame
        veil.backgroundColor = NSColor(calibratedRed: 0.024, green: 0, blue: 0.063, alpha: 1).cgColor
        veil.opacity = 0.42
        tile.addSublayer(veil)
        tile.opacity = 0.55

        if let path = asset.thumbnailPath {
            if let cached = ThumbnailImageLoader.shared.cachedImage(at: path) {
                image.contents = cached.cgImage(forProposedRect: nil, context: nil, hints: nil)
            } else {
                Task {
                    if revealDelay > 0 {
                        try? await Task.sleep(for: .seconds(revealDelay))
                    }
                    let priority: TaskPriority = revealDelay == 0 ? .userInitiated : .utility
                    let loaded = await ThumbnailImageLoader.shared.image(at: path, priority: priority)
                    let contents = loaded?.cgImage(forProposedRect: nil, context: nil, hints: nil)
                    await MainActor.run {
                        let fade = CATransition()
                        fade.type = .fade
                        fade.duration = 0.32
                        image.add(fade, forKey: "reveal")
                        image.contents = contents
                    }
                }
            }
        }
        return tile
    }

    override func cursorUpdate(with event: NSEvent) {
        if hoveredTile != nil {
            NSCursor.pointingHand.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    private func tileLayer(from hit: CALayer?) -> CALayer? {
        var node = hit
        while let current = node {
            if current.name != nil, current.value(forKey: "driftColumn") != nil {
                return current
            }
            node = current.superlayer
        }
        return nil
    }

    private func setHovered(_ tile: CALayer?) {
        if let previous = hoveredTile {
            previous.opacity = 0.55
            (previous.sublayers?.first { $0.name == "veil" })?.opacity = 0.42
        }
        hoveredTile = tile
        if let tile {
            tile.opacity = 1
            (tile.sublayers?.first { $0.name == "veil" })?.opacity = 0
            hoveredColumn = tile.value(forKey: "driftColumn") as? Int ?? -1
            NSCursor.pointingHand.set()
            onHover?(assets.first { $0.id == tile.name })
        } else {
            hoveredColumn = -1
            NSCursor.arrow.set()
            onHover?(nil)
        }
    }

    private func planeTransform(tilt: CGFloat, turn: CGFloat) -> CATransform3D {
        var transform = CATransform3DIdentity
        transform = CATransform3DScale(transform, 1.18, 1.18, 1)
        transform = CATransform3DTranslate(transform, 0, 0, -120)
        transform = CATransform3DRotate(transform, tilt * .pi / 180, 1, 0, 0)
        transform = CATransform3DRotate(transform, turn * .pi / 180, 0, 1, 0)
        return transform
    }

    private func columnSpeed(_ column: Int) -> CGFloat {
        let alt: CGFloat = column % 2 == 0 ? 1 : -1
        let pseudo = ((Double(column) * 0.6180339887 + 0.35).truncatingRemainder(dividingBy: 1)) * 2 - 1
        return 42 * CGFloat(1 + 0.45 * pseudo) * alt
    }

}

private final class DriftColumn {
    let index: Int
    let clip = CALayer()
    let track = CALayer()
    var copyHeight: CGFloat = 1
    var baseSpeed: CGFloat = 0
    var offset: CGFloat = 0

    init(index: Int) {
        self.index = index
    }
}
#else
private struct DriftWallCanvas: View {
    var assets: [MediaAssetSummary]
    var onHover: (MediaAssetSummary?) -> Void
    var onOpen: (MediaAssetSummary) -> Void

    var body: some View { gardenEmpty }
}
#endif

// MARK: - Shared

private struct GardenClock: View {
    var paused: Bool
    var onTick: (Double) -> Void
    @State private var last: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: paused)) { context in
            Color.clear
                .onChange(of: context.date) { _, date in
                    let previous = last ?? date
                    last = date
                    let delta = min(0.05, max(0, date.timeIntervalSince(previous)))
                    if delta > 0 { onTick(delta) }
                }
        }
        .onChange(of: paused) { _, isPaused in
            if !isPaused { last = nil }
        }
    }
}

private var gardenEmpty: some View {
    Text("Nothing in this view yet.")
        .font(.subheadline)
        .foregroundStyle(PrismTheme.textSecondary)
}

private func gardenClamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
    min(max(value, minValue), maxValue)
}

private func gardenModulo(_ value: Double, _ divisor: Double) -> Double {
    guard divisor != 0 else { return 0 }
    let remainder = value.truncatingRemainder(dividingBy: divisor)
    return remainder >= 0 ? remainder : remainder + divisor
}

private func gardenMod(_ value: Int, _ modulus: Int) -> Int {
    guard modulus > 0 else { return 0 }
    let remainder = value % modulus
    return remainder >= 0 ? remainder : remainder + modulus
}

private func gardenSmoothstep(_ minValue: Double, _ maxValue: Double, _ value: Double) -> Double {
    let span = maxValue - minValue
    let x = gardenClamp((value - minValue) / (span == 0 ? 1 : span), 0, 1)
    return x * x * (3 - 2 * x)
}

#if os(macOS)
private struct GardenWheelCatcher: View {
    var onScroll: (CGFloat) -> Void

    var body: some View {
        PrismWheelRegion { event in
            onScroll(event.scrollingDeltaY)
            return .consume
        }
    }
}
#endif
