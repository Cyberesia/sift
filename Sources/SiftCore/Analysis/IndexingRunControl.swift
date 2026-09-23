import Foundation

public enum IndexingAbortReason: Sendable, Equatable {
    case userStopped
    case userCancelled
}

public struct IndexingAbort: Error, Sendable, Equatable {
    public let reason: IndexingAbortReason
}

/// Cooperative pause / stop / cancel gate shared by scan and analysis loops.
public actor IndexingRunControl {
    public enum Mode: Sendable, Equatable {
        case running
        case paused
        case stopRequested
        case cancelRequested
    }

    private(set) var mode: Mode = .running

    public func reset() {
        mode = .running
    }

    public func pause() {
        guard mode == .running else { return }
        mode = .paused
    }

    public func resume() {
        guard mode == .paused else { return }
        mode = .running
    }

    /// Finish the current unit of work, then exit and keep indexed assets.
    public func requestStop() {
        if mode == .cancelRequested { return }
        mode = .stopRequested
    }

    /// Abort immediately (Task cancellation should also be triggered).
    public func requestCancel() {
        mode = .cancelRequested
    }

    public var isPaused: Bool { mode == .paused }

    /// Called frequently from scan/analysis loops.
    public func checkpoint() async throws {
        while mode == .paused {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(120))
        }
        try Task.checkCancellation()
        switch mode {
        case .cancelRequested:
            throw IndexingAbort(reason: .userCancelled)
        case .stopRequested:
            throw IndexingAbort(reason: .userStopped)
        case .running, .paused:
            break
        }
    }

    /// Returns false when scan should stop enumerating.
    public func shouldContinueScan() async -> Bool {
        if mode == .cancelRequested || mode == .stopRequested { return false }
        if mode == .paused {
            do { try await checkpoint() } catch { return false }
        }
        return mode == .running
    }
}
