import SiftCore
import SiftDesign
import SwiftUI

@MainActor
public final class SiftRootSession: ObservableObject {
    public let indexStore: MediaIndexStore
    public let bookmarkStore: BookmarkStore
    public let destinationStore: DestinationStore
    public let indexingCoordinator: IndexingCoordinator
    public let collectionSuggester: CollectionSuggester
    public let clusterEngine: ClusterEngine
    public let jobCenter = BackgroundJobCenter()
    public let notchChrome = NotchChrome()
    public let fileTransfer = FileTransferCoordinator()
    public let transferJournal: TransferJournal
    public let organizeRulesEngine: OrganizeRulesEngine

    #if os(macOS)
    let islandController = SiftIslandController()
    #endif
    private var semanticSearchTask: Task<Void, Never>?
    private var organizeRefineTask: Task<Void, Never>?
    private var rerankNextSearch = false
    private let libraryPageSize = 160
    private var libraryFetchOffset = 0

    @Published public var appMode: AppMode = .library
    @Published public var selectedPipeline: MediaPipeline = .all
    @Published public var palette: ExtractedPalette = .defaultPalette
    @Published public var displayedAssets: [MediaAssetSummary] = []
    @Published public private(set) var hasMoreLibraryAssets = false
    @Published public private(set) var isLoadingLibraryPage = false
    @Published public var collections: [StratumCollectionRecord] = []
    @Published public var commandOrbPresented = false
    @Published public var commandQuery = ""
    @Published public var includeFileNamesInSearch = UserDefaults.standard.bool(forKey: "sift.search.includeFileNames")
    @Published public var selectedAsset: MediaAssetSummary?
    @Published public var relatedAssets: [MediaAssetSummary] = []
    @Published public var libraryViewMode: LibraryViewMode = .grid
    @Published public var visualDirections: Set<VisualDirection> = []
    @Published public var browseScope: LibraryBrowseScope = .allSources
    @Published public var librarySort: LibraryAssetSort = .dateModifiedNewest
    @Published public var libraryKindFilter: LibraryKindFilter = .all
    @Published public var scanKinds: Set<MediaKind> = ScanKindStore.load()
    @Published public var scanDocumentExtensions: Set<String> = ScanKindStore.loadExtensions()
    @Published public var commandRouteTitle: String?
    @Published public private(set) var browseSubfolderOptions: [LibraryBrowseFilter.SubfolderOption] = []
    @Published public var selectedPersonCollectionID: String?
    @Published public private(set) var personCollections: [StratumCollectionRecord] = []
    @Published public private(set) var personReviewGroups: [PersonReviewGroup] = []
    @Published public private(set) var inboxCount: Int = 0
    @Published public private(set) var duplicateGroups: [DuplicateGroup] = []
    @Published public private(set) var isScanningDuplicates = false
    @Published public private(set) var duplicateScanLabel = ""
    @Published public private(set) var duplicateScanFraction: Double = 0
    @Published public var selectedAssetIDs: Set<String> = []

    #if os(macOS)
    private var sourceFolderWatcher: SourceFolderWatcher?
    #endif

    public var watchSourceFolders: Bool {
        get {
            UserDefaults.standard.object(forKey: "sift.watchSourceFolders") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "sift.watchSourceFolders")
            #if os(macOS)
            if newValue {
                startSourceFolderWatcher()
            } else {
                stopSourceFolderWatcher()
            }
            #endif
        }
    }

    @Published public var pendingFolderURL: URL?
    @Published public var showFolderIntakeWizard = false
    @Published public var folderEstimate: FolderTreeEstimate?
    @Published public var selectedSubfolderPaths: Set<String> = []
    @Published public var pendingIncludeSubfolders = true
    @Published public var showMacScanWizard = false
    @Published public var showOrganizePlan = false
    @Published public var showCatalogStructureWizard = false
    @Published public var organizePlan: [OrganizePlanItem] = []
    private var suggestStructureAfterDiscovery = false

    @Published public var showDestinationWizard = false
    @Published public var showStartAITagging = false
    @Published public var showClipWeightSplash = false
    @Published public var clipWeightProgress = ClipWeightProgress.starting
    @Published public var clipWeightError: String?
    @Published public var showPostOrganizeSuccess = false
    @Published public var showConfirmDeleteOrigins = false
    @Published public var pendingDeleteSourcePaths: [String] = []
    @Published public var skipAITaggingPrompt: Bool = UserDefaults.standard.bool(forKey: "sift.skipAITaggingPrompt") {
        didSet { UserDefaults.standard.set(skipAITaggingPrompt, forKey: "sift.skipAITaggingPrompt") }
    }

    @Published public var previewAssets: [MediaAssetSummary] = []
    @Published public var previewIndex: Int = 0
    @Published public var previewIsFullscreen = false
    @Published public var showAssetPreview = false
    @Published public var previewPanelSize: CGSize = .zero

    public var previewAsset: MediaAssetSummary? {
        guard previewIndex >= 0, previewIndex < previewAssets.count else { return nil }
        return previewAssets[previewIndex]
    }
    @Published public private(set) var windowContentSize: CGSize = CGSize(width: 1200, height: 780)

    public var fileTransferMode: FileTransferMode {
        get { FileTransferMode(rawValue: UserDefaults.standard.string(forKey: "sift.fileTransferMode") ?? "") ?? .move }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "sift.fileTransferMode")
            UserDefaults.standard.set(true, forKey: "sift.fileTransferModeChosen")
            objectWillChange.send()
        }
    }

    /// False until the user picks Move or Copy in the organize step. A saved mode is not treated as a choice.
    public var transferChoiceConfirmed: Bool {
        UserDefaults.standard.bool(forKey: "sift.fileTransferModeChosen")
    }

    @Published public var structureFolders: Set<String> = Set(FileTransferCoordinator.suggestedCatalogFolders)
    @Published public private(set) var filingSummary = CatalogFilingSummary.empty

    public var activeDestination: DestinationBookmark? {
        destinationStore.activeDestination
    }

    public var activeDestinationName: String {
        activeDestination?.displayName ?? ""
    }

    public var activeDestinationPath: String {
        guard let activeDestination else { return "" }
        return (try? destinationStore.resolvedDirectory(for: activeDestination).path) ?? ""
    }

    public var isIndexing: Bool {
        indexingCoordinator.isRunning
    }

    public init() {
        let store = MediaIndexStore()
        let bookmarks = BookmarkStore()
        let destinations = DestinationStore()
        self.indexStore = store
        self.bookmarkStore = bookmarks
        self.destinationStore = destinations
        self.transferJournal = TransferJournal(store: store)
        self.indexingCoordinator = IndexingCoordinator(store: store, bookmarkStore: bookmarks)
        self.collectionSuggester = CollectionSuggester(store: store)
        self.clusterEngine = ClusterEngine(store: store)
        self.organizeRulesEngine = OrganizeRulesEngine(store: store)

        indexingCoordinator.onLibraryChanged = { [weak self] in
            Task { @MainActor in
                self?.reloadLibrary()
            }
        }
        indexingCoordinator.onProgress = { [weak self] in
            guard let self else { return }
            self.notchChrome.clipEmbeddedCount = (try? self.indexStore.clipEmbeddedCount()) ?? 0
        }

        reloadLibrary()
        #if os(macOS)
        if watchSourceFolders {
            startSourceFolderWatcher()
        }
        #endif
    }

    public func reloadLibrary() {
        do {
            try? indexStore.normalizePipelinesByKind()
            personReviewGroups = (try? indexStore.personReviewGroups()) ?? []
            collections = try indexStore.fetchCollections()
            personCollections = try indexStore.fetchPersonCollections().filter {
                guard let title = $0.userTitle?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    return false
                }
                return !title.isEmpty
            }
            let personNames = try indexStore.buildPersonNameLookup()
            try loadLibraryPage(reset: true, personNames: personNames)
            if browseScope == .inbox {
                inboxCount = displayedAssets.count
            }
            refreshBrowseSubfolderOptions()
            indexStore.refreshCounts()
            refreshFilingSummary()
            refreshNotchLinks()
            updatePalette()
            jobCenter.sync(from: indexingCoordinator.phase)
            updateIslandVisibility()
        } catch {
            displayedAssets = []
            browseSubfolderOptions = []
            personCollections = []
        }
    }

    public func loadNextLibraryPage() {
        guard hasMoreLibraryAssets, !isLoadingLibraryPage, !notchChrome.searchActive else { return }
        do {
            try loadLibraryPage(reset: false, personNames: indexStore.buildPersonNameLookup())
        } catch {
            hasMoreLibraryAssets = false
        }
    }

    private func loadLibraryPage(
        reset: Bool,
        personNames: [String: String]
    ) throws {
        guard !isLoadingLibraryPage else { return }
        isLoadingLibraryPage = true
        defer { isLoadingLibraryPage = false }
        if reset {
            libraryFetchOffset = 0
            displayedAssets = []
        }

        if let personID = selectedPersonCollectionID,
           let collection = personCollections.first(where: { $0.id == personID }) {
            let sorted = LibraryBrowseFilter.sortRecords(collection.assets ?? [], by: librarySort)
            let end = min(libraryFetchOffset + libraryPageSize, sorted.count)
            guard libraryFetchOffset < end else {
                hasMoreLibraryAssets = false
                return
            }
            let page = sorted[libraryFetchOffset..<end]
            displayedAssets.append(contentsOf: page.map {
                MediaAssetSummary(record: $0, personDisplayName: personNames[$0.id])
            })
            libraryFetchOffset = end
            hasMoreLibraryAssets = end < sorted.count
            return
        }

        let chunkSize = libraryPageSize
        let roots = browseScope == .inbox ? resolvedSourceRoots() : []
        let destination = browseScope == .inbox ? try resolvedDestinationRoot() : nil
        let sourceLabel = browseSourceLabel
        let sourceRoot = try browseSourceRootURL()
        var accepted: [MediaAssetRecord] = []
        var moreRawRecords = true
        var chunksRead = 0

        while accepted.count < libraryPageSize, moreRawRecords, chunksRead < 12 {
            let raw = try indexStore.fetchAssetsPage(
                pipeline: selectedPipeline,
                sort: librarySort,
                offset: libraryFetchOffset,
                limit: chunkSize
            )
            libraryFetchOffset += raw.count
            chunksRead += 1
            moreRawRecords = raw.count == chunkSize
            let filtered = raw.filter { record in
                if let sourceLabel, record.sourceLabel != sourceLabel { return false }
                if browseScope == .inbox,
                   !InboxFilter.isInbox(
                    assetURL: record.fileURL,
                    sourceRoots: roots,
                    destinationRoot: destination
                   ) { return false }
                if let sourceRoot,
                   !LibraryBrowseFilter.matchesSubfolder(
                    fileURL: record.fileURL,
                    sourceRoot: sourceRoot,
                    subfolder: browseSubfolderPath
                   ) { return false }
                if !libraryKindFilter.matches(
                    kind: record.kind,
                    isScreenshotOrDocument: record.isScreenshotOrDocument,
                    faceCount: record.faceCount
                ) { return false }
                return true
            }
            accepted.append(contentsOf: filtered.prefix(libraryPageSize - accepted.count))
        }

        let existing = Set(displayedAssets.map(\.id))
        displayedAssets.append(contentsOf: accepted.compactMap { record in
            guard !existing.contains(record.id) else { return nil }
            return MediaAssetSummary(record: record, personDisplayName: personNames[record.id])
        })
        hasMoreLibraryAssets = moreRawRecords
    }

    public func setPersonLabel(assetID: String, name: String) {
        try? indexStore.setPersonLabel(assetID: assetID, name: name)
        reloadLibrary()
        if showAssetPreview, let asset = previewAsset {
            selectAsset(asset, updateAmbientPalette: false)
        }
    }

    public func selectPersonCollection(id: String?) {
        selectedPersonCollectionID = id
        if id != nil {
            selectedPipeline = .people
        }
        reloadLibrary()
    }

    public var browseSourceLabel: String? {
        switch browseScope {
        case .inbox, .allSources, .entireCatalog:
            return nil
        case .source(let id, _):
            return bookmarkStore.bookmark(id: id)?.displayName
        }
    }

    public func resolvedSourceRoots() -> [URL] {
        bookmarkStore.folders.compactMap { try? bookmarkStore.resolve($0) }
    }

    public func resolvedDestinationRoot() throws -> URL? {
        guard let dest = destinationStore.activeDestination else { return nil }
        return try destinationStore.resolvedDirectory(for: dest)
    }

    public func refreshFilingSummary() {
        let records = (try? indexStore.fetchAssets()) ?? []
        let transfers = (try? transferJournal.activeTransfers()) ?? []
        let roots: [String]
        if let active = destinationStore.activeDestination,
           let path = try? destinationStore.resolvedDirectory(for: active).path {
            roots = [path]
        } else {
            roots = []
        }
        filingSummary = CatalogFilingClassifier.summarize(
            files: records.map {
                CatalogFile(id: $0.id, path: $0.fileURLString, contentHash: $0.contentHash)
            },
            destinationRoots: roots,
            transfers: transfers.map {
                CatalogTransfer(sourcePath: $0.sourcePath, destinationPath: $0.destinationPath)
            }
        )
    }

    private func computeInboxCount() -> Int {
        do {
            let roots = resolvedSourceRoots()
            let dest = try resolvedDestinationRoot()
            let records = try indexStore.fetchAssets()
            return InboxFilter.filterInbox(records, sourceRoots: roots, destinationRoot: dest).count
        } catch {
            return 0
        }
    }

    public var browseSubfolderPath: String? {
        guard case .source(_, let sub) = browseScope else { return nil }
        return sub
    }

    public func browseSourceRootURL() throws -> URL? {
        guard case .source(let id, _) = browseScope,
              let bookmark = bookmarkStore.bookmark(id: id) else { return nil }
        return try bookmarkStore.resolve(bookmark)
    }

    public func mediaAccessRoot(for asset: MediaAssetSummary) -> URL? {
        guard let bookmark = bookmarkStore.folders.first(where: { $0.displayName == asset.sourceLabel }) else {
            return nil
        }
        return try? bookmarkStore.resolve(bookmark)
    }

    public func refreshBrowseSubfolderOptions() {
        guard let label = browseSourceLabel,
              let root = try? browseSourceRootURL() else {
            browseSubfolderOptions = []
            return
        }
        do {
            let records = try indexStore.fetchAssets(pipeline: selectedPipeline, sourceLabel: label)
            browseSubfolderOptions = LibraryBrowseFilter.subfolderOptions(records: records, sourceRoot: root)
        } catch {
            browseSubfolderOptions = []
        }
    }

    public func setBrowseScope(_ scope: LibraryBrowseScope) {
        browseScope = scope
        selectedAssetIDs = []
        reloadLibrary()
    }

    public func toggleAssetSelection(_ assetID: String, rangeAssets: [MediaAssetSummary], extendRange: Bool) {
        if extendRange, let lastID = selectedAssetIDs.first,
           let lastIndex = rangeAssets.firstIndex(where: { $0.id == lastID }),
           let index = rangeAssets.firstIndex(where: { $0.id == assetID }) {
            let lo = min(lastIndex, index)
            let hi = max(lastIndex, index)
            for i in lo...hi {
                selectedAssetIDs.insert(rangeAssets[i].id)
            }
            return
        }
        if selectedAssetIDs.contains(assetID) {
            selectedAssetIDs.remove(assetID)
        } else {
            selectedAssetIDs.insert(assetID)
        }
    }

    public func clearAssetSelection() {
        selectedAssetIDs = []
    }

    public func setLibrarySort(_ sort: LibraryAssetSort) {
        librarySort = sort
        reloadLibrary()
    }

    public func pipelineCounts() -> [MediaPipeline: Int] {
        var counts: [MediaPipeline: Int] = [:]
        for pipeline in MediaPipeline.allCases {
            counts[pipeline] = (try? indexStore.fetchAssets(pipeline: pipeline).count) ?? 0
        }
        return counts
    }

    public func addFolder() async {
        #if os(macOS)
        appMode = .sources
        let resumeAfterPicker = indexingCoordinator.isRunning && !indexingCoordinator.isPaused
        if resumeAfterPicker { pauseIndexing() }
        guard let url = await BookmarkStore.pickFolder() else {
            if resumeAfterPicker { resumeIndexing() }
            return
        }
        await beginFolderIntake(url: url)
        #endif
    }

    public func addLocations() async {
        #if os(macOS)
        appMode = .sources
        let resumeAfterPicker = indexingCoordinator.isRunning && !indexingCoordinator.isPaused
        if resumeAfterPicker { pauseIndexing() }
        let urls = await BookmarkStore.pickFolders()
        guard !urls.isEmpty else {
            if resumeAfterPicker { resumeIndexing() }
            return
        }
        showMacScanWizard = false
        for url in urls {
            _ = try? bookmarkStore.add(url: url, includeSubfolders: true, includedSubfolderPaths: nil)
        }
        startDiscoverOnly()
        #endif
    }

    public func replaceFolderSource(id: String) async {
        #if os(macOS)
        guard let old = bookmarkStore.bookmark(id: id),
              let replacement = await BookmarkStore.pickFolder() else { return }
        cancelIndexing()
        bookmarkStore.remove(id: id)
        _ = try? indexStore.removeAssets(sourceLabel: old.displayName)
        _ = try? bookmarkStore.add(
            url: replacement,
            includeSubfolders: old.includeSubfolders,
            includedSubfolderPaths: nil
        )
        suggestStructureAfterDiscovery = true
        startDiscoverOnly()
        #endif
    }

    public func chooseCatalogStructureDestination() async {
        #if os(macOS)
        guard let url = await DestinationStore.pickFolder() else { return }
        await addDestination(from: url)
        #endif
    }

    public func createSuggestedCatalogStructure() async {
        guard let destination = destinationStore.activeDestination else {
            await chooseCatalogStructureDestination()
            return
        }
        let names = FileTransferCoordinator.suggestedCatalogFolders.filter { structureFolders.contains($0) }
        guard !names.isEmpty else {
            indexingCoordinator.reportFailure("Choose at least one folder to create.")
            return
        }
        do {
            try await destinationStore.withSecurityScopedAccessAsync(destination) { root in
                try await fileTransfer.ensureSuggestedCatalogLayout(at: root, folders: names)
            }
            showCatalogStructureWizard = false
            appMode = .organize
            refreshOrganizePlan()
        } catch {
            indexingCoordinator.reportFailure(error.localizedDescription)
        }
    }

    public func scanStandardMacLocations() {
        showMacScanWizard = false
        for url in MacScanLocations.standard where FileManager.default.isReadableFile(atPath: url.path) {
            _ = try? bookmarkStore.add(url: url, includeSubfolders: true, includedSubfolderPaths: nil)
        }
        startDiscoverOnly()
    }

    public func openFullDiskAccessSettings() {
        #if os(macOS)
        NSWorkspace.shared.open(FullDiskAccessProbe.settingsURL)
        #endif
    }

    public func browseEntireCatalog() {
        browseScope = .entireCatalog
        focus(mode: .library)
        runSearch()
    }

    public func refreshOrganizePlan() {
        refreshFilingSummary()
        let filing = filingSummary
        let records = (try? indexStore.fetchAssets()) ?? []
        organizePlan = OrganizePlanner.preview(
            candidates: records.map {
                OrganizeCandidate(id: $0.id, path: $0.fileURL.path, pipelineName: $0.pipeline.displayName)
            },
            inDestinationPaths: filing.inDestinationPaths,
            originPaths: filing.originPaths,
            outsidePaths: filing.outsidePaths
        )
        showOrganizePlan = true
        notchChrome.planCount = organizePlan.filter { !$0.blocked }.count
        notchChrome.blockedPlanCount = organizePlan.filter(\.blocked).count
        refineOrganizePlanWithJev()
    }

    /// Asks Jev once per small local group. The sheet already shows the local folders; a failure leaves them as they are.
    private func refineOrganizePlanWithJev() {
        organizeRefineTask?.cancel()
        guard JevCredential.isConfigured else { return }
        let snapshot = organizePlan
        organizeRefineTask = Task { [weak self] in
            let groups = Dictionary(grouping: snapshot.filter { !$0.blocked && $0.proposedFolder.isEmpty == false }) {
                $0.proposedFolder
            }
            var replacements: [String: String] = [:]
            for (folder, items) in groups where items.count <= JevAdvisor.maxGroupSize {
                if Task.isCancelled { return }
                let names = items.prefix(5).map(\.fileName)
                guard let proposed = await JevAdvisor.proposeFolder(localFolder: folder, sampleNames: names) else { continue }
                for item in items {
                    replacements[item.id] = proposed
                }
            }
            guard let self, !replacements.isEmpty, !Task.isCancelled else { return }
            organizePlan = organizePlan.map { item in
                guard let folder = replacements[item.id], !item.blocked else { return item }
                return OrganizePlanItem(
                    id: item.id,
                    fileName: item.fileName,
                    sourcePath: item.sourcePath,
                    proposedFolder: folder,
                    reason: "Jev suggested \(folder) from the filename. Nothing is moved until you approve.",
                    blocked: false,
                    blockReason: nil
                )
            }
            notchChrome.planCount = organizePlan.filter { !$0.blocked }.count
        }
    }

    public func approveSafeOrganization() async {
        guard transferChoiceConfirmed else { return }
        guard let destination = destinationStore.activeDestination else {
            showDestinationWizard = true
            return
        }
        let safe = organizePlan.filter { !$0.blocked }
        guard !safe.isEmpty else { return }
        let records = (try? indexStore.fetchAssets()) ?? []
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        do {
            var lastURL: URL?
            for item in safe {
                guard let record = byID[item.id] else { continue }
                let asset = MediaAssetSummary(record: record)
                guard FileManager.default.fileExists(atPath: asset.fileURL.path) else { continue }
                let newURL = try await performTransfer(
                    asset: asset,
                    to: destination,
                    folderName: item.proposedFolder
                )
                try transferJournal.record(
                    assetID: item.id,
                    sourcePath: asset.fileURL.path,
                    destinationPath: newURL.path,
                    mode: fileTransferMode
                )
                try indexStore.updateAssetPath(assetID: item.id, newURL: newURL)
                if fileTransferMode == .copyThenConfirmDelete, asset.fileURL.path != newURL.path {
                    pendingDeleteSourcePaths.append(asset.fileURL.path)
                }
                lastURL = newURL
            }
            if fileTransferMode == .copyThenConfirmDelete, !pendingDeleteSourcePaths.isEmpty {
                showConfirmDeleteOrigins = true
            }
            reloadLibrary()
            #if os(macOS)
            if let lastURL {
                NSWorkspace.shared.activateFileViewerSelecting([lastURL])
            }
            #endif
        } catch {
            indexingCoordinator.reportFailure(error.localizedDescription)
        }
    }

    public func ingestDropped(_ urls: [URL]) {
        #if os(macOS)
        let folder = urls.first(where: \.hasDirectoryPath) ?? urls.first?.deletingLastPathComponent()
        guard let folder else { return }
        NSApp.activate(ignoringOtherApps: true)
        Task { await beginFolderIntake(url: folder) }
        #endif
    }

    private func beginFolderIntake(url: URL) async {
        #if os(macOS)
        pendingFolderURL = url
        pendingIncludeSubfolders = true
        selectedSubfolderPaths = []
        let started = url.startAccessingSecurityScopedResource()
        folderEstimate = (try? await FolderTreeScanner.estimate(at: url))
            ?? FolderTreeEstimate(rootName: url.lastPathComponent, totalImages: 0, totalVideos: 0, totalBytes: 0, nodes: [])
        if started { url.stopAccessingSecurityScopedResource() }
        showFolderIntakeWizard = true
        appMode = .organize
        #endif
    }

    public func focus(mode: AppMode) {
        appMode = mode
        #if os(macOS)
        NSApp.activate(ignoringOtherApps: true)
        #endif
    }

    public func activateIslandStatus() {
        #if os(macOS)
        NSApp.activate(ignoringOtherApps: true)
        #endif
        switch jobCenter.progress.kind {
        case .analyze, .cluster:
            appMode = .review
        case .discover, .transfer:
            appMode = .library
        case .idle:
            appMode = duplicateGroups.isEmpty ? .library : .review
        }
    }

    public func openGarden() {
        libraryViewMode = .orbit
        selectedPersonCollectionID = nil
        focus(mode: .library)
    }

    public func openInbox() {
        browseScope = .inbox
        selectedPersonCollectionID = nil
        focus(mode: .library)
        reloadLibrary()
    }

    public func openDuplicates() {
        focus(mode: .review)
        runDuplicateScan()
    }

    public func focusSearch() {
        commandOrbPresented = true
        #if os(macOS)
        NSApp.activate(ignoringOtherApps: true)
        #endif
    }

    public func noteNotchQuery(_ query: String) {
        if commandQuery != query {
            commandQuery = query
        }
    }

    public func submitNotchSearch(_ query: String) {
        commandQuery = query
        focus(mode: .library)
        runSearch()
    }

    public func clearNotchSearch() {
        commandQuery = ""
        notchChrome.query = ""
        notchChrome.searchActive = false
        notchChrome.hits = []
        reloadLibrary()
    }

    public func selectNotchSavedSearch(id: String) {
        guard let record = (try? indexStore.fetchSavedSearches())?.first(where: { $0.id == id }) else { return }
        focus(mode: .library)
        applySavedSearch(record)
    }

    public func selectNotchPerson(id: String) {
        focus(mode: .library)
        selectPersonCollection(id: id)
    }

    public func openNotchHit(_ asset: MediaAssetSummary) {
        focus(mode: .library)
        openPreview(asset)
    }

    private func refreshNotchLinks() {
        let saved = (try? indexStore.fetchSavedSearches()) ?? []
        notchChrome.saved = saved.prefix(5).map {
            NotchLink(id: $0.id, title: $0.name, subtitle: $0.query)
        }
        notchChrome.people = personCollections.filter { collection in
            if let userTitle = collection.userTitle, !userTitle.isEmpty { return true }
            return !collection.title.hasPrefix("Person ")
        }
        .prefix(5)
        .map { NotchLink(id: $0.id, title: $0.displayTitle, subtitle: "") }
        notchChrome.assetCount = indexStore.assetCount
        notchChrome.folderCount = bookmarkStore.folders.count
        notchChrome.inboxCount = inboxCount
        let otherSuggestions = collections.filter {
            $0.isSuggested && !$0.isAccepted && $0.collectionKind != .person
        }.count
        notchChrome.suggestionCount = otherSuggestions + personReviewGroups.count
        notchChrome.duplicateCount = duplicateGroups.count
        notchChrome.pipelineName = selectedPipeline.displayName
        notchChrome.latest = Array(displayedAssets.prefix(5))
        notchChrome.photoCount = (try? indexStore.count(kind: .image)) ?? 0
        notchChrome.videoCount = (try? indexStore.count(kind: .video)) ?? 0
        notchChrome.audioCount = (try? indexStore.count(kind: .audio)) ?? 0
        let snapshot = ScanStats.shared.snapshot()
        if snapshot.skippedTrees > 0 {
            ScanSessionStore.save(skippedTrees: snapshot.skippedTrees)
        }
        notchChrome.skippedTrees = max(snapshot.skippedTrees, ScanSessionStore.load()?.skippedTrees ?? 0)
        notchChrome.fullDiskAccess = FullDiskAccessProbe.isGranted()
        notchChrome.clipReady = ClipEmbeddingStore.status == .ready
        notchChrome.clipEmbeddedCount = (try? indexStore.clipEmbeddedCount()) ?? 0
        notchChrome.planCount = organizePlan.filter { !$0.blocked }.count
        notchChrome.blockedPlanCount = organizePlan.filter(\.blocked).count
    }

    public func confirmFolderIntake() {
        guard pendingFolderURL != nil else { return }
        showFolderIntakeWizard = false
        let paths: [String]? = pendingIncludeSubfolders
            ? Array(selectedSubfolderPaths)
            : [""]
        if let url = pendingFolderURL {
            _ = try? bookmarkStore.add(
                url: url,
                includeSubfolders: pendingIncludeSubfolders,
                includedSubfolderPaths: paths
            )
            #if os(macOS)
            startSourceFolderWatcher()
            #endif
        }
        pendingFolderURL = nil
        startDiscoverOnly()
    }

    public func cancelFolderIntake() {
        pendingFolderURL = nil
        folderEstimate = nil
        showFolderIntakeWizard = false
    }

    public func addDestination() async {
        #if os(macOS)
        guard let url = await DestinationStore.pickFolder() else { return }
        await addDestination(from: url)
        #endif
    }

    public func addDestination(from url: URL) async {
        do {
            _ = try destinationStore.add(url: url)
            refreshFilingSummary()
            objectWillChange.send()
        } catch {
            indexingCoordinator.reportFailure(error.localizedDescription)
        }
    }

    public func selectDestination(id: String) {
        destinationStore.setActive(id: id)
        refreshFilingSummary()
        objectWillChange.send()
    }

    public func removeDestination(id: String) {
        destinationStore.remove(id: id)
        objectWillChange.send()
    }

    public func finishDestinationSetup() {
        showDestinationWizard = false
        appMode = .organize
    }

    public func startDiscoverOnly() {
        let extensions = scanDocumentExtensions.isEmpty ? DocumentFormats.extensions : scanDocumentExtensions
        indexingCoordinator.startFolderIndexing(
            scanAllSavedSources: true,
            runAnalysis: false,
            kinds: scanKinds.isEmpty ? Set(MediaKind.allCases) : scanKinds,
            documentExtensions: extensions
        )
    }

    public func setScanDocumentExtension(_ ext: String, enabled: Bool) {
        var next = scanDocumentExtensions
        if enabled {
            next.insert(ext)
        } else if next.count > 1 {
            next.remove(ext)
        }
        scanDocumentExtensions = next
        ScanKindStore.saveExtensions(next)
    }

    public func setScanKind(_ kind: MediaKind, enabled: Bool) {
        var next = scanKinds
        if enabled {
            next.insert(kind)
        } else if next.count > 1 {
            next.remove(kind)
        }
        scanKinds = next
        ScanKindStore.save(next)
    }

    public func promptAITaggingIfNeeded() {
        guard !skipAITaggingPrompt else {
            startBackgroundAnalysis()
            return
        }
        showStartAITagging = true
    }

    public func prepareInteractiveLaunch() {
        let needsDownload = ClipEmbeddingStore.status != .ready
        if needsDownload {
            showClipWeightSplash = true
            clipWeightProgress = .starting
            clipWeightError = nil
        }
        Task { @MainActor in
            if needsDownload {
                await downloadClipWeightsForSplash()
            } else {
                notchChrome.clipReady = true
            }
            try? await Task.sleep(for: .seconds(2))
            startDeferredClipIndexing()
        }
    }

    public func retryClipWeightDownload() {
        clipWeightError = nil
        clipWeightProgress = .starting
        Task { await downloadClipWeightsForSplash() }
    }

    public func dismissClipWeightSplash() {
        showClipWeightSplash = false
    }

    private func downloadClipWeightsForSplash() async {
        clipWeightError = nil
        do {
            try await ClipEmbeddingStore.shared.ensureWeights { progress in
                Task { @MainActor in
                    self.clipWeightProgress = progress
                }
            }
            notchChrome.clipReady = ClipEmbeddingStore.status == .ready
            showClipWeightSplash = false
        } catch {
            notchChrome.clipReady = false
            clipWeightError = "The download did not finish. You can try again, or keep going with file names and on-device Vision labels."
        }
    }

    public func setIncludeFileNamesInSearch(_ include: Bool) {
        guard includeFileNamesInSearch != include else { return }
        includeFileNamesInSearch = include
        UserDefaults.standard.set(include, forKey: "sift.search.includeFileNames")
        if !commandQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            runSearch()
        }
    }

    public func startDeferredClipIndexing() {
        guard ClipEmbeddingStore.status == .ready, !indexingCoordinator.isRunning else { return }
        guard ((try? indexStore.unanalyzedCount()) ?? 0) == 0 else { return }
        let pending = (try? indexStore.clipPendingCount()) ?? 0
        guard pending > 0 else { return }
        indexingCoordinator.startClipIndexingOnly()
    }

    public func startBackgroundAnalysis() {
        showStartAITagging = false
        guard !indexingCoordinator.isRunning else { return }
        indexingCoordinator.startAnalysisPassOnly()
        SiftNotificationService.requestAuthorizationIfNeeded()
    }

    /// Asset targeted by organize actions: preview carousel wins when open.
    public var assetForOrganizeActions: MediaAssetSummary? {
        if showAssetPreview, let preview = previewAsset { return preview }
        return selectedAsset
    }

    public func moveSelectedAsset(to bucket: StagingBucket) async {
        guard let asset = assetForOrganizeActions else { return }
        await moveAsset(asset, to: bucket)
    }

    public func moveAsset(_ asset: MediaAssetSummary, to bucket: StagingBucket) async {
        guard transferChoiceConfirmed else { return }
        guard let destination = destinationStore.activeDestination else { return }

        let sourcePath = asset.fileURL.path
        guard FileManager.default.fileExists(atPath: sourcePath) else {
            indexingCoordinator.reportFailure("File not found at \(sourcePath). Try rescanning the source folder.")
            return
        }

        do {
            let newURL = try await performTransfer(asset: asset, to: destination, bucket: bucket)
            try transferJournal.record(
                assetID: asset.id,
                sourcePath: sourcePath,
                destinationPath: newURL.path,
                mode: fileTransferMode
            )
            try indexStore.updateAssetPath(assetID: asset.id, newURL: newURL)
            if fileTransferMode == .copyThenConfirmDelete, sourcePath != newURL.path {
                pendingDeleteSourcePaths.append(sourcePath)
                showConfirmDeleteOrigins = true
            }
            refreshAfterAssetMoved(movedAssetID: asset.id)
            #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([newURL])
            #endif
        } catch {
            indexingCoordinator.reportFailure(error.localizedDescription)
        }
    }

    private func performTransfer(
        asset: MediaAssetSummary,
        to destination: DestinationBookmark,
        bucket: StagingBucket
    ) async throws -> URL {
        let source = asset.fileURL
        if let sourceBookmark = bookmarkStore.folders.first(where: { $0.displayName == asset.sourceLabel }) {
            return try await bookmarkStore.withSecurityScopedAccessAsync(sourceBookmark) { _ in
                try await destinationStore.withSecurityScopedAccessAsync(destination) { destinationRoot in
                    try await fileTransfer.transfer(
                        from: source,
                        to: destinationRoot,
                        bucket: bucket,
                        mode: fileTransferMode
                    )
                }
            }
        }
        return try await destinationStore.withSecurityScopedAccessAsync(destination) { destinationRoot in
            try await fileTransfer.transfer(
                from: source,
                to: destinationRoot,
                bucket: bucket,
                mode: fileTransferMode
            )
        }
    }

    private func performTransfer(
        asset: MediaAssetSummary,
        to destination: DestinationBookmark,
        folderName: String
    ) async throws -> URL {
        let source = asset.fileURL
        if let sourceBookmark = bookmarkStore.folders.first(where: { $0.displayName == asset.sourceLabel }) {
            return try await bookmarkStore.withSecurityScopedAccessAsync(sourceBookmark) { _ in
                try await destinationStore.withSecurityScopedAccessAsync(destination) { destinationRoot in
                    try await fileTransfer.transfer(
                        from: source,
                        to: destinationRoot,
                        folderName: folderName,
                        mode: fileTransferMode
                    )
                }
            }
        }
        return try await destinationStore.withSecurityScopedAccessAsync(destination) { destinationRoot in
            try await fileTransfer.transfer(
                from: source,
                to: destinationRoot,
                folderName: folderName,
                mode: fileTransferMode
            )
        }
    }

    private func refreshAfterAssetMoved(movedAssetID: String) {
        reloadLibrary()
        if showAssetPreview {
            previewAssets = displayedAssets
            if let idx = previewAssets.firstIndex(where: { $0.id == movedAssetID }) {
                previewIndex = idx
            } else if !previewAssets.isEmpty {
                previewIndex = min(previewIndex, previewAssets.count - 1)
            } else {
                closePreview()
            }
            if let asset = previewAsset {
                selectAsset(asset, updateAmbientPalette: false)
            }
        }
    }

    public func syncPreviewSelection() {
        guard showAssetPreview, let asset = previewAsset else { return }
        selectedAsset = asset
    }

    public func enablePhotosLibrary() async {
        let granted = await indexingCoordinator.requestPhotoLibraryAccess()
        guard granted else { return }
        indexingCoordinator.scanPhotoLibraryIfEnabled()
    }

    public func pauseIndexing() { indexingCoordinator.pauseIndexing() }
    public func resumeIndexing() { indexingCoordinator.resumeIndexing() }
    public func stopIndexing() {
        showStartAITagging = false
        indexingCoordinator.stopIndexing()
    }
    public func cancelIndexing() {
        showStartAITagging = false
        indexingCoordinator.cancelIndexing()
    }

    public func continueIndexing() {
        indexingCoordinator.continueInterruptedIndexing()
    }

    public func resetAIProcessing() {
        try? indexingCoordinator.resetAIProcessing()
        reloadLibrary()
    }

    public func dismissIndexingStatus() {
        indexingCoordinator.dismissIndexingStatus()
    }

    public var pendingAnalysisCount: Int {
        (try? indexStore.unanalyzedCount()) ?? 0
    }

    public func removeFolderSource(id: String) {
        guard let bookmark = bookmarkStore.bookmark(id: id) else { return }
        cancelIndexing()
        bookmarkStore.remove(id: id)
        _ = try? indexStore.removeAssets(sourceLabel: bookmark.displayName)
        #if os(macOS)
        sourceFolderWatcher?.refreshBookmarkPaths()
        #endif
        reloadLibrary()
    }

    public func undoTransfer(_ record: TransferRecord) async {
        do {
            try transferJournal.undo(record: record)
            reloadLibrary()
        } catch {
            indexingCoordinator.reportFailure(error.localizedDescription)
        }
    }

    public func saveCurrentSearchAsBookmark(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? indexStore.saveSearch(
            name: trimmed,
            query: commandQuery,
            pipeline: selectedPipeline,
            scope: browseScope,
            sort: librarySort
        )
    }

    public func applySavedSearch(_ record: SavedSearchRecord) {
        commandQuery = record.query
        selectedPipeline = MediaPipeline(rawValue: record.pipelineRaw) ?? .all
        librarySort = LibraryAssetSort(rawValue: record.sortRaw) ?? .dateModifiedNewest
        browseScope = decodeBrowseScope(record.browseScopeRaw)
        runSearch()
    }

    private func decodeBrowseScope(_ raw: String) -> LibraryBrowseScope {
        if raw == "all" { return .allSources }
        if raw == "catalog" { return .entireCatalog }
        if raw == "inbox" { return .inbox }
        if raw.hasPrefix("source|") {
            let parts = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            if parts.count >= 2 {
                let sub = parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil
                return .source(bookmarkID: parts[1], subfolder: sub)
            }
        }
        return .allSources
    }

    public func rescanAllFolderSources() {
        startDiscoverOnly()
        promptAITaggingIfNeeded()
    }

    /// Return in the command field. A confident navigation answer opens that screen. Otherwise this is a normal search.
    public func commitCommand() {
        let query = commandQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        if let surface = JevAdvisor.localSurface(for: query) {
            commandRouteTitle = nil
            applyJevSurface(surface)
            commandOrbPresented = false
            return
        }
        Task { [weak self] in
            guard let self else { return }
            if let surface = await JevAdvisor.route(query: query),
               commandQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query {
                applyJevSurface(surface)
                commandOrbPresented = false
                return
            }
            rerankNextSearch = true
            runSearch()
        }
    }

    private func applyJevSurface(_ surface: JevSurface) {
        switch surface {
        case .search:
            runSearch()
        case .library:
            libraryViewMode = .grid
            focus(mode: .library)
        case .garden:
            openGarden()
        case .sources:
            focus(mode: .sources)
        case .inbox:
            openInbox()
        case .organize:
            focus(mode: .organize)
        case .review:
            focus(mode: .review)
        case .duplicates:
            openDuplicates()
        }
    }

    public func runSearch() {
        semanticSearchTask?.cancel()
        let shouldRerank = rerankNextSearch
        rerankNextSearch = false
        let trimmedQuery = commandQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if let surface = JevAdvisor.localSurface(for: trimmedQuery) {
            commandRouteTitle = JevAdvisor.routeTitle(for: surface)
            return
        }
        commandRouteTitle = nil
        do {
            let personNames = try indexStore.buildPersonNameLookup()
            let visualOnly = !includeFileNamesInSearch
            let keywordRecords = try indexStore.searchAssets(
                query: commandQuery,
                includeFileNames: includeFileNamesInSearch,
                includeRecognizedText: !visualOnly
            )
            var results = keywordRecords
                .map { MediaAssetSummary(record: $0, personDisplayName: personNames[$0.id]) }
            results = applyBrowseScope(to: results)
            displayedAssets = results
            notchChrome.query = commandQuery
            let trimmed = commandQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            notchChrome.searchActive = !trimmed.isEmpty
            notchChrome.hits = Array(results.prefix(6))
            if notchChrome.searchActive {
                appMode = .library
            }
            guard !trimmed.isEmpty, ClipEmbeddingStore.status == .ready else { return }
            let query = trimmed
            let keywordIDs = keywordRecords.map(\.id)
            let includeNames = includeFileNamesInSearch
            semanticSearchTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let queryVector = try await ClipEmbeddingStore.shared.embedText(query)
                    let photoVector = try await ClipEmbeddingStore.shared.embedText("a photo of \(query)")
                    guard !Task.isCancelled, commandQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                        return
                    }
                    let semantic = try await SemanticCatalogSearch.shared.topHits(
                        query: queryVector,
                        also: [photoVector],
                        preferPhotographs: !includeNames
                    )
                    let documentIDs = Set(keywordRecords.filter { $0.kind == .document }.map(\.id))
                    let orderedIDs = SemanticRanker.blend(
                        keywordIDs: keywordIDs,
                        semantic: semantic,
                        limit: 100,
                        semanticFirst: !includeNames,
                        documentIDs: documentIDs
                    )
                    let records = try indexStore.fetchAssets(ids: orderedIDs)
                    let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
                    var blended = orderedIDs.compactMap { id -> MediaAssetSummary? in
                        guard let record = byID[id] else { return nil }
                        return MediaAssetSummary(record: record, personDisplayName: personNames[id])
                    }
                    blended = applyBrowseScope(to: blended)
                    guard !Task.isCancelled, commandQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                        return
                    }
                    displayedAssets = blended
                    notchChrome.hits = Array(blended.prefix(6))
                    if shouldRerank {
                        let documents = blended.filter { $0.kind == .document }
                        let others = blended.filter { $0.kind != .document }
                        let candidates = (documents.prefix(4) + others).prefix(8).map { item in
                            let labels = item.kind == .document
                                ? DocumentTags.sanitized(fileName: item.fileName, stored: item.topCategories)
                                : item.topCategories + item.detectedAnimals
                            return JevCandidate(
                                id: item.id,
                                fileName: item.fileName,
                                labels: Array(labels.prefix(6))
                            )
                        }
                        if let best = await JevAdvisor.promotedID(query: query, candidates: candidates),
                           !Task.isCancelled,
                           commandQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query,
                           let picked = blended.first(where: { $0.id == best }) {
                            blended.removeAll { $0.id == best }
                            blended.insert(picked, at: 0)
                            displayedAssets = blended
                            notchChrome.hits = Array(blended.prefix(6))
                        }
                    }
                } catch {
                    // Keyword/Vision results remain usable if Core ML fails.
                }
            }
        } catch {
            reloadLibrary()
        }
    }

    private func applyBrowseScope(to input: [MediaAssetSummary]) -> [MediaAssetSummary] {
        var results = input
        if browseScope == .inbox {
            let roots = resolvedSourceRoots()
            let dest = try? resolvedDestinationRoot()
            results = results.filter {
                InboxFilter.isInbox(
                    assetURL: $0.fileURL,
                    sourceRoots: roots,
                    destinationRoot: dest
                )
            }
        } else if let label = browseSourceLabel {
            results = results.filter { $0.sourceLabel == label }
        }
        if let root = try? browseSourceRootURL() {
            results = results.filter {
                LibraryBrowseFilter.matchesSubfolder(
                    fileURL: $0.fileURL,
                    sourceRoot: root,
                    subfolder: browseSubfolderPath
                )
            }
        }
        return results
    }

    public func selectAsset(_ asset: MediaAssetSummary, updateAmbientPalette: Bool = true) {
        selectedAsset = asset
        let personNames = (try? indexStore.buildPersonNameLookup()) ?? [:]
        relatedAssets = (try? clusterEngine.relatedAssets(to: asset.id, limit: 8))?
            .map { MediaAssetSummary(record: $0, personDisplayName: personNames[$0.id]) } ?? []
        guard updateAmbientPalette else { return }
        Task {
            if let path = asset.thumbnailPath {
                palette = await ColorExtractor.extract(from: URL(fileURLWithPath: path))
            }
        }
    }

    public func renameCollection(id: String, to name: String) {
        let title = name.isEmpty ? nil : name
        if personReviewGroups.contains(where: { $0.id == id }) {
            try? indexStore.renamePersonGroup(id: id, userTitle: title)
        } else {
            try? indexStore.renameCollection(id: id, userTitle: title)
        }
        reloadLibrary()
    }

    public func dismissPostOrganizeSuccess() {
        showPostOrganizeSuccess = false
    }

    public func onDiscoverCompleteForOrganize() {
        guard indexStore.assetCount > 0 else { return }
        browseScope = .entireCatalog
        appMode = .library
        if suggestStructureAfterDiscovery {
            suggestStructureAfterDiscovery = false
            showCatalogStructureWizard = true
        } else {
            showPostOrganizeSuccess = true
        }
    }

    public func keepCopiedOrigins() {
        pendingDeleteSourcePaths = []
        showConfirmDeleteOrigins = false
    }

    public func deleteCopiedOrigins() {
        let fm = FileManager.default
        for path in pendingDeleteSourcePaths {
            try? fm.removeItem(atPath: path)
        }
        pendingDeleteSourcePaths = []
        showConfirmDeleteOrigins = false
    }

    public func updateWindowContentSize(_ size: CGSize) {
        guard size.width > 100, size.height > 100 else { return }
        windowContentSize = size
    }

    public func openPreview(_ asset: MediaAssetSummary) {
        let pool = displayedAssets.isEmpty ? [asset] : displayedAssets
        let index = pool.firstIndex(where: { $0.id == asset.id }) ?? 0
        presentPreview(pool, index: index)
        selectAsset(asset, updateAmbientPalette: false)
    }

    /// Gives the carousel a real size. A zero panel is only the dimmed backdrop.
    private func presentPreview(_ assets: [MediaAssetSummary], index: Int) {
        guard !assets.isEmpty else { return }
        if previewPanelSize.width < 200 || previewPanelSize.height < 200 {
            previewPanelSize = CGSize(
                width: max(windowContentSize.width, 960) * 0.88,
                height: max(windowContentSize.height, 640) * 0.88
            )
        }
        previewAssets = assets
        previewIndex = min(max(index, 0), assets.count - 1)
        previewIsFullscreen = false
        showAssetPreview = true
    }

    public func restoreLibraryIfSearchEmptiedIt() {
        let command = JevAdvisor.localSurface(for: commandQuery) != nil
        let emptied = notchChrome.searchActive && displayedAssets.isEmpty
        guard command || emptied else { return }
        commandQuery = ""
        commandRouteTitle = nil
        notchChrome.query = ""
        notchChrome.searchActive = false
        notchChrome.hits = []
        reloadLibrary()
    }

    public func stepPreview(by delta: Int) {
        guard !previewAssets.isEmpty else { return }
        let next = min(max(previewIndex + delta, 0), previewAssets.count - 1)
        guard next != previewIndex else { return }
        previewIndex = next
        if let asset = previewAsset {
            selectAsset(asset, updateAmbientPalette: false)
        }
    }

    public func selectPreview(at index: Int) {
        guard index >= 0, index < previewAssets.count else { return }
        previewIndex = index
        syncPreviewSelection()
    }

    public func closePreview() {
        showAssetPreview = false
        previewAssets = []
        previewIndex = 0
        previewIsFullscreen = false
        previewPanelSize = .zero
    }

    public func clearSelection() {
        selectedAsset = nil
        relatedAssets = []
        updatePalette()
    }

    private func updatePalette() {
        guard let first = displayedAssets.first,
              let path = first.thumbnailPath else {
            palette = .defaultPalette
            return
        }
        Task {
            palette = await ColorExtractor.extract(from: URL(fileURLWithPath: path))
        }
    }

    #if os(macOS)
    public func startSourceFolderWatcher() {
        guard watchSourceFolders else { return }
        if sourceFolderWatcher == nil {
            let watcher = SourceFolderWatcher(bookmarkStore: bookmarkStore)
            watcher.onFoldersChanged = { [weak self] bookmarks, paths in
                guard let self else { return }
                Task { @MainActor in
                    await self.indexingCoordinator.ingestChangedFiles(bookmarks: bookmarks, paths: paths)
                }
            }
            sourceFolderWatcher = watcher
        }
        sourceFolderWatcher?.refreshBookmarkPaths()
        sourceFolderWatcher?.start()
    }

    public func stopSourceFolderWatcher() {
        sourceFolderWatcher?.stop()
    }
    #endif

    public func runDuplicateScan() {
        guard !isScanningDuplicates else { return }
        isScanningDuplicates = true
        duplicateScanFraction = 0.02
        duplicateScanLabel = "Reading the catalog…"
        Task { [weak self] in
            guard let self else { return }
            await Task.yield()
            let records = (try? indexStore.fetchAssets()) ?? []
            duplicateScanLabel = "Comparing \(records.count) photos…"
            duplicateScanFraction = 0.08
            let groups = await DuplicateFinderEngine.findGroupsAsync(in: records) { [weak self] done, total in
                Task { @MainActor in
                    self?.noteDuplicateProgress(done: done, total: total)
                }
            }
            duplicateGroups = groups
            notchChrome.duplicateCount = groups.count
            duplicateScanFraction = 1
            duplicateScanLabel = groups.isEmpty ? "No duplicate groups" : "\(groups.count) groups"
            isScanningDuplicates = false
        }
    }

    private func noteDuplicateProgress(done: Int, total: Int) {
        let fraction = 0.08 + 0.92 * Double(done) / Double(max(total, 1))
        duplicateScanFraction = min(1, fraction)
        duplicateScanLabel = "Comparing \(done) of \(total)"
    }

    public func openDuplicateGroupInPreview(_ group: DuplicateGroup) {
        let personNames = (try? indexStore.buildPersonNameLookup()) ?? [:]
        let records = (try? indexStore.fetchAssets(ids: group.memberIDs)) ?? []
        let order = Dictionary(uniqueKeysWithValues: group.memberIDs.enumerated().map { ($1, $0) })
        let assets = records
            .sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
            .map { MediaAssetSummary(record: $0, personDisplayName: personNames[$0.id]) }
        let index = assets.firstIndex(where: { $0.id == group.suggestedKeepID }) ?? 0
        presentPreview(assets, index: index)
    }

    /// Moves every file in the group except the suggested keep into the Trash, then drops those catalog rows.
    public func trashDuplicateExtras(_ group: DuplicateGroup) {
        let extraIDs = group.extraIDs
        guard !extraIDs.isEmpty else { return }
        let records = (try? indexStore.fetchAssets(ids: extraIDs)) ?? []
        let urls = records.map(\.fileURL).filter { FileManager.default.fileExists(atPath: $0.path) }
        #if os(macOS)
        NSWorkspace.shared.recycle(urls) { _, error in
            Task { @MainActor in
                guard error == nil else { return }
                try? self.indexStore.forgetAssets(ids: extraIDs)
                self.duplicateGroups.removeAll { $0.id == group.id }
                self.notchChrome.duplicateCount = self.duplicateGroups.count
                self.reloadLibrary()
            }
        }
        #else
        try? indexStore.forgetAssets(ids: extraIDs)
        duplicateGroups.removeAll { $0.id == group.id }
        reloadLibrary()
        #endif
    }

    public func acceptCollection(id: String) {
        if let group = personReviewGroups.first(where: { $0.id == id }) {
            try? indexStore.acceptPersonGroup(id: group.id, title: group.title)
        } else {
            try? indexStore.acceptCollection(id: id)
        }
        reloadLibrary()
    }

    public func acceptPersonGroup(_ group: PersonReviewGroup) {
        try? indexStore.acceptPersonGroup(id: group.id, title: group.title)
        reloadLibrary()
    }

    public func openPersonGroup(_ group: PersonReviewGroup) {
        let personNames = (try? indexStore.buildPersonNameLookup()) ?? [:]
        let records = (try? indexStore.fetchAssets(ids: group.assetIDs)) ?? []
        let order = Dictionary(uniqueKeysWithValues: group.assetIDs.enumerated().map { ($1, $0) })
        let assets = records
            .sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
            .map { MediaAssetSummary(record: $0, personDisplayName: personNames[$0.id]) }
        presentPreview(assets, index: 0)
    }

    public func rejectCollection(id: String) {
        try? indexStore.rejectCollection(id: id)
        reloadLibrary()
    }

    public func moveSelectedAssets(to bucket: StagingBucket) async {
        if selectedAssetIDs.isEmpty {
            await moveSelectedAsset(to: bucket)
            return
        }
        let targets = displayedAssets.filter { selectedAssetIDs.contains($0.id) }
        for asset in targets {
            await moveAsset(asset, to: bucket)
        }
        clearAssetSelection()
    }

    public func performFactoryReset() {
        #if os(macOS)
        stopSourceFolderWatcher()
        #endif
        try? LibraryResetCoordinator.resetAll(
            indexStore: indexStore,
            bookmarkStore: bookmarkStore,
            destinationStore: destinationStore
        )
        duplicateGroups = []
        clearAssetSelection()
        reloadLibrary()
    }

    private func updateIslandVisibility() {
        #if os(macOS)
        islandController.install(
            jobs: jobCenter,
            chrome: notchChrome,
            onOpenMode: { [weak self] mode in self?.focus(mode: mode) },
            onActivateStatus: { [weak self] in self?.activateIslandStatus() },
            onOpenGarden: { [weak self] in self?.openGarden() },
            onOpenInbox: { [weak self] in self?.openInbox() },
            onOpenDuplicates: { [weak self] in self?.openDuplicates() },
            onFocusSearch: { [weak self] in self?.focusSearch() },
            onBrowseCatalog: { [weak self] in self?.browseEntireCatalog() },
            onPreviewPlan: { [weak self] in self?.refreshOrganizePlan() },
            onStop: { [weak self] in self?.stopIndexing() },
            onSubmitSearch: { [weak self] query in self?.submitNotchSearch(query) },
            onQueryEdited: { [weak self] query in self?.noteNotchQuery(query) },
            onOpenHit: { [weak self] asset in self?.openNotchHit(asset) },
            onClearSearch: { [weak self] in self?.clearNotchSearch() },
            onDropURLs: { [weak self] urls in self?.ingestDropped(urls) },
            onPause: { [weak self] in self?.pauseIndexing() },
            onResume: { [weak self] in self?.resumeIndexing() },
            onQuit: {
                #if os(macOS)
                NSApp.terminate(nil)
                #endif
            }
        )
        if !isIndexing, case .complete = indexingCoordinator.phase {
            SiftNotificationService.notify(
                title: "Sift",
                body: "Indexing finished — your library is ready."
            )
        }
        #endif
    }
}

private enum ScanKindStore {
    private static let key = "sift.scan.kinds"

    static func load() -> Set<MediaKind> {
        guard let raw = UserDefaults.standard.stringArray(forKey: key) else {
            return Set(MediaKind.allCases)
        }
        let kinds = Set(raw.compactMap(MediaKind.init(rawValue:)))
        return kinds.isEmpty ? Set(MediaKind.allCases) : kinds
    }

    static func save(_ kinds: Set<MediaKind>) {
        UserDefaults.standard.set(kinds.map(\.rawValue).sorted(), forKey: key)
    }

    private static let extensionsKey = "sift.scan.documentExtensions"

    static func loadExtensions() -> Set<String> {
        guard let raw = UserDefaults.standard.stringArray(forKey: extensionsKey) else {
            return DocumentFormats.extensions
        }
        let known = Set(raw.filter { DocumentFormats.extensions.contains($0) })
        return known.isEmpty ? DocumentFormats.extensions : known
    }

    static func saveExtensions(_ extensions: Set<String>) {
        UserDefaults.standard.set(extensions.sorted(), forKey: extensionsKey)
    }
}
