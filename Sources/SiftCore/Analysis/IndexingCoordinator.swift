import CoreGraphics
import Foundation
import ImageIO
import os.log

@MainActor
public final class IndexingCoordinator: ObservableObject {
    private static let log = Logger(subsystem: "ai.cyclones.sift", category: "Indexing")

    public enum Phase: Sendable, Equatable {
        case idle
        case scanning(folder: String, filesFound: Int)
        case thumbnailing(current: Int, total: Int, fileName: String)
        case analyzing(current: Int, total: Int, fileName: String)
        case embedding(current: Int, total: Int, fileName: String)
        case clustering
        case paused
        case stopped
        case cancelled
        case complete
        case failed(String)
    }

    /// Indexing stays in the dock so the library remains usable.
    public var showsBlockingOverlay: Bool { false }

    @Published public private(set) var discoveryGeneration = 0

    @Published public private(set) var phase: Phase = .idle
    /// Replaces the kind line while a watch update is checking individual files.
    @Published public var activityDetail: String = ""
    @Published public private(set) var lastScanInserted = 0
    @Published public private(set) var isPaused = false

    public var onLibraryChanged: (() -> Void)?
    public var onProgress: (() -> Void)?

    private let store: MediaIndexStore
    private let bookmarkStore: BookmarkStore
    private let scanner = MediaScanner()
    private let analyzer = PhotoAnalyzer()
    private let videoAnalyzer = VideoKeyframeAnalyzer()
    private let photoKitIndexer = PhotoKitIndexer()
    private let runControl = IndexingRunControl()

    private var activeTask: Task<Void, Never>?
    /// Small progressive waves keep the grid useful while large catalogs load.
    private let thumbnailBatchSize = 40

    public init(store: MediaIndexStore, bookmarkStore: BookmarkStore) {
        self.store = store
        self.bookmarkStore = bookmarkStore
    }

    public var isRunning: Bool {
        switch phase {
        case .idle, .complete, .stopped, .cancelled, .failed: false
        case .paused: true
        default: true
        }
    }

    /// Active job with pause / stop / cancel (scan, thumbnails, analyze).
    public var showsTransportControls: Bool {
        if isRunning { return true }
        return false
    }

    /// Finished or interrupted — offer continue, reset AI, or dismiss.
    public var showsRecoveryControls: Bool {
        switch phase {
        case .stopped, .cancelled, .failed:
            return true
        case .complete:
            return ((try? store.unanalyzedCount()) ?? 0) > 0
        default:
            return false
        }
    }

    // MARK: - Transport controls

    public func pauseIndexing() {
        guard showsTransportControls, !isPaused else { return }
        isPaused = true
        Task { await runControl.pause() }
    }

    public func resumeIndexing() {
        if isPaused, activeTask != nil, !activeTask!.isCancelled {
            isPaused = false
            Task { await runControl.resume() }
            return
        }
        if showsRecoveryControls || isPaused {
            continueInterruptedIndexing()
        }
    }

    public func stopIndexing() {
        Task { await runControl.requestStop() }
        activeTask?.cancel()
    }

    public func cancelIndexing() {
        Task { await runControl.requestCancel() }
        activeTask?.cancel()
        phase = .cancelled
        isPaused = false
        notifyLibraryChanged()
    }

    public func dismissIndexingStatus() {
        activeTask?.cancel()
        activeTask = nil
        isPaused = false
        phase = .idle
        Task { await runControl.reset() }
    }

    /// Resume thumbnails and/or AI from where the user left off.
    public func continueInterruptedIndexing(runAnalysis: Bool = true) {
        activeTask?.cancel()
        activeTask = Task { [weak self] in
            guard let self else { return }
            await runControl.reset()
            isPaused = false
            await generateThumbnailsForPending()
            if runAnalysis {
                await analyzePending()
            } else {
                phase = .complete
                notifyLibraryChanged()
            }
        }
    }

    public func resetAIProcessing() throws {
        activeTask?.cancel()
        activeTask = nil
        isPaused = false
        try store.resetAIAnalysis()
        phase = .idle
        Task { await runControl.reset() }
        notifyLibraryChanged()
    }

    public func startFolderIndexing(
        addURL: URL? = nil,
        includeSubfolders: Bool = true,
        includedSubfolderPaths: [String]? = nil,
        scanAllSavedSources: Bool = false,
        runAnalysis: Bool = true,
        kinds: Set<MediaKind> = Set(MediaKind.allCases),
        documentExtensions: Set<String> = DocumentFormats.extensions
    ) {
        guard !isRunning else { return }
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                if let addURL {
                    let bookmark = try bookmarkStore.add(
                        url: addURL,
                        includeSubfolders: includeSubfolders,
                        includedSubfolderPaths: includedSubfolderPaths
                    )
                    if scanAllSavedSources {
                        await runDiscoverPass(bookmarks: bookmarkStore.allBookmarks(), runAnalysis: runAnalysis, kinds: kinds, documentExtensions: documentExtensions)
                    } else {
                        await runDiscoverPass(bookmarks: [bookmark], runAnalysis: runAnalysis, kinds: kinds, documentExtensions: documentExtensions)
                    }
                } else {
                    await runDiscoverPass(bookmarks: bookmarkStore.allBookmarks(), runAnalysis: runAnalysis, kinds: kinds, documentExtensions: documentExtensions)
                }
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    public func startAnalysisPassOnly() {
        guard !isRunning else { return }
        activeTask = Task { [weak self] in
            await self?.analyzePending()
        }
    }

    public func startClipIndexingOnly() {
        guard ClipEmbeddingStore.status == .ready, !isRunning else { return }
        activeTask = Task { [weak self] in
            guard let self else { return }
            await runControl.reset()
            isPaused = false
            await generateClipEmbeddingsForPending()
            phase = .complete
            isPaused = false
            notifyLibraryChanged()
        }
    }

    public func addFolder(from url: URL) async throws {
        _ = try bookmarkStore.add(url: url)
        await scanAllFolders()
    }

    public func scanPhotoLibraryIfEnabled() {
        activeTask?.cancel()
        activeTask = Task { [weak self] in
            await self?.runPhotoLibraryScan()
        }
    }

    private func runPhotoLibraryScan() async {
        guard photoKitIndexer.isAuthorized else { return }
        await runControl.reset()
        isPaused = false
        phase = .scanning(folder: "Photos Library", filesFound: 0)
        do {
            try await runControl.checkpoint()
            let discovered = try await photoKitIndexer.fetchAllAssets()
            try await runControl.checkpoint()
            lastScanInserted = try store.upsertDiscovered(discovered)
            store.refreshCounts()
            notifyLibraryChanged()
            await generateThumbnailsForPending()
            await analyzePending()
        } catch {
            handleIndexingError(error)
        }
    }

    public func requestPhotoLibraryAccess() async -> Bool {
        await photoKitIndexer.requestAuthorization()
    }

    public func reportFailure(_ message: String) {
        phase = .failed(message)
        isPaused = false
    }

    // MARK: - Pipeline

    public func scanAllFolders() async {
        await runDiscoverPass(bookmarks: bookmarkStore.allBookmarks(), runAnalysis: true)
    }

    /// A file changed inside a saved folder. Classifies those paths only.
    /// A full walk of Downloads is reserved for Look again.
    public func ingestChangedFiles(bookmarks: [FolderBookmark], paths: [String]) async {
        guard !isRunning else { return }
        let files = Array(Set(paths)).filter { path in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
        }.prefix(400)
        guard !files.isEmpty else { return }

        activityDetail = "Checking \(files.count) changed files. The rest of the folder stays as cataloged."
        defer { activityDetail = "" }

        var found: [DiscoveredMedia] = []
        for bookmark in bookmarks {
            let root: URL
            do {
                root = try bookmarkStore.resolve(bookmark).standardizedFileURL
            } catch {
                continue
            }
            let rootPath = root.path
            let owned = files.filter { path in
                let std = URL(fileURLWithPath: path).standardizedFileURL.path
                return std == rootPath || std.hasPrefix(rootPath + "/")
            }
            guard !owned.isEmpty else { continue }
            let batch: [DiscoveredMedia] = (try? bookmarkStore.withSecurityScopedAccess(bookmark) { _ in
                owned.compactMap { path in
                    scanner.classifyFile(at: URL(fileURLWithPath: path), sourceLabel: bookmark.displayName)
                }
            }) ?? []
            found.append(contentsOf: batch)
        }
        guard !found.isEmpty else { return }
        do {
            _ = try store.upsertDiscovered(found)
            store.refreshCounts()
            notifyLibraryChanged()
        } catch {
            reportFailure(error.localizedDescription)
        }
    }

    public func scanBookmarks(
        _ bookmarks: [FolderBookmark],
        runAnalysis: Bool = true,
        kinds: Set<MediaKind> = Set(MediaKind.allCases),
        documentExtensions: Set<String> = DocumentFormats.extensions,
        announce: Bool = true
    ) async {
        guard !isRunning else { return }
        await runDiscoverPass(
            bookmarks: bookmarks,
            runAnalysis: runAnalysis,
            kinds: kinds,
            documentExtensions: documentExtensions,
            announce: announce
        )
    }

    public func runDiscoverPass(
        bookmarks: [FolderBookmark],
        runAnalysis: Bool,
        kinds: Set<MediaKind> = Set(MediaKind.allCases),
        documentExtensions: Set<String> = DocumentFormats.extensions,
        announce: Bool = true
    ) async {
        guard !bookmarks.isEmpty else {
            phase = .complete
            return
        }

        await runControl.reset()
        isPaused = false
        activityDetail = ""

        do {
            var inserted = 0
            for bookmark in bookmarks {
                try await runControl.checkpoint()

                let root = try bookmarkStore.resolve(bookmark)
                let batch = try await bookmarkStore.withSecurityScopedAccessAsync(bookmark) { rootURL in
                    phase = .scanning(folder: bookmark.displayName, filesFound: 0)
                    return try await scanner.scanFolder(
                        at: rootURL,
                        sourceLabel: bookmark.displayName,
                        includeSubfolders: bookmark.includeSubfolders,
                        includedSubfolderPaths: bookmark.includedSubfolderPaths,
                        runControl: runControl,
                        kinds: kinds,
                        documentExtensions: documentExtensions
                    ) { [weak self] count, _ in
                        Task { @MainActor in
                            self?.phase = .scanning(folder: bookmark.displayName, filesFound: count)
                        }
                    }
                }
                if !bookmark.includeSubfolders {
                    _ = try store.removeAssetsNotDirectlyInFolder(
                        sourceLabel: bookmark.displayName,
                        rootPath: root.path
                    )
                }
                if !batch.isEmpty {
                    let added = try store.upsertDiscovered(batch)
                    inserted += added
                    lastScanInserted = added
                    store.refreshCounts()
                    notifyLibraryChanged()
                }
            }

            let newPreviews = await generateThumbnailsForPending()
            if announce, inserted > 0 || newPreviews > 0 {
                discoveryGeneration += 1
            }
            notifyLibraryChanged()

            if runAnalysis {
                await analyzePending()
            } else {
                phase = .complete
                isPaused = false
                notifyLibraryChanged()
            }
        } catch {
            handleIndexingError(error)
        }
    }

    public func generateThumbnailsForPending() async -> Int {
        do {
            try await runControl.checkpoint()
            let total = try store.thumbnailPendingCount()
            guard total > 0 else { return 0 }
            var completedCount = 0
            var failedCount = 0
            while completedCount < total {
                try await runControl.checkpoint()
                let wave = try store.fetchThumbnailPending(
                    offset: failedCount,
                    limit: thumbnailBatchSize
                )
                guard !wave.isEmpty else { break }
                phase = .thumbnailing(
                    current: min(completedCount + 1, total),
                    total: total,
                    fileName: "Loading \(wave.count) previews"
                )

                var jobs: [(id: String, source: URL)] = []
                jobs.reserveCapacity(wave.count)
                for record in wave {
                    try await runControl.checkpoint()
                    if let source = await resolveThumbnailURL(record: record) {
                        jobs.append((record.id, source))
                    }
                }

                let completed = await withTaskGroup(
                    of: (String, String?).self,
                    returning: [(String, String?)].self
                ) { group in
                    for job in jobs {
                        group.addTask {
                            let output = try? await ThumbnailCache.generateThumbnail(
                                for: job.source,
                                assetID: job.id
                            )
                            return (job.id, output?.path)
                        }
                    }
                    var results: [(String, String?)] = []
                    results.reserveCapacity(jobs.count)
                    for await result in group {
                        results.append(result)
                    }
                    return results
                }

                let paths = Dictionary(uniqueKeysWithValues: completed.compactMap { id, path in
                    path.map { (id, $0) }
                })
                failedCount += wave.count - paths.count
                if !paths.isEmpty {
                    try? store.setThumbnailPaths(paths)
                }
                completedCount += wave.count
                phase = .thumbnailing(
                    current: min(completedCount, total),
                    total: total,
                    fileName: "\(completedCount - failedCount) previews ready"
                )
                notifyLibraryChanged()
                await Task.yield()
            }
            return max(0, completedCount - failedCount)
        } catch {
            handleIndexingError(error)
            return 0
        }
    }

    public func analyzePending() async {
        do {
            try await runControl.checkpoint()

            try store.backfillFileExtensions()
            try store.markStaleEvidenceForAnalysis()
            let total = try store.unanalyzedCount()
            guard total > 0 else {
                await generateClipEmbeddingsForPending()
                phase = .complete
                isPaused = false
                return
            }
            var finished = 0
            var seen = Set<String>()
            while finished < total {
                let jobs = try AnalysisJobQueue.unanalyzed(limit: 24).filter { seen.insert($0.id).inserted }
                guard !jobs.isEmpty else { break }
                var savedPhotos = false
                for job in jobs {
                    try await runControl.checkpoint()
                    finished += 1
                    if finished == 1 || finished == total || finished.isMultiple(of: 6) {
                        phase = .analyzing(current: finished, total: total, fileName: job.fileName)
                    }
                    do {
                        if job.kind == .document {
                            try await Task.detached(priority: .utility) {
                                try await DocumentAnalysisWriter.readAndSave(id: job.id, url: job.fileURL)
                            }.value
                        } else if let record = try store.fetchAsset(id: job.id) {
                            try await analyze(record: record)
                            savedPhotos = true
                        }
                    } catch {
                        Self.log.error("Analyze failed for \(job.fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        if let record = try? store.fetchAsset(id: job.id) {
                            try? markAnalysisSkipped(record: record)
                        }
                    }
                    await pumpMainRunLoop()
                }
                if savedPhotos {
                    try store.flush()
                } else if finished.isMultiple(of: 24) {
                    store.refreshCounts()
                }
                onProgress?()
            }

            await generateClipEmbeddingsForPending()
            try await runControl.checkpoint()
            phase = .clustering
            onProgress?()
            let engine = ClusterEngine(store: store)
            try await engine.runClusteringPass()
            store.refreshCounts()
            phase = .complete
            isPaused = false
            notifyLibraryChanged()
        } catch {
            handleIndexingError(error)
        }
    }

    private func handleIndexingError(_ error: Error) {
        isPaused = false
        if error is CancellationError {
            phase = .cancelled
        } else if let abort = error as? IndexingAbort {
            switch abort.reason {
            case .userStopped: phase = .stopped
            case .userCancelled: phase = .cancelled
            }
        } else {
            phase = .failed(error.localizedDescription)
        }
        try? store.flush()
        notifyLibraryChanged()
    }

    private func generateClipEmbeddingsForPending() async {
        guard ClipEmbeddingStore.status == .ready else { return }
        do {
            let total = try store.clipPendingCount()
            guard total > 0 else { return }
            var finished = 0
            while finished < total {
                let jobs = try store.fetchClipJobs(limit: 32)
                guard !jobs.isEmpty else { break }
                var updates: [(id: String, vector: [Float])] = []
                for job in jobs {
                    try await runControl.checkpoint()
                    finished += 1
                    if finished == 1 || finished.isMultiple(of: 5) || finished == total {
                        phase = .embedding(current: finished, total: total, fileName: job.name)
                    }
                    let path = job.path
                    let vector = try? await Task.detached(priority: .utility) {
                        guard let image = SafeImageLoader.loadForAnalysis(
                            from: URL(fileURLWithPath: path),
                            maxPixelSize: 224
                        ) else { return nil as [Float]? }
                        return try await ClipEmbeddingStore.shared.embedImage(image)
                    }.value
                    if let vector {
                        updates.append((job.id, vector))
                    }
                    await Task.yield()
                }
                if !updates.isEmpty {
                    try store.setClipEmbeddings(updates)
                    onProgress?()
                }
            }
        } catch {
            Self.log.error("CLIP indexing failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func notifyLibraryChanged() {
        onLibraryChanged?()
    }

    /// Lets a click, including opening a photo, paint before the next file is read.
    private func pumpMainRunLoop() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }

    private func analyze(record: MediaAssetRecord) async throws {
        if record.kind == .document {
            let fileURL = record.fileURL
            let assetID = record.id
            try await Task.detached(priority: .utility) {
                try await DocumentAnalysisWriter.readAndSave(id: assetID, url: fileURL)
            }.value
            return
        }
        if record.kind == .audio {
            let result = await FileEvidenceReader.audio(at: record.fileURL)
            try store.applyAnalysis(assetID: record.id, result: result, pipeline: .music, persist: false)
            return
        }
        if record.thumbnailPath == nil || !FileManager.default.fileExists(atPath: record.thumbnailPath ?? "") {
            if let thumbSource = await resolveThumbnailURL(record: record) {
                _ = try await ThumbnailCache.generateThumbnail(for: thumbSource, assetID: record.id)
                try store.setThumbnailPath(assetID: record.id, path: ThumbnailCache.thumbnailPath(for: record.id).path)
            }
        }

        let result: PhotoAnalysisResult
        if record.kind == .video {
            guard let videoURL = await resolveThumbnailURL(record: record) else { return }
            result = try await videoAnalyzer.analyzeVideo(at: videoURL)
        } else {
            guard let cgImage = await loadCGImage(record: record) else {
                try markAnalysisSkipped(record: record)
                return
            }
            let header = FileEvidenceReader.imageHeader(at: record.fileURL)
            let width = header?.pixelWidth ?? cgImage.width
            let height = header?.pixelHeight ?? cgImage.height
            let metadata = AssetMetadata(
                pixelWidth: width,
                pixelHeight: height,
                isScreenshotCandidate: isScreenshotDimensions(width: width, height: height),
                captureDate: header?.captureDate
            )
            let vision = analyzer
            result = try await Task.detached(priority: .userInitiated) {
                try await vision.analyzeImage(cgImage, metadata: metadata)
            }.value
        }

        let pipeline = PipelineClassifier.classify(
            kind: record.kind,
            analysis: result,
            metadata: AssetMetadata(pixelWidth: 0, pixelHeight: 0)
        )
        try store.applyAnalysis(assetID: record.id, result: result, pipeline: pipeline, persist: false)
    }

    private func markAnalysisSkipped(record: MediaAssetRecord) throws {
        let pipeline: MediaPipeline = switch record.kind {
        case .video: .videos
        case .audio: .music
        case .document: .documents
        case .image: .photography
        }
        try store.applyAnalysis(assetID: record.id, result: PhotoAnalysisResult(), pipeline: pipeline, persist: false)
    }

    private func loadCGImage(record: MediaAssetRecord) async -> CGImage? {
        if record.sourceKindRaw == MediaSourceKind.photoLibrary.rawValue,
           let id = PhotoAssetURL.localIdentifier(from: record.fileURL) {
            guard let image = await PhotoAssetImageLoader.loadCGImage(localIdentifier: id) else { return nil }
            return SafeImageLoader.copyToIndependentBitmap(image) ?? image
        }
        return SafeImageLoader.loadForAnalysis(from: record.fileURL)
    }

    private func resolveThumbnailURL(record: MediaAssetRecord) async -> URL? {
        if record.sourceKindRaw == MediaSourceKind.photoLibrary.rawValue,
           let id = PhotoAssetURL.localIdentifier(from: record.fileURL) {
            return await PhotoAssetImageLoader.fileURLForExport(localIdentifier: id)
        }
        let url = record.fileURL
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func isScreenshotDimensions(width: Int, height: Int) -> Bool {
        let ratio = Double(width) / Double(max(height, 1))
        return abs(ratio - 9.0 / 19.5) < 0.04 || abs(ratio - 9.0 / 16.0) < 0.04
    }
}
