import SiftCore
import Foundation
import Testing

@Test func exactDuplicateGroupsByContentHash() {
    let records = [
        makeRecord(id: "a", hash: "same", size: 100),
        makeRecord(id: "b", hash: "same", size: 200),
        makeRecord(id: "c", hash: "other", size: 50),
    ]

    let groups = DuplicateFinderEngine.findGroups(in: records)
    let exact = groups.filter { $0.kind == .exact }
    #expect(exact.count == 1)
    #expect(exact[0].memberIDs.count == 2)
    #expect(exact[0].suggestedKeepID == "b")
}

private func makeRecord(id: String, hash: String, size: Int64) -> MediaAssetRecord {
    MediaAssetRecord(
        id: id,
        fileURLString: "/tmp/\(id).jpg",
        kindRaw: MediaKind.image.rawValue,
        sourceKindRaw: MediaSourceKind.folder.rawValue,
        sourceLabel: "Test",
        fileSize: size,
        contentHash: hash,
        createdAt: nil,
        modifiedAt: nil
    )
}
