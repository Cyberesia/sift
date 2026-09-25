import Foundation
@preconcurrency import SwiftData
import os.log

@Model
public final class IndexedSource {
    @Attribute(.unique) public var id: String
    public var displayName: String
    public var sourceKindRaw: String
    public var bookmarkData: Data?
    public var isEnabled: Bool
    public var lastScannedAt: Date?

    public init(
        id: String = UUID().uuidString,
        displayName: String,
        sourceKindRaw: String,
        bookmarkData: Data? = nil,
        isEnabled: Bool = true,
        lastScannedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.sourceKindRaw = sourceKindRaw
        self.bookmarkData = bookmarkData
        self.isEnabled = isEnabled
        self.lastScannedAt = lastScannedAt
    }

    public var sourceKind: MediaSourceKind {
        get { MediaSourceKind(rawValue: sourceKindRaw) ?? .folder }
        set { sourceKindRaw = newValue.rawValue }
    }
}

@Model
public final class MediaAssetRecord {
    @Attribute(.unique) public var id: String
    public var fileURLString: String
    public var kindRaw: String
    public var sourceKindRaw: String
    public var sourceLabel: String
    public var fileSize: Int64?
    public var contentHash: String
    public var createdAt: Date?
    public var modifiedAt: Date?
    public var indexedAt: Date
    public var pipelineRaw: String
    public var thumbnailPath: String?
    public var isAnalyzed: Bool
    public var textLineCount: Int
    public var isScreenshotOrDocument: Bool
    public var topCategoriesJSON: String?
    public var detectedAnimalsJSON: String?
    public var faceCount: Int
    public var featurePrintData: Data?
    public var clipEmbeddingData: Data?
    public var clipModelVersion: String?
    public var clipContentHash: String?
    public var recognizedTextJSON: String?
    public var clusterID: String?
    public var personClusterID: String?
    public var fileExtension: String?
    public var uti: String?
    public var pixelWidth: Int?
    public var pixelHeight: Int?
    public var durationSeconds: Double?
    public var captureDate: Date?
    public var screenshotReason: String?
    public var labelScoresJSON: String?
    public var rejectedLabelsJSON: String?
    /// Folder name of a transfer the user undid. The next plan holds the file instead of repeating it.
    public var undoneFolder: String?
    public var evidenceVersion: Int = 0

    public init(
        id: String,
        fileURLString: String,
        kindRaw: String,
        sourceKindRaw: String,
        sourceLabel: String,
        fileSize: Int64?,
        contentHash: String,
        createdAt: Date?,
        modifiedAt: Date?,
        indexedAt: Date = .now,
        pipelineRaw: String = MediaPipeline.photography.rawValue,
        thumbnailPath: String? = nil,
        isAnalyzed: Bool = false,
        textLineCount: Int = 0,
        isScreenshotOrDocument: Bool = false,
        topCategoriesJSON: String? = nil,
        detectedAnimalsJSON: String? = nil,
        faceCount: Int = 0,
        featurePrintData: Data? = nil,
        clipEmbeddingData: Data? = nil,
        clipModelVersion: String? = nil,
        clipContentHash: String? = nil,
        recognizedTextJSON: String? = nil,
        clusterID: String? = nil,
        personClusterID: String? = nil
    ) {
        self.id = id
        self.fileURLString = fileURLString
        self.kindRaw = kindRaw
        self.sourceKindRaw = sourceKindRaw
        self.sourceLabel = sourceLabel
        self.fileSize = fileSize
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.indexedAt = indexedAt
        self.pipelineRaw = pipelineRaw
        self.thumbnailPath = thumbnailPath
        self.isAnalyzed = isAnalyzed
        self.textLineCount = textLineCount
        self.isScreenshotOrDocument = isScreenshotOrDocument
        self.topCategoriesJSON = topCategoriesJSON
        self.detectedAnimalsJSON = detectedAnimalsJSON
        self.faceCount = faceCount
        self.featurePrintData = featurePrintData
        self.clipEmbeddingData = clipEmbeddingData
        self.clipModelVersion = clipModelVersion
        self.clipContentHash = clipContentHash
        self.recognizedTextJSON = recognizedTextJSON
        self.clusterID = clusterID
        self.personClusterID = personClusterID
    }

    public var recognizedTextLines: [String] {
        get {
            guard let recognizedTextJSON,
                  let data = recognizedTextJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            recognizedTextJSON = try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)
        }
    }

    public var fileURL: URL { URL(fileURLWithPath: fileURLString) }

    public var clipEmbedding: [Float]? {
        guard let clipEmbeddingData,
              clipEmbeddingData.count == ClipEmbeddingStore.vectorDimension * MemoryLayout<Float>.size else {
            return nil
        }
        return clipEmbeddingData.withUnsafeBytes {
            Array($0.bindMemory(to: Float.self))
        }
    }

    public var kind: MediaKind {
        get { MediaKind(rawValue: kindRaw) ?? .image }
        set { kindRaw = newValue.rawValue }
    }

    public var pipeline: MediaPipeline {
        get { MediaPipeline(rawValue: pipelineRaw) ?? .photography }
        set { pipelineRaw = newValue.rawValue }
    }

    public var topCategories: [String] {
        get {
            guard let topCategoriesJSON,
                  let data = topCategoriesJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            topCategoriesJSON = try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)
        }
    }

    public var detectedAnimals: [String] {
        get {
            guard let detectedAnimalsJSON,
                  let data = detectedAnimalsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            detectedAnimalsJSON = try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)
        }
    }

    public var labelScores: [LabelScore] {
        get {
            guard let labelScoresJSON,
                  let data = labelScoresJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([LabelScore].self, from: data) else { return [] }
            return decoded
        }
        set {
            labelScoresJSON = try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)
        }
    }

    public var rejectedLabels: [String] {
        get {
            guard let rejectedLabelsJSON,
                  let data = rejectedLabelsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            rejectedLabelsJSON = newValue.isEmpty
                ? nil
                : try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)
        }
    }
}

@Model
public final class TransferRecord {
    @Attribute(.unique) public var id: String
    public var assetID: String
    public var sourcePath: String
    public var destinationPath: String
    public var modeRaw: String
    public var timestamp: Date
    public var isUndone: Bool

    public init(
        id: String = UUID().uuidString,
        assetID: String,
        sourcePath: String,
        destinationPath: String,
        modeRaw: String,
        timestamp: Date = .now,
        isUndone: Bool = false
    ) {
        self.id = id
        self.assetID = assetID
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.modeRaw = modeRaw
        self.timestamp = timestamp
        self.isUndone = isUndone
    }

    public var mode: FileTransferMode {
        get { FileTransferMode(rawValue: modeRaw) ?? .move }
        set { modeRaw = newValue.rawValue }
    }
}

@Model
public final class SavedSearchRecord {
    @Attribute(.unique) public var id: String
    public var name: String
    public var query: String
    public var pipelineRaw: String
    public var browseScopeRaw: String
    public var sortRaw: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        query: String,
        pipelineRaw: String = MediaPipeline.all.rawValue,
        browseScopeRaw: String = "all",
        sortRaw: String = LibraryAssetSort.dateModifiedNewest.rawValue,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.query = query
        self.pipelineRaw = pipelineRaw
        self.browseScopeRaw = browseScopeRaw
        self.sortRaw = sortRaw
        self.createdAt = createdAt
    }
}

@Model
public final class StratumCollectionRecord {
    @Attribute(.unique) public var id: String
    public var title: String
    public var pipelineRaw: String
    public var parentID: String?
    public var isSuggested: Bool
    public var isAccepted: Bool
    public var sortOrder: Int
    public var createdAt: Date
    public var userTitle: String?
    public var collectionKindRaw: String

    @Relationship(deleteRule: .nullify)
    public var assets: [MediaAssetRecord]?

    public init(
        id: String = UUID().uuidString,
        title: String,
        pipelineRaw: String,
        parentID: String? = nil,
        isSuggested: Bool = false,
        isAccepted: Bool = true,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        userTitle: String? = nil,
        collectionKindRaw: String = CollectionKind.custom.rawValue
    ) {
        self.id = id
        self.title = title
        self.pipelineRaw = pipelineRaw
        self.parentID = parentID
        self.isSuggested = isSuggested
        self.isAccepted = isAccepted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.userTitle = userTitle
        self.collectionKindRaw = collectionKindRaw
    }

    public var pipeline: MediaPipeline {
        get { MediaPipeline(rawValue: pipelineRaw) ?? .all }
        set { pipelineRaw = newValue.rawValue }
    }
}

public enum StratumSchema {
    private static let log = Logger(subsystem: "ai.cyclones.sift", category: "SwiftData")
    /// Bump when schema changes so a corrupt prior store is not reopened.
    private static let storeName = "SiftIndex-v4"
    private static let schema = Schema([
        IndexedSource.self,
        MediaAssetRecord.self,
        StratumCollectionRecord.self,
        TransferRecord.self,
        SavedSearchRecord.self,
    ])

    nonisolated(unsafe) private static var cachedContainer: ModelContainer?
    private static let lock = NSLock()

    public static var modelContainer: ModelContainer {
        lock.lock()
        defer { lock.unlock() }
        if let cachedContainer { return cachedContainer }
        let container = makeModelContainer()
        cachedContainer = container
        return container
    }

    public static func makeModelContainer() -> ModelContainer {
        if let container = tryOpenPersistent() {
            return container
        }
        log.warning("Resetting SwiftData store after open failure")
        removeStoreFiles()
        if let container = tryOpenPersistent() {
            return container
        }
        log.error("Persistent store unavailable; using in-memory index")
        return makeInMemoryContainer()
    }

    private static func tryOpenPersistent() -> ModelContainer? {
        do {
            let config = ModelConfiguration(storeName, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            log.error("SwiftData open failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func makeInMemoryContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        } catch {
            preconditionFailure("Sift in-memory SwiftData failed: \(error)")
        }
    }

    private static func removeStoreFiles() {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let base = support.appendingPathComponent(storeName)
        let suffixes = ["", ".store", ".store-shm", ".store-wal"]
        for suffix in suffixes {
            let url = suffix.isEmpty ? base : support.appendingPathComponent(storeName + suffix)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
