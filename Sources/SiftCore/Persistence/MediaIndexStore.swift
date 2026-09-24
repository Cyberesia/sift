import Foundation
import SwiftData

@MainActor
public final class MediaIndexStore: ObservableObject {
    public var modelContext: ModelContext { context }
    private let context: ModelContext

    @Published public private(set) var assetCount: Int = 0
    @Published public private(set) var analyzedCount: Int = 0

    public init(container: ModelContainer? = nil) {
        self.context = ModelContext(container ?? StratumSchema.modelContainer)
        context.autosaveEnabled = false
        refreshCounts()
    }

    public func refreshCounts() {
        assetCount = (try? context.fetchCount(FetchDescriptor<MediaAssetRecord>())) ?? 0
        let analyzedDescriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate { $0.isAnalyzed }
        )
        analyzedCount = (try? context.fetchCount(analyzedDescriptor)) ?? 0
    }

    public func fetchSources() throws -> [IndexedSource] {
        let descriptor = FetchDescriptor<IndexedSource>(
            sortBy: [SortDescriptor(\.displayName)]
        )
        return try context.fetch(descriptor)
    }

    public func upsertSource(_ source: IndexedSource) throws {
        context.insert(source)
        try context.save()
    }

    public func removeSource(id: String) throws {
        let descriptor = FetchDescriptor<IndexedSource>(
            predicate: #Predicate { $0.id == id }
        )
        if let source = try context.fetch(descriptor).first {
            context.delete(source)
            try context.save()
        }
    }

    public func fetchAssets(
        pipeline: MediaPipeline = .all,
        sourceLabel: String? = nil,
        limit: Int? = nil
    ) throws -> [MediaAssetRecord] {
        var records: [MediaAssetRecord]
        if pipeline == .all {
            records = try context.fetch(FetchDescriptor<MediaAssetRecord>())
        } else if pipeline == .photography {
            let photoRaw = MediaPipeline.photography.rawValue
            let videoKind = MediaKind.video.rawValue
            records = try context.fetch(FetchDescriptor(
                predicate: #Predicate { $0.pipelineRaw == photoRaw && $0.kindRaw != videoKind }
            ))
        } else if pipeline == .videos {
            let videoRaw = MediaPipeline.videos.rawValue
            let videoKind = MediaKind.video.rawValue
            records = try context.fetch(FetchDescriptor(
                predicate: #Predicate {
                    $0.pipelineRaw == videoRaw || $0.kindRaw == videoKind
                }
            ))
        } else {
            let raw = pipeline.rawValue
            records = try context.fetch(FetchDescriptor(
                predicate: #Predicate { $0.pipelineRaw == raw }
            ))
        }

        if let sourceLabel, !sourceLabel.isEmpty {
            let label = sourceLabel
            records = records.filter { $0.sourceLabel == label }
        }
        if let limit {
            records = Array(records.prefix(limit))
        }
        return records
    }

    public func fetchAssetsPage(
        pipeline: MediaPipeline = .all,
        sourceLabel: String? = nil,
        sort: LibraryAssetSort,
        offset: Int,
        limit: Int
    ) throws -> [MediaAssetRecord] {
        var descriptor = FetchDescriptor<MediaAssetRecord>()
        if pipeline == .photography {
            let raw = MediaPipeline.photography.rawValue
            let video = MediaKind.video.rawValue
            descriptor.predicate = #Predicate { $0.pipelineRaw == raw && $0.kindRaw != video }
        } else if pipeline == .videos {
            let raw = MediaPipeline.videos.rawValue
            let video = MediaKind.video.rawValue
            descriptor.predicate = #Predicate { $0.pipelineRaw == raw || $0.kindRaw == video }
        } else if pipeline != .all {
            let raw = pipeline.rawValue
            descriptor.predicate = #Predicate { $0.pipelineRaw == raw }
        }
        descriptor.sortBy = switch sort {
        case .dateModifiedNewest:
            [SortDescriptor(\.modifiedAt, order: .reverse), SortDescriptor(\.indexedAt, order: .reverse)]
        case .dateModifiedOldest:
            [SortDescriptor(\.modifiedAt), SortDescriptor(\.indexedAt)]
        case .fileNameAZ:
            [SortDescriptor(\.fileURLString)]
        case .fileNameZA:
            [SortDescriptor(\.fileURLString, order: .reverse)]
        case .fileSizeLargest:
            [SortDescriptor(\.fileSize, order: .reverse)]
        case .fileSizeSmallest:
            [SortDescriptor(\.fileSize)]
        }
        descriptor.fetchOffset = max(0, offset)
        descriptor.fetchLimit = max(1, limit)
        var records = try context.fetch(descriptor)
        if let sourceLabel, !sourceLabel.isEmpty {
            records = records.filter { $0.sourceLabel == sourceLabel }
        }
        return records
    }

    public func fetchAssetsFiltered(
        pipeline: MediaPipeline = .all,
        sourceLabel: String? = nil,
        sourceRoot: URL? = nil,
        subfolder: String? = nil,
        sort: LibraryAssetSort = .dateModifiedNewest,
        limit: Int? = nil
    ) throws -> [MediaAssetRecord] {
        var records = try fetchAssets(pipeline: pipeline, sourceLabel: sourceLabel)
        if let sourceRoot {
            records = records.filter {
                LibraryBrowseFilter.matchesSubfolder(
                    fileURL: $0.fileURL,
                    sourceRoot: sourceRoot,
                    subfolder: subfolder
                )
            }
        }
        records = LibraryBrowseFilter.sortRecords(records, by: sort)
        if let limit {
            records = Array(records.prefix(limit))
        }
        return records
    }

    /// Ensures videos are in the Videos pipeline (legacy rows indexed before kind-based routing).
    public func normalizePipelinesByKind() throws {
        let videoKind = MediaKind.video.rawValue
        let videosRaw = MediaPipeline.videos.rawValue
        let descriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate { $0.kindRaw == videoKind && $0.pipelineRaw != videosRaw }
        )
        let mismatched = try context.fetch(descriptor)
        guard !mismatched.isEmpty else { return }
        for record in mismatched {
            record.pipeline = .videos
        }
        try context.save()
    }

    /// Drops catalog rows and their thumbnails. The caller moves the original files.
    public func forgetAssets(ids: [String]) throws {
        guard !ids.isEmpty else { return }
        for id in ids {
            guard let record = try fetchAsset(id: id) else { continue }
            ThumbnailCache.deleteIfCached(record.thumbnailPath)
            context.delete(record)
        }
        try flush()
    }

    public func fetchAsset(id: String) throws -> MediaAssetRecord? {
        let descriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    public func fetchAssets(ids: [String]) throws -> [MediaAssetRecord] {
        guard !ids.isEmpty else { return [] }
        let idSet = Set(ids)
        let descriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate { idSet.contains($0.id) }
        )
        return try context.fetch(descriptor)
    }

    public func upsertDiscovered(_ items: [DiscoveredMedia]) throws -> Int {
        var inserted = 0
        for item in items {
            let itemID = item.id
            let descriptor = FetchDescriptor<MediaAssetRecord>(
                predicate: #Predicate { $0.id == itemID }
            )
            if let existing = try context.fetch(descriptor).first {
                if existing.contentHash != item.contentHash {
                    existing.contentHash = item.contentHash
                    existing.modifiedAt = item.modifiedAt
                    existing.isAnalyzed = false
                    existing.clipEmbeddingData = nil
                    existing.clipModelVersion = nil
                    existing.clipContentHash = nil
                }
                continue
            }
            let initialPipeline: MediaPipeline = switch item.kind {
            case .video: .videos
            case .audio: .music
            case .document: .documents
            case .image: .photography
            }
            let record = MediaAssetRecord(
                id: item.id,
                fileURLString: item.url.path,
                kindRaw: item.kind.rawValue,
                sourceKindRaw: item.sourceKind.rawValue,
                sourceLabel: item.sourceLabel,
                fileSize: item.fileSize,
                contentHash: item.contentHash,
                createdAt: item.createdAt,
                modifiedAt: item.modifiedAt,
                pipelineRaw: initialPipeline.rawValue
            )
            context.insert(record)
            inserted += 1
        }
        try context.save()
        refreshCounts()
        return inserted
    }

    public func applyAnalysis(
        assetID: String,
        result: PhotoAnalysisResult,
        pipeline: MediaPipeline,
        persist: Bool = true
    ) throws {
        guard let record = try fetchAsset(id: assetID) else { return }
        record.isAnalyzed = true
        record.isScreenshotOrDocument = result.isScreenshotOrDocument
        record.textLineCount = result.textLineCount
        record.topCategories = result.topCategories
        record.detectedAnimals = result.detectedAnimals
        record.faceCount = result.faceCount
        record.featurePrintData = result.featurePrintData
        record.recognizedTextLines = result.recognizedText
        record.pipeline = pipeline
        if persist { try flush() }
    }

    public func setThumbnailPath(assetID: String, path: String) throws {
        try setThumbnailPaths([assetID: path])
    }

    public func setThumbnailPaths(_ paths: [String: String]) throws {
        guard !paths.isEmpty else { return }
        for (assetID, path) in paths {
            guard let record = try fetchAsset(id: assetID) else { continue }
            record.thumbnailPath = path
        }
        try flush()
    }

    public func thumbnailPendingCount() throws -> Int {
        let document = MediaKind.document.rawValue
        return try context.fetchCount(
            FetchDescriptor<MediaAssetRecord>(
                predicate: #Predicate { $0.thumbnailPath == nil && $0.kindRaw != document }
            )
        )
    }

    public func fetchThumbnailPending(offset: Int = 0, limit: Int = 40) throws -> [MediaAssetRecord] {
        let document = MediaKind.document.rawValue
        var descriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate { $0.thumbnailPath == nil && $0.kindRaw != document }
        )
        descriptor.fetchOffset = max(0, offset)
        descriptor.fetchLimit = max(1, limit)
        return try context.fetch(descriptor)
    }

    public func fetchUnanalyzed(limit: Int = 32) throws -> [MediaAssetRecord] {
        var descriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate { !$0.isAnalyzed }
        )
        descriptor.fetchLimit = max(1, limit)
        return try context.fetch(descriptor)
    }

    public func setClipEmbedding(assetID: String, vector: [Float]) throws {
        try setClipEmbeddings([(assetID, vector)])
    }

    public func setClipEmbeddings(_ updates: [(id: String, vector: [Float])]) throws {
        guard !updates.isEmpty else { return }
        for update in updates where update.vector.count == ClipEmbeddingStore.vectorDimension {
            guard let record = try fetchAsset(id: update.id) else { continue }
            record.clipEmbeddingData = update.vector.withUnsafeBufferPointer { Data(buffer: $0) }
            record.clipModelVersion = ClipEmbeddingStore.modelVersion
            record.clipContentHash = record.contentHash
        }
        try flush()
    }

    public func flush() throws {
        if context.hasChanges {
            try context.save()
        }
        refreshCounts()
    }

    public func clipCatalog() throws -> [(id: String, vector: [Float])] {
        try fetchAssets().compactMap { record in
            guard record.clipModelVersion == ClipEmbeddingStore.modelVersion,
                  record.clipContentHash == record.contentHash,
                  let vector = record.clipEmbedding else { return nil }
            return (record.id, vector)
        }
    }

    public func count(kind: MediaKind) throws -> Int {
        let raw = kind.rawValue
        return try context.fetchCount(
            FetchDescriptor<MediaAssetRecord>(predicate: #Predicate { $0.kindRaw == raw })
        )
    }

    public func clipEmbeddedCount() throws -> Int {
        let version = ClipEmbeddingStore.modelVersion
        return try context.fetchCount(
            FetchDescriptor<MediaAssetRecord>(
                predicate: #Predicate { $0.clipModelVersion == version && $0.clipEmbeddingData != nil }
            )
        )
    }

    public func clipPendingCount() throws -> Int {
        let version = ClipEmbeddingStore.modelVersion
        let audio = MediaKind.audio.rawValue
        return try context.fetchCount(
            FetchDescriptor<MediaAssetRecord>(
                predicate: #Predicate {
                    $0.kindRaw != audio && $0.thumbnailPath != nil
                        && ($0.clipEmbeddingData == nil || $0.clipModelVersion != version)
                }
            )
        )
    }

    public func fetchClipJobs(limit: Int = 32) throws -> [(id: String, path: String, name: String)] {
        let version = ClipEmbeddingStore.modelVersion
        let audio = MediaKind.audio.rawValue
        var descriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate {
                $0.kindRaw != audio && $0.thumbnailPath != nil
                    && ($0.clipEmbeddingData == nil || $0.clipModelVersion != version)
            }
        )
        descriptor.fetchLimit = max(1, limit)
        let records = try context.fetch(descriptor)
        return records.compactMap { record in
            guard let path = record.thumbnailPath else { return nil }
            return (record.id, path, record.fileURL.lastPathComponent)
        }
    }

    public func fetchCollections(pipeline: MediaPipeline? = nil) throws -> [StratumCollectionRecord] {
        var descriptor = FetchDescriptor<StratumCollectionRecord>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.title)]
        )
        if let pipeline {
            let raw = pipeline.rawValue
            descriptor.predicate = #Predicate { $0.pipelineRaw == raw }
        }
        return try context.fetch(descriptor)
    }

    public func upsertCollection(_ collection: StratumCollectionRecord) throws {
        context.insert(collection)
        try context.save()
    }

    public func upsertSuggestedPerson(
        id: String,
        title: String,
        sortOrder: Int,
        members: [MediaAssetRecord]
    ) throws {
        let targetID = id
        let descriptor = FetchDescriptor<StratumCollectionRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        let collection = try context.fetch(descriptor).first ?? {
            let created = StratumCollectionRecord(
                id: id,
                title: title,
                pipelineRaw: MediaPipeline.people.rawValue,
                isSuggested: true,
                isAccepted: false,
                sortOrder: sortOrder,
                collectionKindRaw: CollectionKind.person.rawValue
            )
            context.insert(created)
            return created
        }()
        guard !collection.isAccepted else { return }
        collection.title = collection.userTitle?.isEmpty == false ? collection.title : title
        collection.isSuggested = true
        collection.collectionKind = .person
        collection.assets = members
        try context.save()
    }

    public func searchAssets(
        query: String,
        includeFileNames: Bool = false,
        includeRecognizedText: Bool = true,
        limit: Int = 80
    ) throws -> [MediaAssetRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try fetchAssets(limit: limit)
        }
        let lower = trimmed.lowercased()
        let title = trimmed.prefix(1).uppercased() + trimmed.dropFirst().lowercased()
        let candidateLimit = max(limit * 8, 200)
        var categoryDescriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate {
                ($0.topCategoriesJSON?.contains(lower) ?? false)
                    || ($0.topCategoriesJSON?.contains(title) ?? false)
            }
        )
        categoryDescriptor.fetchLimit = candidateLimit
        var animalDescriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate {
                ($0.detectedAnimalsJSON?.contains(lower) ?? false)
                    || ($0.detectedAnimalsJSON?.contains(title) ?? false)
            }
        )
        animalDescriptor.fetchLimit = candidateLimit
        var candidates = try context.fetch(categoryDescriptor)
        candidates.append(contentsOf: try context.fetch(animalDescriptor))
        if includeRecognizedText {
            var textDescriptor = FetchDescriptor<MediaAssetRecord>(
                predicate: #Predicate {
                    ($0.recognizedTextJSON?.contains(trimmed) ?? false)
                }
            )
            textDescriptor.fetchLimit = candidateLimit
            candidates.append(contentsOf: try context.fetch(textDescriptor))
            if title != trimmed {
                var titleDescriptor = FetchDescriptor<MediaAssetRecord>(
                    predicate: #Predicate {
                        ($0.recognizedTextJSON?.contains(title) ?? false)
                    }
                )
                titleDescriptor.fetchLimit = candidateLimit
                candidates.append(contentsOf: try context.fetch(titleDescriptor))
            }
        }
        if includeFileNames {
            var nameDescriptor = FetchDescriptor<MediaAssetRecord>(
                predicate: #Predicate {
                    $0.fileURLString.contains(trimmed)
                        || $0.fileURLString.contains(lower)
                        || $0.fileURLString.contains(title)
                }
            )
            nameDescriptor.fetchLimit = candidateLimit
            candidates.append(contentsOf: try context.fetch(nameDescriptor))
        }
        var seenCandidates = Set<String>()
        candidates = candidates.filter { seenCandidates.insert($0.id).inserted }
        let personLookup = try buildPersonNameLookup()
        let matched = candidates.filter { record in
            let content = [
                record.topCategories.joined(separator: " "),
                record.detectedAnimals.joined(separator: " "),
                includeRecognizedText ? record.recognizedTextLines.joined(separator: " ") : "",
                personLookup[record.id] ?? "",
            ].joined(separator: " ")
            if SearchTermMatcher.containsTerm(trimmed, in: content) { return true }
            guard includeFileNames else { return false }
            return SearchTermMatcher.containsTerm(trimmed, in: record.fileURL.lastPathComponent)
                || SearchTermMatcher.containsTerm(trimmed, in: record.sourceLabel)
        }
        return matched.sorted { lhs, rhs in
            let lhsAnimal = SearchTermMatcher.containsTerm(trimmed, in: lhs.detectedAnimals.joined(separator: " "))
            let rhsAnimal = SearchTermMatcher.containsTerm(trimmed, in: rhs.detectedAnimals.joined(separator: " "))
            if lhsAnimal != rhsAnimal { return lhsAnimal }
            return false
        }.prefix(limit).map { $0 }
    }

    public func acceptCollection(id: String) throws {
        let targetID = id
        let descriptor = FetchDescriptor<StratumCollectionRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        guard let collection = try context.fetch(descriptor).first else { return }
        collection.isAccepted = true
        collection.isSuggested = false
        try context.save()
    }

    public func rejectCollection(id: String) throws {
        var dismissed = UserDefaults.standard.stringArray(forKey: "sift.dismissedCollectionIDs") ?? []
        if !dismissed.contains(id) {
            dismissed.append(id)
            UserDefaults.standard.set(dismissed, forKey: "sift.dismissedCollectionIDs")
        }
        let targetID = id
        let descriptor = FetchDescriptor<StratumCollectionRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        if let collection = try context.fetch(descriptor).first {
            context.delete(collection)
            try context.save()
        }
    }

    public func wipeCatalog() throws {
        for record in try context.fetch(FetchDescriptor<MediaAssetRecord>()) {
            ThumbnailCache.deleteIfCached(record.thumbnailPath)
            context.delete(record)
        }
        for collection in try context.fetch(FetchDescriptor<StratumCollectionRecord>()) {
            context.delete(collection)
        }
        for transfer in try context.fetch(FetchDescriptor<TransferRecord>()) {
            context.delete(transfer)
        }
        for search in try context.fetch(FetchDescriptor<SavedSearchRecord>()) {
            context.delete(search)
        }
        try context.save()
        refreshCounts()
    }

    public func fetchSavedSearches() throws -> [SavedSearchRecord] {
        try context.fetch(FetchDescriptor(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
    }

    public func saveSearch(name: String, query: String, pipeline: MediaPipeline, scope: LibraryBrowseScope, sort: LibraryAssetSort) throws {
        let scopeRaw: String = {
            switch scope {
            case .allSources: return "all"
            case .entireCatalog: return "catalog"
            case .inbox: return "inbox"
            case .source(let id, let sub):
                return "source|\(id)|\(sub ?? "")"
            }
        }()
        context.insert(
            SavedSearchRecord(
                name: name,
                query: query,
                pipelineRaw: pipeline.rawValue,
                browseScopeRaw: scopeRaw,
                sortRaw: sort.rawValue
            )
        )
        try context.save()
    }

    public func assignCluster(assetID: String, clusterID: String?, personClusterID: String?) throws {
        guard let record = try fetchAsset(id: assetID) else { return }
        record.clusterID = clusterID
        record.personClusterID = personClusterID
        try context.save()
    }

    /// Drops catalog rows for a source whose files sit in a subfolder. Files on disk stay.
    @discardableResult
    public func removeAssetsNotDirectlyInFolder(sourceLabel: String, rootPath: String) throws -> Int {
        let label = sourceLabel
        let root = URL(fileURLWithPath: rootPath).standardizedFileURL.path
        let descriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate { $0.sourceLabel == label }
        )
        let records = try context.fetch(descriptor)
        var removed = 0
        for record in records {
            let parent = URL(fileURLWithPath: record.fileURLString)
                .deletingLastPathComponent()
                .standardizedFileURL
                .path
            guard parent != root else { continue }
            ThumbnailCache.deleteIfCached(record.thumbnailPath)
            context.delete(record)
            removed += 1
        }
        if removed > 0 {
            try context.save()
            refreshCounts()
        }
        return removed
    }

    /// Removes indexed assets (and thumbnails) tied to a folder source label, e.g. "Downloads".
    @discardableResult
    public func removeAssets(sourceLabel: String) throws -> Int {
        let label = sourceLabel
        let descriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate { $0.sourceLabel == label }
        )
        let records = try context.fetch(descriptor)
        for record in records {
            ThumbnailCache.deleteIfCached(record.thumbnailPath)
            context.delete(record)
        }
        try context.save()
        refreshCounts()
        return records.count
    }

    public func updateAssetPath(assetID: String, newURL: URL) throws {
        guard let record = try fetchAsset(id: assetID) else { return }
        record.fileURLString = newURL.path
        record.modifiedAt = Date()
        try context.save()
    }

    /// Clears Vision analysis and suggested smart groups so AI tagging can run again from scratch.
    public func resetAIAnalysis() throws {
        let assets = try fetchAssets()
        for record in assets {
            record.isAnalyzed = false
            record.textLineCount = 0
            record.isScreenshotOrDocument = false
            record.topCategories = []
            record.detectedAnimals = []
            record.faceCount = 0
            record.featurePrintData = nil
            record.clusterID = nil
            record.personClusterID = nil
            record.pipeline = .photography
        }
        let collections = try fetchCollections()
        for collection in collections where collection.isSuggested {
            context.delete(collection)
        }
        try context.save()
        refreshCounts()
    }

    public func unanalyzedCount() throws -> Int {
        try context.fetchCount(
            FetchDescriptor<MediaAssetRecord>(predicate: #Predicate { !$0.isAnalyzed })
        )
    }

    public func renamePersonGroup(id: String, userTitle: String?) throws {
        let collection = try ensurePersonCollection(id: id, title: userTitle ?? defaultPersonTitle(id))
        collection.userTitle = userTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let userTitle, !userTitle.isEmpty {
            collection.title = userTitle
        }
        try context.save()
    }

    public func renameCollection(id: String, userTitle: String?) throws {
        let targetID = id
        let descriptor = FetchDescriptor<StratumCollectionRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        guard let record = try context.fetch(descriptor).first else { return }
        record.userTitle = userTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        try context.save()
    }

    // MARK: - Person labels

    /// Drops suggested person cards that have no linked photos, then returns one group per saved face cluster.
    public func personReviewGroups() throws -> [PersonReviewGroup] {
        let dismissed = Set(UserDefaults.standard.stringArray(forKey: "sift.dismissedCollectionIDs") ?? [])
        let descriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate { $0.personClusterID != nil }
        )
        let clustered = try context.fetch(descriptor)
        let named = Dictionary(uniqueKeysWithValues: try fetchPersonCollections().map { ($0.id, $0) })
        let grouped = Dictionary(grouping: clustered) { $0.personClusterID ?? "" }

        var removed = false
        for collection in named.values where collection.isSuggested && !collection.isAccepted {
            let linked = grouped[collection.id]?.isEmpty == false
            let stored = collection.assets?.isEmpty == false
            if !linked && !stored {
                context.delete(collection)
                removed = true
            }
        }
        if removed { try context.save() }

        return grouped.compactMap { id, assets -> PersonReviewGroup? in
            guard !id.isEmpty, !dismissed.contains(id), assets.count >= 2 else { return nil }
            if named[id]?.isAccepted == true { return nil }
            let title = named[id]?.displayTitle ?? defaultPersonTitle(id)
            let previews = assets.prefix(4).map {
                PersonReviewPreview(id: $0.id, thumbnailPath: $0.thumbnailPath)
            }
            return PersonReviewGroup(
                id: id,
                title: title,
                assetIDs: assets.map(\.id),
                previews: previews,
                count: assets.count
            )
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public func acceptPersonGroup(id: String, title: String) throws {
        let collection = try ensurePersonCollection(id: id, title: title)
        collection.isAccepted = true
        collection.isSuggested = false
        collection.userTitle = title
        collection.title = title
        try context.save()
    }

    private func ensurePersonCollection(id: String, title: String) throws -> StratumCollectionRecord {
        let targetID = id
        let descriptor = FetchDescriptor<StratumCollectionRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let created = StratumCollectionRecord(
            id: id,
            title: title,
            pipelineRaw: MediaPipeline.people.rawValue,
            isSuggested: true,
            isAccepted: false,
            sortOrder: 10,
            collectionKindRaw: CollectionKind.person.rawValue
        )
        let members = try context.fetch(FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate { $0.personClusterID == targetID }
        ))
        created.assets = members
        context.insert(created)
        return created
    }

    private func defaultPersonTitle(_ id: String) -> String {
        if let number = id.split(separator: "-").last, let value = Int(number) {
            return "Person \(value + 1)"
        }
        return "Person"
    }

    public func fetchPersonCollections() throws -> [StratumCollectionRecord] {
        let personKind = CollectionKind.person.rawValue
        let descriptor = FetchDescriptor<StratumCollectionRecord>(
            predicate: #Predicate { $0.collectionKindRaw == personKind },
            sortBy: [SortDescriptor(\.title)]
        )
        return try context.fetch(descriptor)
    }

    public func personDisplayName(for assetID: String) throws -> String? {
        guard let asset = try fetchAsset(id: assetID),
              let collection = try findPersonCollection(for: asset) else {
            return nil
        }
        return userFacingPersonTitle(collection)
    }

    public func setPersonLabel(assetID: String, name: String) throws {
        guard let asset = try fetchAsset(id: assetID) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            if let collection = try findPersonCollection(for: asset) {
                collection.assets = collection.assets?.filter { $0.id != assetID }
            }
            asset.personClusterID = nil
            if asset.kind != .video {
                asset.pipeline = asset.faceCount > 0 ? .people : .photography
            }
            try context.save()
            return
        }

        let clusterID = asset.personClusterID ?? "person-\(assetID)"
        asset.personClusterID = clusterID
        if asset.kind != .video {
            asset.pipeline = .people
        }

        let targetID = clusterID
        let descriptor = FetchDescriptor<StratumCollectionRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        let collection = try context.fetch(descriptor).first ?? {
            let created = StratumCollectionRecord(
                id: clusterID,
                title: trimmed,
                pipelineRaw: MediaPipeline.people.rawValue,
                isSuggested: false,
                isAccepted: true,
                sortOrder: 5,
                userTitle: trimmed,
                collectionKindRaw: CollectionKind.person.rawValue
            )
            context.insert(created)
            return created
        }()

        collection.userTitle = trimmed
        collection.title = trimmed
        collection.isSuggested = false
        collection.isAccepted = true
        collection.collectionKind = .person
        collection.pipeline = .people
        var members = collection.assets ?? []
        if !members.contains(where: { $0.id == assetID }) {
            members.append(asset)
        }
        collection.assets = members
        try context.save()
    }

    private func findPersonCollection(for asset: MediaAssetRecord) throws -> StratumCollectionRecord? {
        if let pid = asset.personClusterID {
            let targetID = pid
            let byID = FetchDescriptor<StratumCollectionRecord>(
                predicate: #Predicate { $0.id == targetID }
            )
            if let hit = try context.fetch(byID).first {
                return hit
            }
        }
        let personKind = CollectionKind.person.rawValue
        let assetID = asset.id
        let all = try context.fetch(FetchDescriptor<StratumCollectionRecord>(
            predicate: #Predicate { $0.collectionKindRaw == personKind }
        ))
        return all.first { $0.assets?.contains(where: { $0.id == assetID }) == true }
    }

    private func userFacingPersonTitle(_ collection: StratumCollectionRecord) -> String? {
        if let userTitle = collection.userTitle, !userTitle.isEmpty {
            return userTitle
        }
        let title = collection.title
        if title.range(of: #"^Person \d+$"#, options: .regularExpression) != nil {
            return nil
        }
        return title.isEmpty ? nil : title
    }

    public func buildPersonNameLookup() throws -> [String: String] {
        var lookup: [String: String] = [:]
        for collection in try fetchPersonCollections() {
            guard let label = userFacingPersonTitle(collection) else { continue }
            for asset in collection.assets ?? [] {
                lookup[asset.id] = label
            }
        }
        return lookup
    }
}
