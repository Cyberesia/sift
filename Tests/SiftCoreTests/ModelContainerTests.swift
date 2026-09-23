import SiftCore
import SwiftData
import Testing

@Test func modelContainerInitializesInMemory() throws {
    let schema = Schema([
        IndexedSource.self,
        MediaAssetRecord.self,
        StratumCollectionRecord.self,
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    _ = try ModelContainer(for: schema, configurations: [config])
}

@Test func stratumSharedContainerInitializes() {
    let container = StratumSchema.makeModelContainer()
    #expect(container.schema.entities.count >= 3)
}
