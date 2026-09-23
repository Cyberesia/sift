import SiftCore
import Foundation
import Testing

@Test func orbitSlotZeroStaysPutWhenMoreCardsExist() {
    let first = OrbitLayout.coordinates(slot: 0, radius: 400, viewportHeight: 800)
    let again = OrbitLayout.coordinates(slot: 0, radius: 400, viewportHeight: 800)
    #expect(first == again)
    let later = OrbitLayout.coordinates(slot: 12, radius: 400, viewportHeight: 800)
    #expect(later.x != first.x || later.y != first.y)
}

@Test func orbitYawMovesTheCardSideways() {
    let rest = OrbitLayout.project(
        slot: 3,
        radius: 400,
        viewportHeight: 800,
        yawDegrees: 0,
        pitchDegrees: 0,
        zoom: 1
    )
    let turned = OrbitLayout.project(
        slot: 3,
        radius: 400,
        viewportHeight: 800,
        yawDegrees: 40,
        pitchDegrees: 0,
        zoom: 1
    )
    #expect(abs(turned.x - rest.x) > 0.5)
}

@Test func fittedRadiiUseWidthAndStayInside() {
    let viewport = CGSize(width: 1200, height: 680)
    let zoom = 1.35
    let frame = OrbitLayout.gardenFrame(viewport: viewport, zoom: zoom)
    let maxScale = min(1.35, zoom * 1.1)
    let extentX = (frame.x + 18) * zoom + frame.card.width / 2 * maxScale
    let extentY = (frame.y + 18) * zoom + frame.card.height / 2 * maxScale
    #expect(extentX <= viewport.width / 2 + 0.5)
    #expect(extentY <= viewport.height / 2 + 0.5)
    #expect(frame.x > frame.y)
    #expect(extentX > viewport.width / 2 * 0.8)
}

@Test func gardenThumbnailsShrinkWhenThePaneShrinks() {
    let zoom = 1.35
    let small = OrbitLayout.gardenFrame(viewport: CGSize(width: 640, height: 380), zoom: zoom)
    let large = OrbitLayout.gardenFrame(viewport: CGSize(width: 1600, height: 960), zoom: zoom)
    #expect(small.card.width < large.card.width)
    #expect(small.card.height < large.card.height)
    let maxScale = min(1.35, zoom * 1.1)
    let extentX = (small.x + 18) * zoom + small.card.width / 2 * maxScale
    let extentY = (small.y + 18) * zoom + small.card.height / 2 * maxScale
    #expect(extentX <= 320 + 0.5)
    #expect(extentY <= 190 + 0.5)
}

@Test func orbitPitchStaysInRange() {
    #expect(OrbitLayout.clampPitch(90) == 32)
    #expect(OrbitLayout.clampPitch(-90) == -32)
}

@Test func visualDirectionKeepsEverythingWhenNoneSelected() {
    #expect(
        VisualDirectionFilter.matches(
            fileName: "IMG_1.jpg",
            categories: ["dog"],
            personName: nil,
            directions: []
        )
    )
}

@Test func botanicalDirectionMatchesAFlowerLabel() {
    #expect(
        VisualDirectionFilter.matches(
            fileName: "IMG_1.jpg",
            categories: ["Flower", "Outdoor"],
            personName: nil,
            directions: [.botanical]
        )
    )
    #expect(
        !VisualDirectionFilter.matches(
            fileName: "IMG_1.jpg",
            categories: ["Car"],
            personName: nil,
            directions: [.botanical]
        )
    )
}
