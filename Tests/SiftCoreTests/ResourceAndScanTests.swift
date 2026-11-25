@testable import SiftCore
import Foundation
import SwiftData
import Testing

@Test func readBudgetScalesWithRAMAndFreeMemory() {
    let gb: UInt64 = 1 << 30
    // 16 GB Mac with plenty free: 5 % of RAM.
    #expect(ResourceGovernor.readBudget(physical: 16 * gb, available: 8 * gb) == 16 * gb / 20)
    // Same Mac under pressure: half of what is free, but never under 64 MB.
    #expect(ResourceGovernor.readBudget(physical: 16 * gb, available: 100 << 20) == 64 << 20)
    // 128 GB workstation: capped at 1 GB.
    #expect(ResourceGovernor.readBudget(physical: 128 * gb, available: 100 * gb) == gb)
}

@Test func videosAreNeverCostedAtTheirFileSize() {
    let fourGB: Int64 = 4 << 30
    #expect(ResourceGovernor.estimatedReadCost(kind: .video, fileSize: fourGB, fileExtension: "mov") == 32 << 20)
    #expect(ResourceGovernor.estimatedReadCost(kind: .document, fileSize: fourGB, fileExtension: "txt") == 200_000)
    #expect(ResourceGovernor.estimatedReadCost(kind: .image, fileSize: 3 << 30, fileExtension: "psb") == 3 << 30)
    #expect(ResourceGovernor.estimatedReadCost(kind: .image, fileSize: 12 << 20, fileExtension: "heic") == 12 << 20)
}

@Test func scannerStreamsInBatches() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("sift-batch-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    for index in 0..<23 {
        try Data().write(to: root.appendingPathComponent("photo-\(index).jpg"))
    }
    try Data().write(to: root.appendingPathComponent("notes.bin"))

    actor Sizes { var values: [Int] = []; func add(_ n: Int) { values.append(n) } }
    let sizes = Sizes()
    let sent = try await MediaScanner().scanFolderStreaming(at: root, sourceLabel: "Fixture", batchSize: 10) { batch in
        await sizes.add(batch.count)
    }
    #expect(sent == 23)
    #expect(await sizes.values == [10, 10, 3])
}

@Test func ordinaryFilesAreNotCloudPlaceholders() throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("sift-local-\(UUID().uuidString).txt")
    try Data("here".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    #expect(!CloudFileState.isDataless(file))
    #expect(!CloudFileState.isDataless(path: "/no/such/file"))
}

@MainActor
@Test func cloudOnlyFilesAreCatalogedButNotQueuedForReading() throws {
    let container = try ModelContainer(for: StratumSchema.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    let store = MediaIndexStore(container: container)
    func media(_ name: String, cloud: Bool) -> DiscoveredMedia {
        DiscoveredMedia(
            id: "file:/x/\(name)",
            url: URL(fileURLWithPath: "/x/\(name)"),
            kind: .image,
            sourceKind: .folder,
            sourceLabel: "X",
            fileSize: 10,
            contentHash: name,
            createdAt: nil,
            modifiedAt: nil,
            isCloudOnly: cloud
        )
    }
    let inserted = try store.upsertDiscovered([media("here.jpg", cloud: false), media("icloud.jpg", cloud: true)])
    #expect(inserted == 2)
    #expect(store.cloudOnlyCount == 1)
    #expect(try store.unanalyzedCount() == 1)
    #expect(try store.thumbnailPendingCount() == 1)

    // Downloaded later: the next scan clears the flag and the file joins the queue.
    _ = try store.upsertDiscovered([media("icloud.jpg", cloud: false)])
    #expect(store.cloudOnlyCount == 0)
    #expect(try store.unanalyzedCount() == 2)
}
