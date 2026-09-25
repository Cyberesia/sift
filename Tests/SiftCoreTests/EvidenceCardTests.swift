import Foundation
@testable import SiftCore
import SwiftData
import Testing

@MainActor
private func memoryStore() throws -> MediaIndexStore {
    let schema = Schema([
        IndexedSource.self,
        MediaAssetRecord.self,
        StratumCollectionRecord.self,
        TransferRecord.self,
        SavedSearchRecord.self,
    ])
    let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    return MediaIndexStore(container: container)
}

private func discovered(_ path: String, kind: MediaKind = .image, source: String = "100LEICA") -> DiscoveredMedia {
    DiscoveredMedia(
        id: path,
        url: URL(fileURLWithPath: path),
        kind: kind,
        sourceKind: .folder,
        sourceLabel: source,
        fileSize: 2_000,
        contentHash: path,
        createdAt: nil,
        modifiedAt: nil
    )
}

@MainActor
@Test func upsertStoresTheLowercasedExtensionAndType() throws {
    let store = try memoryStore()
    _ = try store.upsertDiscovered([discovered("/tmp/L1000123.JPG")])
    let record = try #require(try store.fetchAsset(id: "/tmp/L1000123.JPG"))
    #expect(record.fileExtension == "jpg")
    #expect(record.uti == "public.jpeg")
}

@Test func weakVisionLabelsAndRefusedLabelsStayOffTheCard() {
    let card = EvidenceCard(
        fileName: "a.jpg",
        fileExtension: "jpg",
        kind: .image,
        sourceLabel: "100LEICA",
        labels: [
            LabelScore(label: "outdoor", score: 0.2, source: .vision),
            LabelScore(label: "dog", score: 0.9, source: .vision),
            LabelScore(label: "grass", score: 0.6, source: .vision),
        ],
        rejected: ["grass"]
    )
    #expect(card.labels.map(\.label) == ["dog"])
}

@Test func theSameRowAlwaysGivesTheSameText() {
    let make = {
        EvidenceCard(
            fileName: "shot.png",
            fileExtension: "png",
            kind: .image,
            sourceLabel: "Desktop",
            fileSize: 3_400_000,
            pixelWidth: 1170,
            pixelHeight: 2532,
            screenshotReason: "screen-size",
            labels: [LabelScore(label: "text", score: 0.8, source: .vision)],
            ocr: ["Settings", "Wi-Fi", "Bluetooth", "Battery"]
        ).text
    }
    #expect(make() == make())
    #expect(make().contains("ext png"))
    #expect(make().contains("screenshot screen-size"))
    #expect(!make().contains("Battery"))
}

@Test func artifactReasonNamesWhyAPictureIsAScreenshot() {
    let screen = PipelineClassifier.artifactReason(
        analysis: PhotoAnalysisResult(),
        metadata: AssetMetadata(pixelWidth: 1170, pixelHeight: 2532, isScreenshotCandidate: true)
    )
    #expect(screen == "screen-size")
    let photo = PipelineClassifier.artifactReason(
        analysis: PhotoAnalysisResult(textLineCount: 1),
        metadata: AssetMetadata(pixelWidth: 6000, pixelHeight: 4000)
    )
    #expect(photo == nil)
}

@Test func exifDatesParseInTheCameraFormat() {
    #expect(FileEvidenceReader.exifDate("2024:07:14 18:03:22") != nil)
    #expect(FileEvidenceReader.exifDate("not a date") == nil)
}

@MainActor
@Test func analysisStampsTheEvidenceVersion() throws {
    let store = try memoryStore()
    _ = try store.upsertDiscovered([discovered("/tmp/a.heic")])
    try store.applyAnalysis(
        assetID: "/tmp/a.heic",
        result: PhotoAnalysisResult(labelScores: [LabelScore(label: "cat", score: 0.8, source: .vision)], pixelWidth: 4000, pixelHeight: 3000),
        pipeline: .photography
    )
    let record = try #require(try store.fetchAsset(id: "/tmp/a.heic"))
    #expect(record.evidenceVersion == EvidenceCard.currentVersion)
    #expect(record.pixelWidth == 4000)
    #expect(record.labelScores.first?.label == "cat")
    try store.markStaleEvidenceForAnalysis()
    #expect(try store.fetchAsset(id: "/tmp/a.heic")?.isAnalyzed == true)
}

@MainActor
@Test func rejectedLabelStaysOffStoredCategoriesAndEvidence() throws {
    let store = try memoryStore()
    _ = try store.upsertDiscovered([discovered("/tmp/dog.jpg")])
    try store.applyAnalysis(
        assetID: "/tmp/dog.jpg",
        result: PhotoAnalysisResult(
            topCategories: ["dog", "grass"],
            labelScores: [
                LabelScore(label: "dog", score: 0.9, source: .vision),
                LabelScore(label: "grass", score: 0.8, source: .vision),
            ]
        ),
        pipeline: .photography
    )
    try store.rejectLabel(assetID: "/tmp/dog.jpg", label: "grass")
    let record = try #require(try store.fetchAsset(id: "/tmp/dog.jpg"))
    #expect(record.topCategories == ["dog"])
    #expect(EvidenceCard(record: record).labels.map(\.label) == ["dog"])
}

@MainActor
@Test func undoingACopyRemovesTheCopyAndKeepsTheOriginal() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("sift-copy-undo-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source.jpg")
    let destination = root.appendingPathComponent("Photos/copy.jpg")
    try Data("photo".utf8).write(to: source)
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("photo".utf8).write(to: destination)

    let store = try memoryStore()
    _ = try store.upsertDiscovered([discovered(source.path)])
    let journal = TransferJournal(store: store)
    try journal.record(assetID: source.path, sourcePath: source.path, destinationPath: destination.path, mode: .copy)
    let record = try #require(try journal.recent(limit: 1).first)
    try journal.undo(record: record)

    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(!FileManager.default.fileExists(atPath: destination.path))
    #expect(try store.fetchAsset(id: source.path)?.fileURL.path == source.path)
    #expect(record.isUndone)
}
