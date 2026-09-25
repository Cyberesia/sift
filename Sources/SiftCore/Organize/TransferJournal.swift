import Foundation
import SwiftData

@MainActor
public final class TransferJournal {
    private let store: MediaIndexStore
    private let context: ModelContext

    public init(store: MediaIndexStore) {
        self.store = store
        self.context = store.modelContext
    }

    public func record(
        assetID: String,
        sourcePath: String,
        destinationPath: String,
        mode: FileTransferMode
    ) throws {
        let entry = TransferRecord(
            assetID: assetID,
            sourcePath: sourcePath,
            destinationPath: destinationPath,
            modeRaw: mode.rawValue
        )
        context.insert(entry)
        try context.save()
    }

    public func activeTransfers() throws -> [TransferRecord] {
        try context.fetch(FetchDescriptor<TransferRecord>()).filter { !$0.isUndone }
    }

    public func recent(limit: Int = 20) throws -> [TransferRecord] {
        var descriptor = FetchDescriptor<TransferRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    public func undo(record: TransferRecord) throws {
        guard !record.isUndone else { return }
        let fm = FileManager.default
        guard fm.fileExists(atPath: record.destinationPath) else {
            throw FileTransferError.sourceMissing
        }
        switch record.mode {
        case .copy, .copyThenConfirmDelete:
            if fm.fileExists(atPath: record.sourcePath) {
                try fm.removeItem(atPath: record.destinationPath)
            } else {
                try restoreMovedFile(record, fileManager: fm)
            }
        case .move:
            try restoreMovedFile(record, fileManager: fm)
        }
        try store.updateAssetPath(
            assetID: record.assetID,
            newURL: URL(fileURLWithPath: record.sourcePath)
        )
        record.isUndone = true
        try context.save()
    }

    private func restoreMovedFile(_ record: TransferRecord, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: record.sourcePath) {
            throw FileTransferError.transferFailed("Original path already exists.")
        }
        try fileManager.createDirectory(
            at: URL(fileURLWithPath: record.sourcePath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.moveItem(atPath: record.destinationPath, toPath: record.sourcePath)
    }
}
