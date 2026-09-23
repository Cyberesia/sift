import Foundation

public struct OrganizeRule: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var pipeline: MediaPipeline?
    public var kind: MediaKind?
    public var sourceLabel: String?
    public var bucket: StagingBucket
    public var isEnabled: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        pipeline: MediaPipeline? = nil,
        kind: MediaKind? = nil,
        sourceLabel: String? = nil,
        bucket: StagingBucket,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.pipeline = pipeline
        self.kind = kind
        self.sourceLabel = sourceLabel
        self.bucket = bucket
        self.isEnabled = isEnabled
    }
}

public enum OrganizeRulesStore {
    private static let key = "sift.organizeRules"

    public static func load() -> [OrganizeRule] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let rules = try? JSONDecoder().decode([OrganizeRule].self, from: data) else {
            return defaultRules()
        }
        return rules
    }

    public static func save(_ rules: [OrganizeRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    public static func defaultRules() -> [OrganizeRule] {
        [
            OrganizeRule(name: "Videos → Videos", kind: .video, bucket: .videos),
            OrganizeRule(name: "Screenshots → Gather", pipeline: .artifacts, bucket: .gather),
            OrganizeRule(name: "People → Photos", pipeline: .people, bucket: .photos),
        ]
    }
}
