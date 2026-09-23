import Foundation

@MainActor
public final class ClusterEngine {
    private let store: MediaIndexStore
    private let distanceThreshold: Float = 0.35

    public init(store: MediaIndexStore) {
        self.store = store
    }

    public func runClusteringPass() async throws {
        let assets = try store.fetchAssets().filter { $0.featurePrintData != nil }
        guard assets.count >= 2 else {
            try CollectionSuggester(store: store).rebuildSuggestions()
            return
        }

        var clusters: [[MediaAssetRecord]] = []
        var assigned = Set<String>()

        for asset in assets {
            guard !assigned.contains(asset.id),
                  let printA = asset.featurePrintData else { continue }

            var cluster = [asset]
            assigned.insert(asset.id)

            for other in assets where !assigned.contains(other.id) {
                guard let printB = other.featurePrintData,
                      let distance = LegacyVisionBridge.distanceBetween(printA, printB),
                      distance < distanceThreshold else { continue }
                cluster.append(other)
                assigned.insert(other.id)
            }

            if cluster.count >= 2 {
                clusters.append(cluster)
            }
        }

        let dismissed = Set(UserDefaults.standard.stringArray(forKey: "sift.dismissedCollectionIDs") ?? [])

        for (index, cluster) in clusters.enumerated() {
            let clusterID = "trip-\(index)"
            if dismissed.contains(clusterID) { continue }
            for asset in cluster {
                try store.assignCluster(assetID: asset.id, clusterID: clusterID, personClusterID: nil)
            }
            let collection = StratumCollectionRecord(
                title: "Trip \(index + 1)",
                pipelineRaw: MediaPipeline.trips.rawValue,
                isSuggested: true,
                isAccepted: false,
                sortOrder: 200 + index
            )
            collection.assets = cluster
            try store.upsertCollection(collection)
        }

        try clusterPeople(from: assets, dismissed: dismissed)
        try CollectionSuggester(store: store).rebuildSuggestions()
    }

    private func clusterPeople(from assets: [MediaAssetRecord], dismissed: Set<String>) throws {
        let withFaces = assets.filter { $0.faceCount > 0 }
        var personClusters: [[MediaAssetRecord]] = []

        for asset in withFaces {
            if personClusters.contains(where: { $0.contains { $0.id == asset.id } }) { continue }
            let similar = withFaces.filter { other in
                guard other.id != asset.id,
                      let a = asset.featurePrintData,
                      let b = other.featurePrintData,
                      let d = LegacyVisionBridge.distanceBetween(a, b) else { return false }
                return d < 0.45
            }
            var group = [asset] + similar
            group = Array(Dictionary(grouping: group, by: \.id).compactMap(\.value.first))
            if group.count >= 2 {
                personClusters.append(group)
            }
        }

        for (index, group) in personClusters.enumerated() {
            let personID = "person-\(index)"
            if dismissed.contains(personID) { continue }
            for asset in group {
                try store.assignCluster(assetID: asset.id, clusterID: asset.clusterID, personClusterID: personID)
            }
            try store.upsertSuggestedPerson(
                id: personID,
                title: "Person \(index + 1)",
                sortOrder: 10 + index,
                members: group
            )
        }
    }

    public func relatedAssets(to assetID: String, limit: Int = 12) throws -> [MediaAssetRecord] {
        guard let target = try store.fetchAsset(id: assetID),
              let printA = target.featurePrintData else { return [] }

        let all = try store.fetchAssets()
        var scored: [(MediaAssetRecord, Float)] = []
        for other in all where other.id != assetID {
            guard let printB = other.featurePrintData,
                  let distance = LegacyVisionBridge.distanceBetween(printA, printB) else { continue }
            scored.append((other, distance))
        }
        return scored
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }
}
