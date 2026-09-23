import Foundation

/// Fibonacci disk used by the orbit gallery.
/// Same placement as Refgarden `orbit-scene.ts`: the first slots keep their
/// radius even as later cards are added (`prioritySlots` stays the denominator).
public enum OrbitLayout {
    public static let prioritySlots = 100

    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var z: Double
    }

    public struct Projection: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var depth: Double
        public var scale: Double
        public var opacity: Double
    }

    public static func coordinates(
        slot: Int,
        radius: Double,
        viewportHeight: Double,
        spreadSlots: Int = prioritySlots,
        verticalFraction: Double = 0.365,
        yRadius: Double? = nil,
        spreadScale: Double = 1
    ) -> Point {
        let angle = Double(slot) * Double.pi * (3 - sqrt(5))
        let slots = Double(max(spreadSlots, 1))
        let spread = sqrt((Double(slot) + 0.65) / slots) * min(1, max(0, spreadScale))
        let vertical = yRadius ?? min(viewportHeight * verticalFraction, radius * 1.5)
        return Point(
            x: cos(angle) * radius * spread,
            y: sin(angle) * vertical * spread,
            z: sin(angle * 2) * 22 * spread
        )
    }

    /// Largest orbit that keeps a card inside the live viewport, using width and height separately.
    public static func fittedRadii(
        viewport: CGSize,
        cardSize: CGSize,
        zoom: Double,
        margin: Double = 12
    ) -> (x: Double, y: Double) {
        let safeZoom = max(zoom, 0.2)
        let maxScale = min(1.35, max(0.35, safeZoom * 1.1))
        let depthPad = 18.0
        let x = (viewport.width / 2 - cardSize.width / 2 * maxScale - margin) / safeZoom - depthPad
        let y = (viewport.height / 2 - cardSize.height / 2 * maxScale - margin) / safeZoom - depthPad
        return (max(12, x), max(12, y))
    }

    /// Thumbnail frame and orbit radii for the live garden pane.
    /// Front-card size tracks the pane: a short window gets smaller thumbnails so the ring can still open inside the frame.
    public static func gardenFrame(
        viewport: CGSize,
        zoom: Double
    ) -> (card: CGSize, x: Double, y: Double) {
        let safeZoom = max(zoom, 0.2)
        let maxScale = min(1.35, max(0.35, safeZoom * 1.1))
        let margin = 10.0
        let depthPad = 18.0
        let halfX = max(0, viewport.width / 2 - margin)
        let halfY = max(0, viewport.height / 2 - margin)
        let limiting = min(max(viewport.width, 1), max(viewport.height, 1) * 1.55)
        let desiredVisual = min(188, max(44, limiting * 0.132))
        let roomX = max(0, halfX - (16 + depthPad) * safeZoom)
        let roomY = max(0, halfY - (16 + depthPad) * safeZoom)
        let visual = max(32, min(desiredVisual, roomX * 2, roomY * 2 / 0.75))
        let card = CGSize(width: visual / maxScale, height: visual / maxScale * 0.75)
        let fit = fittedRadii(viewport: viewport, cardSize: card, zoom: zoom, margin: margin)
        return (card, fit.x, fit.y)
    }

    public static func clampPitch(_ degrees: Double) -> Double {
        min(32, max(-32, degrees))
    }

    public static func project(
        slot: Int,
        radius: Double,
        viewportHeight: Double,
        yawDegrees: Double,
        pitchDegrees: Double,
        zoom: Double,
        spreadSlots: Int = prioritySlots,
        verticalFraction: Double = 0.365,
        yRadius: Double? = nil,
        spreadScale: Double = 1
    ) -> Projection {
        let local = coordinates(
            slot: slot,
            radius: radius,
            viewportHeight: viewportHeight,
            spreadSlots: spreadSlots,
            verticalFraction: verticalFraction,
            yRadius: yRadius,
            spreadScale: spreadScale
        )
        let yaw = yawDegrees * .pi / 180
        let pitch = clampPitch(pitchDegrees) * .pi / 180
        let x1 = local.x * cos(yaw) - local.z * sin(yaw)
        let z1 = local.x * sin(yaw) + local.z * cos(yaw)
        let y2 = local.y * cos(pitch) - z1 * sin(pitch)
        let depth = local.y * sin(pitch) + z1 * cos(pitch)
        let span = max(radius, 1)
        let normalized = (depth + span) / (span * 2)
        let scale = min(1.35, max(0.35, zoom * (0.55 + normalized * 0.55)))
        let opacity = min(1, max(0.35, 0.45 + normalized * 0.55))
        return Projection(x: x1 * zoom, y: y2 * zoom, depth: depth, scale: scale, opacity: opacity)
    }
}
