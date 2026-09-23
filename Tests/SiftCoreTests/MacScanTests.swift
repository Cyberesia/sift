import SiftCore
import CoreGraphics
import Foundation
import Testing

@Test func exclusionSkipsDependencyAndSystemTrees() {
    let policy = ScanExclusionPolicy.standard
    let modules = URL(fileURLWithPath: "/tmp/album/node_modules")
    #expect(policy.skipReason(forDirectory: modules) == .dependencyTree)
    #expect(policy.skipReason(forDirectory: URL(fileURLWithPath: "/System/Library")) == .systemLocation)
    #expect(policy.isBlockedSource(URL(fileURLWithPath: "/tmp/album/node_modules/pkg/cover.jpg")) == .dependencyTree)
    #expect(policy.isBlockedSource(URL(fileURLWithPath: "/Library/Desktop Pictures/a.jpg")) == .systemLocation)
}

@Test func scannerSkipsProjectAndDependencyFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("sift-scan-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try Data().write(to: root.appendingPathComponent("keep.jpg"))
    let modules = root.appendingPathComponent("node_modules", isDirectory: true)
    try FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true)
    try Data().write(to: modules.appendingPathComponent("hidden.jpg"))
    let project = root.appendingPathComponent("repo", isDirectory: true)
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    try Data().write(to: project.appendingPathComponent(".git"))
    try Data().write(to: project.appendingPathComponent("shot.jpg"))
    try Data().write(to: root.appendingPathComponent("song.mp3"))

    ScanStats.shared.reset()
    let found = try MediaScanner().scanFolder(at: root, sourceLabel: "Fixture")
    let names = Set(found.map { $0.url.lastPathComponent })
    #expect(names.contains("keep.jpg"))
    #expect(names.contains("song.mp3"))
    #expect(!names.contains("hidden.jpg"))
    #expect(!names.contains("shot.jpg"))
    #expect(found.contains { $0.kind == .audio })
    #expect(ScanStats.shared.snapshot().skippedTrees >= 2)
}

@Test func organizePlanHoldsProjectFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("sift-plan-\(UUID().uuidString)", isDirectory: true)
    let repo = root.appendingPathComponent("app", isDirectory: true)
    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data().write(to: repo.appendingPathComponent(".git"))
    let held = repo.appendingPathComponent("logo.png")
    let loose = root.appendingPathComponent("vacation.jpg")
    let plan = OrganizePlanner.preview(candidates: [
        OrganizeCandidate(id: "held", path: held.path, pipelineName: "Photography"),
        OrganizeCandidate(id: "loose", path: loose.path, pipelineName: "Photography"),
    ])
    #expect(plan.first { $0.id == "held" }?.blocked == true)
    #expect(plan.first { $0.id == "loose" }?.blocked == false)
    #expect(plan.first { $0.id == "loose" }?.proposedFolder == "Photos")
}

@Test func semanticRankerOrdersByCosine() {
    let query: [Float] = [1, 0, 0]
    let hits = SemanticRanker.topK(query: query, catalog: [
        ("far", [0, 1, 0]),
        ("near", [0.9, 0.1, 0]),
    ])
    #expect(hits.first?.id == "near")
    #expect(hits.first!.score > hits.last!.score)
}

@Test func semanticRankerHandlesLargeCatalog() {
    for size in [10_000, 50_000, 100_000] {
        var catalog: [(id: String, vector: [Float])] = []
        catalog.reserveCapacity(size)
        for index in 0..<size {
            catalog.append(("\(index)", [Float(index % 7), 0.2, 0.1]))
        }
        let started = Date()
        let hits = SemanticRanker.topK(query: [1, 0, 0], catalog: catalog, limit: 20)
        #expect(hits.count == 20)
        #expect(Date().timeIntervalSince(started) < 2)
    }
}

@Test func localCommandOpensDuplicatesWithoutASearch() {
    #expect(JevAdvisor.localSurface(for: "montre les doublons") == .duplicates)
    #expect(JevAdvisor.localSurface(for: "cat") == nil)
    #expect(JevAdvisor.localSurface(for: "a photo of the garden") == nil)
    #expect(JevAdvisor.localSurface(for: "open the garden") == .garden)
}

@Test func jevLeavesOrdinarySearchAlone() {
    #expect(!JevAdvisor.looksLikeCommand("cat"))
    #expect(!JevAdvisor.looksLikeCommand("a photo of the garden"))
    #expect(JevAdvisor.looksLikeCommand("open the garden"))
    #expect(JevAdvisor.looksLikeCommand("montre les doublons"))
}

@Test func jevRouteIgnoresSearchAndLowConfidence() {
    #expect(JevAdvisor.acceptedRoute(JevChoice(value: "garden", confidence: 0.9)) == .garden)
    #expect(JevAdvisor.acceptedRoute(JevChoice(value: "search", confidence: 0.99)) == nil)
    #expect(JevAdvisor.acceptedRoute(JevChoice(value: "garden", confidence: 0.4)) == nil)
    #expect(JevAdvisor.acceptedRoute(JevChoice(value: "desktop", confidence: 0.99)) == nil)
}

@Test func jevRerankOnlyPromotesAKnownCandidate() {
    let ids = ["clip", "exact", "other"]
    let promoted = JevAdvisor.promotedOrder(ids: ids, choice: JevChoice(value: "exact", confidence: 0.8))
    #expect(promoted == ["exact", "clip", "other"])
    #expect(JevAdvisor.promotedOrder(ids: ids, choice: JevChoice(value: "missing", confidence: 0.99)) == ids)
    #expect(JevAdvisor.promotedOrder(ids: ids, choice: JevChoice(value: "exact", confidence: 0.2)) == ids)
}

@Test func jevFolderStaysInsideTheExistingSet() {
    #expect(JevAdvisor.acceptedFolder(JevChoice(value: "Videos", confidence: 0.8)) == "Videos")
    #expect(JevAdvisor.acceptedFolder(JevChoice(value: "Desktop", confidence: 0.99)) == nil)
    #expect(JevAdvisor.acceptedFolder(JevChoice(value: "Photos", confidence: 0.5)) == nil)
}

@Test func jevDecodesNestedChoice() throws {
    let json = """
    {"choices":[{"message":{"content":"{\\"value\\":\\"photo\\",\\"confidence\\":0.91}"}}]}
    """
    let choice = try JevClient.decode(Data(json.utf8))
    #expect(choice.value == "photo")
    #expect(choice.confidence > 0.9)
    #expect(choice.uncertain == false)
    #expect(!JevClient.disclosure.isEmpty)
}

@Test func jevDecodesNoulScores() throws {
    let json = """
    {"answers":{"l0":{"noul":0.82},"l1":{"noul":0.2}}}
    """
    let scores = try JevClient.decodeNouls(Data(json.utf8))
    #expect(scores["l0"] == 0.82)
    #expect(scores["l1"] == 0.2)
}

@Test func semanticBlendKeepsExactNamesFirst() {
    let ordered = SemanticRanker.blend(
        keywordIDs: ["exact"],
        semantic: [SemanticHit(id: "near", score: 0.99), SemanticHit(id: "exact", score: 0.2)]
    )
    #expect(ordered.first == "exact")
    #expect(ordered.contains("near"))
}

@Test func searchTermIgnoresWordsThatOnlyContainTheQuery() {
    #expect(SearchTermMatcher.containsTerm("cat", in: "a cat on the sofa"))
    #expect(SearchTermMatcher.containsTerm("cat", in: "cat_01.JPG"))
    #expect(!SearchTermMatcher.containsTerm("cat", in: "application location indicator"))
    #expect(!SearchTermMatcher.containsTerm("cat", in: "Capture d'écran 2026.png"))
}

@Test func matchingDocumentStaysAheadOfVisualNeighbors() {
    let photos = (1...120).map { SemanticHit(id: "photo\($0)", score: 0.4) }
    let ordered = SemanticRanker.blend(
        keywordIDs: ["notes"],
        semantic: photos,
        semanticFirst: true,
        documentIDs: ["notes"]
    )
    #expect(ordered.first == "notes")
    #expect(ordered.contains("photo1"))
}

@Test func visualSearchStillKeepsALaterDocument() {
    let photos = (1...120).map { SemanticHit(id: "photo\($0)", score: 0.4) }
    let ordered = SemanticRanker.blend(
        keywordIDs: ["catphoto", "notes"],
        semantic: photos,
        limit: 100,
        semanticFirst: true,
        documentIDs: ["notes"]
    )
    #expect(ordered.first == "photo1")
    #expect(ordered.contains("notes"))
    #expect(ordered.count == 100)
}

@Test func visualSearchCanLeadFilenameHits() {
    let ordered = SemanticRanker.blend(
        keywordIDs: ["screenshot"],
        semantic: [SemanticHit(id: "cat", score: 0.31), SemanticHit(id: "weak", score: 0.05)],
        semanticFirst: true
    )
    #expect(ordered.first == "cat")
    #expect(!ordered.contains("weak"))
    #expect(ordered.last == "screenshot")
}

@Test func clipWeightProgressCoversBothFiles() {
    let halfway = ClipWeightProgress(
        fileIndex: 1,
        fileCount: 2,
        completedBytes: 87_818_240,
        totalBytes: ClipWeightProgress.starting.totalBytes
    )
    #expect(abs(halfway.fraction - 0.29) < 0.02)
    #expect(halfway.statusLine.contains("1 of 2"))
    let done = ClipWeightProgress(
        fileIndex: 2,
        fileCount: 2,
        completedBytes: ClipWeightProgress.starting.totalBytes,
        totalBytes: ClipWeightProgress.starting.totalBytes
    )
    #expect(done.fraction == 1)
    #expect(done.statusLine.contains("2 of 2"))
}

@Test func bundledClipTowersProduceCompatibleVectors() async throws {
    guard ClipEmbeddingStore.status == .ready else { return }
    let text = try await ClipEmbeddingStore.shared.embedText("a bright orange square")
    let blueText = try await ClipEmbeddingStore.shared.embedText("a dark blue circle")
    #expect(text.count == ClipEmbeddingStore.vectorDimension)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: 224,
        height: 224,
        bitsPerComponent: 8,
        bytesPerRow: 224 * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    context?.setFillColor(CGColor(red: 1, green: 0.35, blue: 0.05, alpha: 1))
    context?.fill(CGRect(x: 0, y: 0, width: 224, height: 224))
    let image = try #require(context?.makeImage())
    let imageVector = try await ClipEmbeddingStore.shared.embedImage(image)
    #expect(imageVector.count == ClipEmbeddingStore.vectorDimension)
    #expect(abs(SemanticRanker.cosine(text, text) - 1) < 0.001)
    #expect(SemanticRanker.cosine(text, imageVector).isFinite)
    #expect(
        SemanticRanker.cosine(text, imageVector)
            > SemanticRanker.cosine(blueText, imageVector)
    )
}
