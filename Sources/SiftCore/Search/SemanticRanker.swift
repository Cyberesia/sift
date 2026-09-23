import Foundation

public struct SemanticHit: Sendable, Identifiable {
    public let id: String
    public let score: Double

    public init(id: String, score: Double) {
        self.id = id
        self.score = score
    }
}

/// Cosine ranking over stored vectors. Image vectors are produced on device; the query vector is the text side.
public enum SemanticRanker {
    public static func cosine(_ a: [Float], _ b: [Float]) -> Double {
        let n = min(a.count, b.count)
        guard n > 0 else { return 0 }
        var dot: Float = 0
        var na: Float = 0
        var nb: Float = 0
        for i in 0..<n {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = sqrt(na) * sqrt(nb)
        guard denom > 0 else { return 0 }
        return Double(dot / denom)
    }

    public static func topK(
        query: [Float],
        catalog: [(id: String, vector: [Float])],
        limit: Int = 100
    ) -> [SemanticHit] {
        catalog
            .map { SemanticHit(id: $0.id, score: cosine(query, $0.vector)) }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }
}
