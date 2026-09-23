import Foundation

public enum CollectionKind: String, CaseIterable, Sendable, Codable {
    case person
    case place
    case trip
    case project
    case gather
    case custom

    public var label: String {
        switch self {
        case .person: "Person"
        case .place: "Place"
        case .trip: "Trip"
        case .project: "Project"
        case .gather: "Gather"
        case .custom: "Collection"
        }
    }
}

public extension StratumCollectionRecord {
    var collectionKind: CollectionKind {
        get { CollectionKind(rawValue: collectionKindRaw) ?? .custom }
        set { collectionKindRaw = newValue.rawValue }
    }

    var displayTitle: String {
        if let userTitle, !userTitle.isEmpty { return userTitle }
        return title
    }
}
