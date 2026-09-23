import Foundation

public enum MediaKind: String, Codable, Sendable, CaseIterable {
    case image
    case video
    case audio
    case document

    public var displayName: String {
        switch self {
        case .image: "Photo"
        case .video: "Video"
        case .audio: "Audio"
        case .document: "Document"
        }
    }
}

public enum MediaPipeline: String, Codable, Sendable, CaseIterable, Identifiable {
    case all
    case photography
    case artifacts
    case people
    case places
    case trips
    case videos
    case music
    case documents

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: "All Media"
        case .photography: "Photography"
        case .artifacts: "Artifacts"
        case .people: "People"
        case .places: "Places"
        case .trips: "Trips"
        case .videos: "Videos"
        case .music: "Music"
        case .documents: "Documents"
        }
    }

    public var systemImage: String {
        switch self {
        case .all: "photo.on.rectangle.angled"
        case .photography: "camera.aperture"
        case .artifacts: "doc.text.viewfinder"
        case .people: "person.2"
        case .places: "map"
        case .trips: "airplane"
        case .videos: "film"
        case .music: "music.note"
        case .documents: "doc.text"
        }
    }
}

public enum MediaSourceKind: String, Codable, Sendable {
    case folder
    case photoLibrary
}
