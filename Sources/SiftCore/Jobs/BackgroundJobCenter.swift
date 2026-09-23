import Foundation

@MainActor
public final class BackgroundJobCenter: ObservableObject {
    public enum JobKind: String, Sendable {
        case idle
        case discover
        case transfer
        case analyze
        case cluster
    }

    public struct Progress: Sendable, Equatable {
        public var kind: JobKind
        public var title: String
        public var subtitle: String
        public var current: Int
        public var total: Int

        public var fraction: Double? {
            guard total > 0 else { return nil }
            return Double(current) / Double(total)
        }
    }

    @Published public private(set) var progress = Progress(
        kind: .idle,
        title: "Ready",
        subtitle: "",
        current: 0,
        total: 0
    )

    @Published public var islandExpanded = false

    public init() {}

    public func sync(from phase: IndexingCoordinator.Phase) {
        switch phase {
        case .idle:
            progress = Progress(kind: .idle, title: "Ready", subtitle: "On-device", current: 0, total: 0)
        case .scanning(let folder, let count):
            progress = Progress(
                kind: .discover,
                title: "Discovering",
                subtitle: folder,
                current: count,
                total: max(count, 1)
            )
        case .thumbnailing(let current, let total, let name):
            progress = Progress(
                kind: .discover,
                title: "Previews",
                subtitle: name,
                current: current,
                total: total
            )
        case .analyzing(let current, let total, let name):
            progress = Progress(
                kind: .analyze,
                title: "AI tagging",
                subtitle: name,
                current: current,
                total: total
            )
        case .embedding(let current, let total, let name):
            progress = Progress(
                kind: .analyze,
                title: "Visual search",
                subtitle: name,
                current: current,
                total: total
            )
        case .clustering:
            progress = Progress(kind: .cluster, title: "Smart groups", subtitle: "Clustering", current: 0, total: 1)
        case .complete:
            progress = Progress(kind: .idle, title: "Complete", subtitle: "Ready to browse", current: 1, total: 1)
        case .paused:
            progress.title = "Paused"
        case .stopped, .cancelled:
            progress = Progress(kind: .idle, title: "Stopped", subtitle: "", current: 0, total: 0)
        case .failed(let message):
            progress = Progress(kind: .idle, title: "Failed", subtitle: message, current: 0, total: 0)
        }
    }
}
