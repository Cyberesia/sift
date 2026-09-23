import Foundation

public enum FileTransferMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case move
    case copy
    case copyThenConfirmDelete

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .move: "Move (remove from source)"
        case .copy: "Copy (keep originals)"
        case .copyThenConfirmDelete: "Copy, then remove originals"
        }
    }

    /// Short label for segmented controls in the main window.
    public var shortLabel: String {
        switch self {
        case .move: "Move"
        case .copy: "Copy"
        case .copyThenConfirmDelete: "Copy + confirm"
        }
    }

    public var detail: String {
        switch self {
        case .move: "Files leave their original location."
        case .copy: "Originals stay untouched; duplicates use disk space."
        case .copyThenConfirmDelete: "Copies first; you choose when to delete originals."
        }
    }

    public var stepTitle: String {
        switch self {
        case .move: "Move"
        case .copy: "Copy"
        case .copyThenConfirmDelete: "Copy, then ask"
        }
    }

    public var stepDetail: String {
        switch self {
        case .move: "Originals leave their current folder. They exist only inside the destination."
        case .copy: "Originals stay where they are. You will have a second copy inside the destination."
        case .copyThenConfirmDelete: "A copy is made first. Sift asks before removing the originals."
        }
    }
}

public enum StagingBucket: String, CaseIterable, Sendable, Codable {
    case photos = "Photos"
    case videos = "Videos"
    case gather = "Gather"

    public var folderName: String { rawValue }
}
