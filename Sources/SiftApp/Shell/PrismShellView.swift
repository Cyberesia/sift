import SiftCore
import SiftDesign
import SwiftUI

#if os(macOS)
import AppKit
#endif

public struct PrismShellView: View {
    @ObservedObject private var session: SiftRootSession
    @ObservedObject private var destinationStore: DestinationStore
    @ObservedObject private var indexer: IndexingCoordinator
    @ObservedObject private var indexStore: MediaIndexStore
    @ObservedObject private var jobCenter: BackgroundJobCenter

    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif
    @State private var hoveredLibraryAsset: MediaAssetSummary?
    @State private var showHelp = false
    @State private var clearLibraryHover: Task<Void, Never>?
    @State private var cardOnLeading = false
    @State private var pointerProbe = LibraryPointerProbe()

    public init(session: SiftRootSession) {
        self.session = session
        _destinationStore = ObservedObject(wrappedValue: session.destinationStore)
        _indexer = ObservedObject(wrappedValue: session.indexingCoordinator)
        _indexStore = ObservedObject(wrappedValue: session.indexStore)
        _jobCenter = ObservedObject(wrappedValue: session.jobCenter)
    }

    public var body: some View {
        GeometryReader { windowGeo in
            ZStack(alignment: .bottom) {
                LivingCanvas(palette: session.palette) {
                    VStack(spacing: 16) {
                        modePicker
                        HStack(alignment: .top, spacing: 24) {
                            StrataSidebar(
                                selectedPipeline: $session.selectedPipeline,
                                counts: session.pipelineCounts(),
                                personCollections: session.personCollections,
                                selectedPersonCollectionID: session.selectedPersonCollectionID,
                                onSelectPersonCollection: session.selectPersonCollection
                            )

                            ZStack(alignment: .topLeading) {
                                modeContent
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                if indexer.showsBlockingOverlay {
                                    IndexingOverlay(
                                        phase: indexer.phase,
                                        assetCount: indexStore.assetCount,
                                        isPaused: indexer.isPaused,
                                        onPause: session.pauseIndexing,
                                        onResume: session.resumeIndexing,
                                        onStop: session.stopIndexing,
                                        onCancel: session.cancelIndexing
                                    )
                                }
                            }
                            .prismGlass(cornerRadius: 28, padding: 0)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                indexDock
                    .zIndex(100)
            }
            .overlay {
                if session.commandOrbPresented {
                    CommandOrb(
                        isPresented: $session.commandOrbPresented,
                        query: $session.commandQuery,
                        savedSearches: (try? indexStore.fetchSavedSearches()) ?? [],
                        results: session.displayedAssets,
                        semanticReady: session.notchChrome.clipReady,
                        analyzedCount: indexStore.analyzedCount,
                        catalogCount: indexStore.assetCount,
                        onSubmit: session.runSearch,
                        onCommit: session.commitCommand,
                        routeHint: session.commandRouteTitle,
                        onSelectSavedSearch: session.applySavedSearch,
                        onSaveSearch: { session.saveCurrentSearchAsBookmark(name: $0) },
                        onOpenResult: session.openPreview,
                        onRunAnalysis: session.startBackgroundAnalysis,
                        includeFileNames: Binding(
                            get: { session.includeFileNamesInSearch },
                            set: { session.setIncludeFileNamesInSearch($0) }
                        )
                    )
                }
            }
            .onAppear {
                session.updateWindowContentSize(windowGeo.size)
            }
            .onChange(of: windowGeo.size) { _, newSize in
                session.updateWindowContentSize(newSize)
            }
            .onChange(of: session.commandQuery) { _, query in
                if session.notchChrome.query != query {
                    session.notchChrome.query = query
                }
            }
            .overlay {
                if session.showAssetPreview, !session.previewAssets.isEmpty {
                    AssetPreviewCarousel(
                        assets: session.previewAssets,
                        selectionIndex: $session.previewIndex,
                        isFullscreen: $session.previewIsFullscreen,
                        panelSize: session.previewPanelSize,
                        windowSize: windowGeo.size,
                        mediaAccessRoot: session.mediaAccessRoot(for:),
                        onClose: session.closePreview,
                        onRevealInFinder: PreviewActions.revealInFinder,
                        onCopyPath: PreviewActions.copyPath,
                        onMoveToPhotos: { Task { await session.moveSelectedAsset(to: .photos) } },
                        onMoveToVideos: { Task { await session.moveSelectedAsset(to: .videos) } },
                        onMoveToGather: { Task { await session.moveSelectedAsset(to: .gather) } },
                        onPersonLabelCommit: { name in
                            guard let asset = session.previewAsset else { return }
                            session.setPersonLabel(assetID: asset.id, name: name)
                        }
                    )
                    .zIndex(200)
                }
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .tint(PrismTheme.accent)
        .onChange(of: session.selectedPipeline) { _, _ in
            session.selectedPersonCollectionID = nil
            session.reloadLibrary()
        }
        .onChange(of: session.browseScope) { _, _ in
            session.reloadLibrary()
        }
        .onChange(of: session.librarySort) { _, _ in
            session.reloadLibrary()
        }
        .onChange(of: session.libraryKindFilter) { _, _ in
            session.reloadLibrary()
        }
        .onChange(of: session.commandOrbPresented) { _, open in
            if !open { session.restoreLibraryIfSearchEmptiedIt() }
        }
        .onChange(of: session.previewIndex) { _, _ in
            session.syncPreviewSelection()
        }
        .onChange(of: indexer.phase) { _, phase in
            jobCenter.sync(from: phase)
        }
        .onReceive(NotificationCenter.default.publisher(for: .siftToggleCommandOrb)) { _ in
            session.commandOrbPresented.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .siftAssetSelected)) { note in
            guard let id = note.object as? String,
                  let asset = session.displayedAssets.first(where: { $0.id == id }) else { return }
            session.openPreview(asset)
        }
        .sheet(isPresented: $showHelp) {
            SiftHelpView(mode: session.appMode.rawValue, onClose: { showHelp = false })
        }
        .sheet(isPresented: $session.showMacScanWizard) {
            MacScanWizard(
                fullDiskAccess: FullDiskAccessProbe.isGranted(),
                lookingFor: ScanActivityCopy.lookingFor(session.scanKinds),
                onScanMac: session.scanStandardMacLocations,
                onChooseLocations: { Task { await session.addLocations() } },
                onOpenSettings: session.openFullDiskAccessSettings,
                onClose: { session.showMacScanWizard = false }
            )
        }
        .sheet(isPresented: $session.showOrganizePlan) {
            OrganizePlanSheet(
                items: session.organizePlan,
                confirmLabel: organizeConfirmLabel,
                canConfirm: session.transferChoiceConfirmed,
                onApproveSafe: { Task { await session.approveSafeOrganization() } },
                onClose: { session.showOrganizePlan = false }
            )
        }
        .sheet(isPresented: $session.showCatalogStructureWizard) {
            CatalogStructureWizard(
                activeDestinationName: session.activeDestinationName,
                destinationPath: session.activeDestinationPath,
                selectedFolders: $session.structureFolders,
                onChooseDestination: { Task { await session.chooseCatalogStructureDestination() } },
                onCreateStructure: { Task { await session.createSuggestedCatalogStructure() } },
                onClose: { session.showCatalogStructureWizard = false }
            )
        }
        .sheet(isPresented: $session.showFolderIntakeWizard) {
            if let estimate = session.folderEstimate, let url = session.pendingFolderURL {
                FolderIntakeWizard(
                    folderName: url.lastPathComponent,
                    estimate: estimate,
                    selectedPaths: $session.selectedSubfolderPaths,
                    includeSubfolders: $session.pendingIncludeSubfolders,
                    onCancel: session.cancelFolderIntake,
                    onConfirm: session.confirmFolderIntake
                )
            }
        }
        .sheet(isPresented: $session.showDestinationWizard) {
            DestinationWizard(
                destinations: destinationStore.destinations,
                activeDestinationID: destinationStore.activeDestinationID,
                onAddDestination: { Task { await session.addDestination() } },
                onSelectDestination: session.selectDestination,
                onRemoveDestination: session.removeDestination,
                onCancel: { session.showDestinationWizard = false },
                onDone: session.finishDestinationSetup
            )
        }
        .sheet(isPresented: $session.showStartAITagging) {
            StartAITaggingSheet(
                dontAskAgain: $session.skipAITaggingPrompt,
                pendingCount: session.pendingAnalysisCount,
                onLater: { session.showStartAITagging = false },
                onStart: {
                    session.skipAITaggingPrompt = session.skipAITaggingPrompt
                    session.startBackgroundAnalysis()
                }
            )
        }
        .onAppear {
            #if os(macOS)
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
            Task { @MainActor in
                session.prepareInteractiveLaunch()
            }
            #endif
        }
        .onChange(of: indexer.discoveryGeneration) { _, generation in
            guard generation > 0 else { return }
            session.onDiscoverCompleteForOrganize()
        }
        .sheet(isPresented: $session.showPostOrganizeSuccess) {
            PostOrganizeSuccessSheet(
                assetCount: indexStore.assetCount,
                destinationCount: destinationStore.destinations.count,
                activeDestinationName: session.activeDestinationName,
                onOpenLibrary: {
                    session.appMode = .library
                    session.dismissPostOrganizeSuccess()
                },
                onOpenOrganize: {
                    session.dismissPostOrganizeSuccess()
                    session.showCatalogStructureWizard = true
                },
                onDismiss: session.dismissPostOrganizeSuccess
            )
        }
        .sheet(isPresented: $session.showConfirmDeleteOrigins) {
            ConfirmDeleteOriginsSheet(
                paths: session.pendingDeleteSourcePaths,
                onKeep: session.keepCopiedOrigins,
                onDelete: session.deleteCopiedOrigins
            )
        }
        .overlay {
            if session.showClipWeightSplash {
                ClipWeightSplash(
                    progress: session.clipWeightProgress,
                    errorMessage: session.clipWeightError,
                    onRetry: session.retryClipWeightDownload,
                    onContinue: session.dismissClipWeightSplash
                )
                .zIndex(400)
            }
        }
    }

    private var indexDock: some View {
        IndexDock(
            phase: indexer.phase,
            assetCount: indexStore.assetCount,
            analyzedCount: indexStore.analyzedCount,
            inboxCount: session.inboxCount,
            sourceFolderCount: session.bookmarkStore.folders.count,
            isPaused: indexer.isPaused,
            showsTransportControls: indexer.showsTransportControls,
            showsRecoveryControls: indexer.showsRecoveryControls,
            pendingAnalysisCount: session.pendingAnalysisCount,
            scanDetail: indexer.activityDetail.isEmpty
                ? ScanActivityCopy.lookingFor(session.scanKinds)
                : indexer.activityDetail,
            onAddSourceFolder: { session.showMacScanWizard = true },
            onRescanSources: session.startDiscoverOnly,
            onPause: session.pauseIndexing,
            onResume: session.resumeIndexing,
            onStop: session.stopIndexing,
            onCancel: session.cancelIndexing,
            onContinueIndexing: session.continueIndexing,
            onResetAI: session.resetAIProcessing,
            onDismissStatus: session.dismissIndexingStatus
        )
    }

    private var modePicker: some View {
        HStack(spacing: 10) {
            PrismModePicker(selection: $session.appMode)
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .help("Help for this page")
            .prismClickable()
            #if os(macOS)
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .help("Settings · Jev API key, source watching, transfers, and maintenance")
            .prismClickable()
            #endif
        }
        .frame(maxWidth: 590)
    }

    @ViewBuilder
    private var modeContent: some View {
        switch session.appMode {
        case .sources:
            sourcesMode
        case .organize:
            organizeMode
        case .library:
            libraryMode
        case .review:
            reviewMode
        }
    }

    private var sourcesMode: some View {
        DiscoveryWorkspaceView(
            folders: session.bookmarkStore.folders,
            assetCount: indexStore.assetCount,
            analyzedCount: indexStore.analyzedCount,
            onScanMac: { session.showMacScanWizard = true },
            onChooseLocations: { Task { await session.addLocations() } },
            onRescan: session.startDiscoverOnly,
            onReplaceFolder: { id in Task { await session.replaceFolderSource(id: id) } },
            onRemoveFolder: session.removeFolderSource,
            onPlanStructure: { session.showCatalogStructureWizard = true },
            scanKinds: session.scanKinds,
            onToggleScanKind: session.setScanKind,
            documentExtensions: session.scanDocumentExtensions,
            onToggleDocumentExtension: session.setScanDocumentExtension,
            filingNote: session.filingSummary.line(folderName: session.activeDestinationName)
        )
    }

    private var organizeConfirmLabel: String {
        let ready = session.organizePlan.filter { !$0.blocked }.count
        let name = session.activeDestinationName.isEmpty ? "the folder" : session.activeDestinationName
        guard session.transferChoiceConfirmed else { return "Choose move or copy first" }
        guard ready > 0 else { return "Nothing new to file" }
        switch session.fileTransferMode {
        case .move: return "Move \(ready) files into \(name)"
        case .copy: return "Copy \(ready) files into \(name)"
        case .copyThenConfirmDelete: return "Copy \(ready) files into \(name), then ask"
        }
    }

    private var organizeMode: some View {
        ReorganizeWorkspaceView(
            transferMode: transferModeBinding,
            destinations: destinationStore.destinations,
            activeDestinationID: destinationStore.activeDestinationID,
            activeDestinationName: session.activeDestinationName,
            pendingCount: indexStore.assetCount,
            hasSelectedAsset: session.selectedAsset != nil,
            batchSelectionCount: session.selectedAssetIDs.count,
            ruleSuggestions: session.organizeRulesEngine.suggestions(
                for: (try? indexStore.fetchAssets()) ?? [],
                sourceRoots: session.resolvedSourceRoots(),
                destinationRoot: try? session.resolvedDestinationRoot()
            ),
            onSelectDestination: session.selectDestination,
            onRemoveDestination: session.removeDestination,
            onAddDestination: { Task { await session.addDestination() } },
            onMoveToPhotos: { Task { await session.moveSelectedAssets(to: .photos) } },
            onMoveToVideos: { Task { await session.moveSelectedAssets(to: .videos) } },
            onMoveToGather: { Task { await session.moveSelectedAssets(to: .gather) } },
            onStartDiscover: session.startDiscoverOnly,
            planItems: session.organizePlan,
            onPreviewPlan: session.refreshOrganizePlan,
            onApproveSafe: { Task { await session.approveSafeOrganization() } },
            destinationPath: session.activeDestinationPath,
            filingNote: session.filingSummary.line(folderName: session.activeDestinationName),
            transferChoiceConfirmed: session.transferChoiceConfirmed
        )
    }

    private var transferModeBinding: Binding<FileTransferMode> {
        Binding(
            get: { session.fileTransferMode },
            set: { session.fileTransferMode = $0 }
        )
    }

    @ViewBuilder
    private var libraryMode: some View {
        let hasLibrary = indexStore.assetCount > 0
        if !hasLibrary && !session.isIndexing {
            VStack(spacing: 20) {
                OnboardingEmptyState(
                    onScanMac: { session.showMacScanWizard = true },
                    onChooseLocations: { Task { await session.addLocations() } },
                    onEnablePhotos: { Task { await session.enablePhotosLibrary() } }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 12) {
                LibraryToolbar(
                    viewMode: $session.libraryViewMode,
                    assetCount: indexStore.assetCount,
                    folderCount: session.bookmarkStore.folders.count,
                    onAddFolder: { Task { await session.addFolder() } },
                    onOpenSources: openSources,
                    onSearch: session.focusSearch,
                    statusNote: session.filingSummary.line(folderName: session.activeDestinationName)
                )
                LibraryBrowseBar(
                    browseScope: $session.browseScope,
                    librarySort: $session.librarySort,
                    kindFilter: $session.libraryKindFilter,
                    folderSources: session.bookmarkStore.folders,
                    subfolderOptions: session.browseSubfolderOptions,
                    filteredCount: session.displayedAssets.count
                )
                ZStack {
                    libraryBrowser
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onContinuousHover { phase in
                            if case .active(let location) = phase {
                                pointerProbe.x = location.x
                            }
                        }
                        .background {
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { pointerProbe.width = geo.size.width }
                                    .onChange(of: geo.size.width) { _, width in
                                        pointerProbe.width = width
                                    }
                            }
                        }
                    floatingDetailCard
                }
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: floatingCardKey)
            }
            .padding(12)
        }
    }

    /// The detail card floats over the gallery instead of taking a column from it.
    /// A hover card sits on the side away from the pointer and lets clicks pass through.
    /// The card for a selected item stays on the trailing side and can be closed.
    @ViewBuilder
    private var floatingDetailCard: some View {
        let hovered = hoveredLibraryAsset
        if let cardAsset = hovered ?? session.selectedAsset {
            let isHoverCard = hovered != nil
            let leading = isHoverCard && cardOnLeading
            let inGarden = session.libraryViewMode == .orbit
            ViewThatFits(in: .vertical) {
                detailCard(cardAsset)
                ScrollView(showsIndicators: false) {
                    detailCard(cardAsset)
                }
            }
            .frame(width: 300)
            .overlay(alignment: .topTrailing) {
                if !isHoverCard {
                    Button {
                        hoveredLibraryAsset = nil
                        session.selectedAsset = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(.black.opacity(0.45), in: Circle())
                            .overlay { Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .prismClickable()
                    .help("Close")
                    .padding(10)
                }
            }
            .shadow(color: .black.opacity(0.45), radius: 28, y: 14)
            .allowsHitTesting(!isHoverCard)
            .padding(.top, inGarden ? 46 : 12)
            .padding(.bottom, inGarden ? 52 : 12)
            .padding(.horizontal, 14)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: cardAlignment(leading: leading, inGarden: inGarden)
            )
            .transition(
                .opacity.combined(with: .scale(scale: 0.96, anchor: cardAnchor(leading: leading, inGarden: inGarden)))
            )
            .id(leading)
        }
    }

    /// The Garden stages draw their strongest motion near the top, so the card rests at the bottom there.
    private func cardAlignment(leading: Bool, inGarden: Bool) -> Alignment {
        switch (leading, inGarden) {
        case (true, true): .bottomLeading
        case (false, true): .bottomTrailing
        case (true, false): .topLeading
        case (false, false): .topTrailing
        }
    }

    private func cardAnchor(leading: Bool, inGarden: Bool) -> UnitPoint {
        switch (leading, inGarden) {
        case (true, true): .bottomLeading
        case (false, true): .bottomTrailing
        case (true, false): .topLeading
        case (false, false): .topTrailing
        }
    }

    private func detailCard(_ cardAsset: MediaAssetSummary) -> some View {
        AssetDetailView(
            asset: cardAsset,
            related: cardAsset.id == session.selectedAsset?.id ? session.relatedAssets : [],
            onOpenRelated: session.openPreview,
            onPersonLabelCommit: { name in
                session.setPersonLabel(assetID: cardAsset.id, name: name)
            }
        )
    }

    private var floatingCardKey: String {
        let shown = (hoveredLibraryAsset ?? session.selectedAsset) != nil
        return "\(shown)-\(hoveredLibraryAsset != nil && cardOnLeading)"
    }

    private var reviewMode: some View {
        ReviewAIWorkspaceView(
            collections: session.collections.filter {
                $0.isSuggested && !$0.isAccepted && $0.collectionKind != .person && ($0.assets?.isEmpty == false)
            },
            personGroups: session.personReviewGroups,
            duplicateGroups: session.duplicateGroups,
            assetCount: indexStore.assetCount,
            analyzedCount: indexStore.analyzedCount,
            pendingAnalysisCount: session.pendingAnalysisCount,
            isScanningDuplicates: session.isScanningDuplicates,
            duplicateScanLabel: session.duplicateScanLabel,
            duplicateScanFraction: session.duplicateScanFraction,
            onRenameCollection: session.renameCollection,
            onAcceptCollection: session.acceptCollection,
            onRejectCollection: session.rejectCollection,
            onRunAITagging: session.startBackgroundAnalysis,
            onScanDuplicates: session.runDuplicateScan,
            onOpenDuplicateGroup: session.openDuplicateGroupInPreview,
            onTrashDuplicateExtras: session.trashDuplicateExtras,
            onOpenPersonGroup: session.openPersonGroup
        )
    }

    @ViewBuilder
    private var libraryBrowser: some View {
        switch session.libraryViewMode {
        case .grid:
            PhotoMosaicGrid(
                assets: session.displayedAssets,
                columns: 4,
                selectedIDs: session.selectedAssetIDs,
                onOpen: { session.openPreview($0) },
                onHoverAsset: noteLibraryHover,
                onToggleSelection: { asset, extend in
                    session.toggleAssetSelection(asset.id, rangeAssets: session.displayedAssets, extendRange: extend)
                },
                hasMore: session.hasMoreLibraryAssets,
                isLoadingMore: session.isLoadingLibraryPage,
                onLoadMore: session.loadNextLibraryPage
            )
        case .list:
            MediaListView(
                assets: session.displayedAssets,
                hasMore: session.hasMoreLibraryAssets,
                onLoadMore: session.loadNextLibraryPage,
                onHoverAsset: noteLibraryHover
            ) { asset in
                session.openPreview(asset)
            }
        case .orbit:
            OrbitGardenView(
                assets: session.displayedAssets,
                directions: $session.visualDirections,
                hasMore: session.hasMoreLibraryAssets,
                onLoadMore: session.loadNextLibraryPage,
                onHoverAsset: noteLibraryHover,
                onOpen: { session.openPreview($0) }
            )
        }
    }

    private func noteLibraryHover(_ asset: MediaAssetSummary?) {
        if let asset {
            clearLibraryHover?.cancel()
            let onLeading = pointerProbe.x > pointerProbe.width * 0.5
            if cardOnLeading != onLeading {
                cardOnLeading = onLeading
            }
            hoveredLibraryAsset = asset
        } else {
            clearLibraryHover?.cancel()
            clearLibraryHover = Task {
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                hoveredLibraryAsset = nil
            }
        }
    }

    private func openSources() {
        #if os(macOS)
        openSettings()
        session.appMode = .sources
        #endif
    }
}

/// Pointer position over the gallery. A reference type, so moving the mouse does not re-render the shell.
private final class LibraryPointerProbe {
    var x: CGFloat = 0
    var width: CGFloat = 1
}

extension Notification.Name {
    static let siftToggleCommandOrb = Notification.Name("sift.toggleCommandOrb")
}
