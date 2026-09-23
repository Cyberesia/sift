import Foundation

private struct DuplicateAssetFingerprint: Sendable {
    let id: String
    let contentHash: String
    let featurePrintData: Data?
    let fileSize: Int64?
    let modifiedAt: Date?
    let indexedAt: Date
    let thumbnailPath: String?

    init(_ record: MediaAssetRecord) {
        id = record.id
        contentHash = record.contentHash
        featurePrintData = record.featurePrintData
        fileSize = record.fileSize
        modifiedAt = record.modifiedAt
        indexedAt = record.indexedAt
        thumbnailPath = record.thumbnailPath
    }
}

public enum DuplicateFinderEngine: Sendable {
    public static let nearDuplicateDistanceThreshold: Float = 0.20
    public static let maxNearGroupSize = 12

    public static func findGroups(in records: [MediaAssetRecord]) -> [DuplicateGroup] {
        findGroups(in: records.map(DuplicateAssetFingerprint.init))
    }

    @MainActor
    public static func findGroupsAsync(
        in records: [MediaAssetRecord],
        onProgress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) async -> [DuplicateGroup] {
        let snapshot = records.map(DuplicateAssetFingerprint.init)
        return await Task.detached(priority: .utility) {
            findGroups(in: snapshot, onProgress: onProgress)
        }.value
    }

    private static func findGroups(
        in fingerprints: [DuplicateAssetFingerprint],
        onProgress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        groups.append(contentsOf: exactGroups(from: fingerprints))
        groups.append(contentsOf: nearDuplicateGroups(from: fingerprints, onProgress: onProgress))
        return groups.sorted { $0.reclaimableBytes > $1.reclaimableBytes }
    }

    private static func exactGroups(from records: [DuplicateAssetFingerprint]) -> [DuplicateGroup] {
        let grouped = Dictionary(grouping: records, by: \.contentHash)
        return grouped.compactMap { hash, members in
            guard members.count > 1, !hash.isEmpty else { return nil }
            let keep = suggestKeep(in: members)
            let others = members.filter { $0.id != keep.id }
            let bytes = others.compactMap(\.fileSize).reduce(0, +)
            return DuplicateGroup(
                kind: .exact,
                memberIDs: members.map(\.id),
                suggestedKeepID: keep.id,
                reclaimableBytes: bytes,
                thumbnailPaths: Self.thumbnails(in: members)
            )
        }
    }

    private static func nearDuplicateGroups(
        from records: [DuplicateAssetFingerprint],
        onProgress: @escaping @Sendable (Int, Int) -> Void
    ) -> [DuplicateGroup] {
        let withPrints = records.filter { $0.featurePrintData != nil }
        let total = withPrints.count
        guard total >= 2 else {
            onProgress(total, max(total, 1))
            return []
        }

        var groups: [DuplicateGroup] = []
        var assigned = Set<String>()

        for (index, asset) in withPrints.enumerated() {
            if index.isMultiple(of: 24) || index == total - 1 {
                onProgress(index + 1, total)
            }
            guard !assigned.contains(asset.id),
                  let printA = asset.featurePrintData else { continue }

            var cluster = [asset]
            assigned.insert(asset.id)

            for other in withPrints where !assigned.contains(other.id) {
                guard cluster.count < maxNearGroupSize,
                      let printB = other.featurePrintData,
                      let distance = LegacyVisionBridge.distanceBetween(printA, printB),
                      distance < nearDuplicateDistanceThreshold else { continue }
                cluster.append(other)
                assigned.insert(other.id)
            }

            guard cluster.count > 1 else { continue }
            let keep = suggestKeep(in: cluster)
            let others = cluster.filter { $0.id != keep.id }
            let bytes = others.compactMap(\.fileSize).reduce(0, +)
            groups.append(
                DuplicateGroup(
                    kind: .near,
                    memberIDs: cluster.map(\.id),
                    suggestedKeepID: keep.id,
                    reclaimableBytes: bytes,
                    thumbnailPaths: Self.thumbnails(in: cluster)
                )
            )
        }
        return groups
    }

    private static func thumbnails(in members: [DuplicateAssetFingerprint]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: members.compactMap { member in
            guard let path = member.thumbnailPath else { return nil }
            return (member.id, path)
        })
    }

    private static func suggestKeep(in members: [DuplicateAssetFingerprint]) -> DuplicateAssetFingerprint {
        members.max { lhs, rhs in
            let lSize = lhs.fileSize ?? 0
            let rSize = rhs.fileSize ?? 0
            if lSize != rSize { return lSize < rSize }
            let lDate = lhs.modifiedAt ?? lhs.indexedAt
            let rDate = rhs.modifiedAt ?? rhs.indexedAt
            return lDate < rDate
        } ?? members[0]
    }
}
