import Foundation
import SwiftData

/// Streams persisted vectors in bounded pages on a background actor.
/// The UI never materializes a 100k-item vector catalog.
public actor SemanticCatalogSearch {
    public static let shared = SemanticCatalogSearch()

    public func topHits(
        query: [Float],
        limit: Int = 100,
        batchSize: Int = 512,
        also queryVectors: [[Float]] = [],
        preferPhotographs: Bool = false
    ) throws -> [SemanticHit] {
        let queries = [query] + queryVectors
        let context = ModelContext(StratumSchema.modelContainer)
        let version = ClipEmbeddingStore.modelVersion
        var offset = 0
        var best: [SemanticHit] = []

        while true {
            var descriptor = FetchDescriptor<MediaAssetRecord>(
                predicate: #Predicate {
                    $0.clipModelVersion == version && $0.clipEmbeddingData != nil
                }
            )
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = batchSize
            let records = try context.fetch(descriptor)
            guard !records.isEmpty else { break }

            best.append(contentsOf: records.compactMap { record in
                guard let vector = record.clipEmbedding else { return nil }
                var score = queries.map { SemanticRanker.cosine($0, vector) }.max() ?? 0
                if preferPhotographs, record.isScreenshotOrDocument {
                    score -= 0.08
                }
                return SemanticHit(id: record.id, score: score)
            })
            best.sort { $0.score > $1.score }
            if best.count > limit {
                best.removeLast(best.count - limit)
            }
            offset += records.count
            if records.count < batchSize { break }
        }
        return best
    }
}
