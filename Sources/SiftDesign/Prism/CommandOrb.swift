import SiftCore
import SwiftUI

public struct CommandOrb: View {
    @Binding var isPresented: Bool
    @Binding var query: String
    let savedSearches: [SavedSearchRecord]
    let results: [MediaAssetSummary]
    let semanticReady: Bool
    let analyzedCount: Int
    let catalogCount: Int
    let onSubmit: () -> Void
    let onCommit: () -> Void
    let routeHint: String?
    let onSelectSavedSearch: (SavedSearchRecord) -> Void
    let onSaveSearch: (String) -> Void
    let onOpenResult: (MediaAssetSummary) -> Void
    let onRunAnalysis: () -> Void
    @Binding var includeFileNames: Bool

    @State private var saveName = ""
    @State private var liveSearchTask: Task<Void, Never>?

    public init(
        isPresented: Binding<Bool>,
        query: Binding<String>,
        savedSearches: [SavedSearchRecord] = [],
        results: [MediaAssetSummary] = [],
        semanticReady: Bool = false,
        analyzedCount: Int = 0,
        catalogCount: Int = 0,
        onSubmit: @escaping () -> Void,
        onCommit: (() -> Void)? = nil,
        routeHint: String? = nil,
        onSelectSavedSearch: @escaping (SavedSearchRecord) -> Void = { _ in },
        onSaveSearch: @escaping (String) -> Void = { _ in },
        onOpenResult: @escaping (MediaAssetSummary) -> Void = { _ in },
        onRunAnalysis: @escaping () -> Void = {},
        includeFileNames: Binding<Bool> = .constant(false)
    ) {
        _isPresented = isPresented
        _query = query
        self.savedSearches = savedSearches
        self.results = results
        self.semanticReady = semanticReady
        self.analyzedCount = analyzedCount
        self.catalogCount = catalogCount
        self.onSubmit = onSubmit
        self.onCommit = onCommit ?? onSubmit
        self.routeHint = routeHint
        self.onSelectSavedSearch = onSelectSavedSearch
        self.onSaveSearch = onSaveSearch
        self.onOpenResult = onOpenResult
        self.onRunAnalysis = onRunAnalysis
        _includeFileNames = includeFileNames
    }

    public var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }

                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(PrismTheme.accent)
                        TextField("Describe an image, person, place, filename, or text…", text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .onSubmit(onCommit)
                            .onChange(of: query) { _, _ in
                                liveSearchTask?.cancel()
                                liveSearchTask = Task {
                                    try? await Task.sleep(for: .milliseconds(280))
                                    guard !Task.isCancelled else { return }
                                    await MainActor.run { onSubmit() }
                                }
                            }
                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        Text("↩ Search")
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(PrismTheme.glassStrokeGradient, lineWidth: 1)
                    }

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        emptySearchContent
                    } else if let routeHint {
                        Text(routeHint)
                            .font(.headline)
                            .foregroundStyle(PrismTheme.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        visualResults
                    }

                    if query.isEmpty, !savedSearches.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Saved searches")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(savedSearches.prefix(6), id: \.id) { saved in
                                Button {
                                    onSelectSavedSearch(saved)
                                } label: {
                                    HStack {
                                        Text(saved.name)
                                            .font(.caption.weight(.medium))
                                        Spacer()
                                        Text(saved.query)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                                .prismClickable()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !query.isEmpty {
                        HStack {
                        TextField("Save search as…", text: $saveName)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        Button("Save") {
                            onSaveSearch(saveName)
                            saveName = ""
                        }
                        .font(.caption.weight(.semibold))
                        .disabled(saveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .prismClickable()
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: 920, maxHeight: 650)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(PrismTheme.glassStrokeGradient, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.4), radius: 40, y: 16)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private var emptySearchContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(PrismTheme.accentGradient)
            Text("Search your visual library")
                .font(.headline)
            Text(semanticReady
                 ? "CLIP searches what the picture shows. Turn on Filenames to also match names and text inside the image."
                 : "Search filenames, OCR, Vision labels, and people. Install the local CLIP model to add visual-language search.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }

    private var visualResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(results.isEmpty ? "No pictures found" : "\(results.count) matches")
                    .font(.caption.weight(.semibold))
                Spacer()
                Toggle("Filenames", isOn: $includeFileNames)
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #endif
                    .font(.caption.weight(.medium))
                    .help("Include file names and text read inside the picture. Off keeps the search on what the picture shows.")
                Label(
                    semanticReady
                        ? (includeFileNames ? "Visual CLIP + filenames" : "Visual content only")
                        : (includeFileNames ? "Filenames, OCR & labels" : "OCR, labels & people"),
                    systemImage: semanticReady ? "brain.head.profile" : "text.magnifyingglass"
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !semanticReady, analyzedCount < catalogCount {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("Content recognition is ready for \(analyzedCount) of \(catalogCount) items. Until analysis finishes, unmatched items can only be found by filename or metadata.")
                        .lineLimit(2)
                    Spacer()
                    Button("Analyze remaining", action: onRunAnalysis)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .font(.caption2)
                .foregroundStyle(PrismTheme.textSecondary)
                .padding(9)
                .background(PrismTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
            }

            if results.isEmpty {
                ContentUnavailableView(
                    "No visual matches",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("Try a filename, visible text, person, place, or a broader description.")
                )
                .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                        spacing: 8
                    ) {
                        ForEach(results.prefix(50)) { asset in
                            Button {
                                onOpenResult(asset)
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    ThumbnailImageView(path: asset.thumbnailPath, contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 108)
                                        .clipped()
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.72)],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )
                                    Text(asset.fileName)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .padding(7)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .prismClickable()
                        }
                    }
                }
                .frame(minHeight: 260, maxHeight: 410)
            }
        }
    }
}
