import Foundation

public struct OrganizeRuleSuggestion: Sendable, Identifiable {
    public let id: String
    public let assetID: String
    public let fileName: String
    public let ruleName: String
    public let bucket: StagingBucket

    public init(assetID: String, fileName: String, ruleName: String, bucket: StagingBucket) {
        self.id = assetID
        self.assetID = assetID
        self.fileName = fileName
        self.ruleName = ruleName
        self.bucket = bucket
    }
}

@MainActor
public final class OrganizeRulesEngine {
    private let store: MediaIndexStore

    public var autoApplyEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "sift.autoApplyOrganizeRules") }
        set { UserDefaults.standard.set(newValue, forKey: "sift.autoApplyOrganizeRules") }
    }

    public init(store: MediaIndexStore) {
        self.store = store
    }

    public var rules: [OrganizeRule] {
        get { OrganizeRulesStore.load() }
        set { OrganizeRulesStore.save(newValue) }
    }

    public func suggestions(
        for records: [MediaAssetRecord],
        sourceRoots: [URL],
        destinationRoot: URL?
    ) -> [OrganizeRuleSuggestion] {
        let inbox = InboxFilter.filterInbox(
            records,
            sourceRoots: sourceRoots,
            destinationRoot: destinationRoot
        )
        var results: [OrganizeRuleSuggestion] = []
        for record in inbox {
            guard let rule = firstMatchingRule(for: record) else { continue }
            results.append(
                OrganizeRuleSuggestion(
                    assetID: record.id,
                    fileName: record.fileURL.lastPathComponent,
                    ruleName: rule.name,
                    bucket: rule.bucket
                )
            )
        }
        return results
    }

    private func firstMatchingRule(for record: MediaAssetRecord) -> OrganizeRule? {
        for rule in rules where rule.isEnabled {
            if let pipeline = rule.pipeline, record.pipeline != pipeline { continue }
            if let kind = rule.kind, record.kind != kind { continue }
            if let label = rule.sourceLabel, record.sourceLabel != label { continue }
            return rule
        }
        return nil
    }
}
