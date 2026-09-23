import Foundation

@MainActor
public final class CollectionSuggester {
    private let store: MediaIndexStore

    public init(store: MediaIndexStore) {
        self.store = store
    }

    public func rebuildSuggestions() throws {
        let existing = try store.fetchCollections()
        for collection in existing where collection.isSuggested {
            // Remove old suggestions — simplified: recreate each run
        }

        let assets = try store.fetchAssets()
        // Pipeline browsing uses MediaPipeline filters in the sidebar — no duplicate collections.
        try suggestCategoryCollections(from: assets)
        try suggestAnimalCollections(from: assets)
        try suggestScreenshotProjects(from: assets)
    }

    private func suggestScreenshotProjects(from assets: [MediaAssetRecord]) throws {
        let groups = ScreenshotProjectGrouper.suggestGroups(from: assets)
        for group in groups {
            let collection = StratumCollectionRecord(
                title: group.suggestedTitle,
                pipelineRaw: MediaPipeline.artifacts.rawValue,
                isSuggested: true,
                isAccepted: false,
                sortOrder: 80,
                collectionKindRaw: CollectionKind.project.rawValue
            )
            let members = assets.filter { group.assetIDs.contains($0.id) }
            collection.assets = members
            try store.upsertCollection(collection)
        }
    }

    private func suggestCategoryCollections(from assets: [MediaAssetRecord]) throws {
        var categoryMap: [String: [MediaAssetRecord]] = [:]
        for asset in assets {
            for category in asset.topCategories.prefix(2) {
                categoryMap[category, default: []].append(asset)
            }
        }
        for (category, items) in categoryMap where items.count >= 4 {
            let collection = StratumCollectionRecord(
                title: category.capitalized,
                pipelineRaw: MediaPipeline.places.rawValue,
                parentID: nil,
                isSuggested: true,
                isAccepted: false,
                sortOrder: 100
            )
            collection.assets = items
            try store.upsertCollection(collection)
        }
    }

    private func suggestAnimalCollections(from assets: [MediaAssetRecord]) throws {
        var animalMap: [String: [MediaAssetRecord]] = [:]
        for asset in assets {
            for animal in asset.detectedAnimals {
                animalMap[animal, default: []].append(asset)
            }
        }
        for (animal, items) in animalMap where items.count >= 3 {
            let collection = StratumCollectionRecord(
                title: animal.capitalized,
                pipelineRaw: MediaPipeline.people.rawValue,
                isSuggested: true,
                isAccepted: false,
                sortOrder: 50
            )
            collection.assets = items
            try store.upsertCollection(collection)
        }
    }
}
