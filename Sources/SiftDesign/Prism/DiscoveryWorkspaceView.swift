import SiftCore
import SwiftUI

public struct DiscoveryWorkspaceView: View {
    let folders: [FolderBookmark]
    let assetCount: Int
    let analyzedCount: Int
    let onScanMac: () -> Void
    let onChooseLocations: () -> Void
    let onRescan: () -> Void
    let onRescanFolder: (String) -> Void
    let onSetIncludeSubfolders: (String, Bool) -> Void
    let onReplaceFolder: (String) -> Void
    let onRemoveFolder: (String) -> Void
    let onPlanStructure: () -> Void
    let scanKinds: Set<MediaKind>
    let onToggleScanKind: (MediaKind, Bool) -> Void
    let documentExtensions: Set<String>
    let onToggleDocumentExtension: (String, Bool) -> Void
    let filingNote: String
    @State private var confirm: SiftConfirm?

    public init(
        folders: [FolderBookmark],
        assetCount: Int,
        analyzedCount: Int,
        onScanMac: @escaping () -> Void,
        onChooseLocations: @escaping () -> Void,
        onRescan: @escaping () -> Void,
        onRescanFolder: @escaping (String) -> Void = { _ in },
        onSetIncludeSubfolders: @escaping (String, Bool) -> Void = { _, _ in },
        onReplaceFolder: @escaping (String) -> Void,
        onRemoveFolder: @escaping (String) -> Void,
        onPlanStructure: @escaping () -> Void,
        scanKinds: Set<MediaKind> = Set(MediaKind.allCases),
        onToggleScanKind: @escaping (MediaKind, Bool) -> Void = { _, _ in },
        documentExtensions: Set<String> = DocumentFormats.extensions,
        onToggleDocumentExtension: @escaping (String, Bool) -> Void = { _, _ in },
        filingNote: String = ""
    ) {
        self.folders = folders
        self.assetCount = assetCount
        self.analyzedCount = analyzedCount
        self.onScanMac = onScanMac
        self.onChooseLocations = onChooseLocations
        self.onRescan = onRescan
        self.onRescanFolder = onRescanFolder
        self.onSetIncludeSubfolders = onSetIncludeSubfolders
        self.onReplaceFolder = onReplaceFolder
        self.onRemoveFolder = onRemoveFolder
        self.onPlanStructure = onPlanStructure
        self.scanKinds = scanKinds
        self.onToggleScanKind = onToggleScanKind
        self.documentExtensions = documentExtensions
        self.onToggleDocumentExtension = onToggleDocumentExtension
        self.filingNote = filingNote
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(PrismTheme.accentSoft)
                            .frame(width: 58, height: 58)
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(PrismTheme.accentGradient)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Find files on this Mac")
                            .font(.title2.weight(.bold))
                        Text("Sift makes a catalog and leaves every file where it is. Moving or copying happens later, and only after you choose.")
                            .font(.subheadline)
                            .foregroundStyle(PrismTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                scanKindRow

                HStack(spacing: 12) {
                    discoveryAction(
                        title: "Scan this Mac",
                        detail: "Home folders and connected disks. Files stay put.",
                        icon: "internaldrive",
                        prominent: true,
                        action: onScanMac
                    )
                    discoveryAction(
                        title: "Choose folders",
                        detail: "Pick the folders or disks yourself.",
                        icon: "folder.badge.plus",
                        prominent: false,
                        action: onChooseLocations
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        stat("\(assetCount)", label: "cataloged", icon: "photo.stack")
                        stat("\(analyzedCount)", label: "analyzed", icon: "sparkles")
                        stat("\(folders.count)", label: "locations", icon: "externaldrive")
                        Spacer()
                        if !folders.isEmpty {
                            Button(action: onPlanStructure) {
                                Label("Choose a home folder", systemImage: "wand.and.stars")
                            }
                            .buttonStyle(.bordered)
                            .help("Pick where organized files should go. Nothing moves yet.")
                            .prismClickable()
                        }
                    }
                }
                .padding(16)
                .prismGlass(cornerRadius: 18, padding: 0)

                VStack(alignment: .leading, spacing: 5) {
                    Text("What happens")
                        .font(.headline)
                    Text("1. Choose what to look for  ·  2. Find the files  ·  3. Later, decide whether to move or copy them")
                        .font(.caption)
                        .foregroundStyle(PrismTheme.textSecondary)
                    if !filingNote.isEmpty {
                        Text(filingNote)
                            .font(.caption)
                            .foregroundStyle(PrismTheme.textPrimary)
                            .padding(.top, 4)
                    }
                    Label("Projects, apps, caches, and system folders are skipped.", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(PrismTheme.textSecondary)
                        .padding(.top, 4)
                }

                if !folders.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Catalog locations")
                                .font(.headline)
                            Spacer()
                            Button {
                                let names = folders.map(\.displayName).joined(separator: ", ")
                                confirm = SiftConfirm(
                                    title: "Scan saved folders?",
                                    message: "Sift walks \(names) again and updates the catalog. Each folder keeps its own subfolder setting. Files stay where they are. Use this for new files, or to finish a scan you stopped.",
                                    confirmTitle: "Scan saved folders",
                                    destructive: false,
                                    run: onRescan
                                )
                            } label: {
                                Label("Scan saved folders", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .help(lookAgainHelp)
                            .prismClickable()
                        }
                        Text("These folders are already in the catalog. Scan them again here. Finder is only for adding a new place.")
                            .font(.caption)
                            .foregroundStyle(PrismTheme.textSecondary)
                        FolderSourcesPanel(
                            folders: folders,
                            onReplace: onReplaceFolder,
                            onRemove: onRemoveFolder,
                            onScan: onRescanFolder,
                            onSetIncludeSubfolders: onSetIncludeSubfolders
                        )
                    }
                }
            }
            .padding(24)
        }
        .siftConfirming($confirm)
    }

    private var lookAgainHelp: String {
        let names = folders.map(\.displayName).joined(separator: ", ")
        return "Scans the saved folders again: \(names)."
    }

    private var scanChoices: [(MediaKind, String, String)] {
        [
            (.image, "Photos", "photo"),
            (.video, "Videos", "film"),
            (.audio, "Audio", "music.note"),
            (.document, "Documents", "doc.text"),
        ]
    }

    private var scanKindRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What to look for")
                .font(.headline)
            HStack(alignment: .center, spacing: 8) {
                ForEach(scanChoices, id: \.0) { kind, title, icon in
                    let on = scanKinds.contains(kind)
                    Button {
                        onToggleScanKind(kind, !on)
                    } label: {
                        Label(title, systemImage: icon)
                            .font(.caption.weight(on ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                Capsule().fill(on ? PrismTheme.accentSoft : PrismTheme.surfaceMuted.opacity(0.8))
                            }
                            .overlay {
                                Capsule().strokeBorder(on ? PrismTheme.accent.opacity(0.7) : PrismTheme.borderSubtle, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .prismClickable()
                    if kind == .document, on {
                        documentExtensionChecks
                    }
                }
            }
            Text("\(ScanActivityCopy.lookingFor(scanKinds)) Files already in the catalog stay.")
                .font(.caption)
                .foregroundStyle(PrismTheme.textSecondary)
        }
    }

    private var documentExtensionChecks: some View {
        HStack(spacing: 10) {
            ForEach(DocumentFormats.ordered, id: \.self) { ext in
                Toggle(isOn: Binding(
                    get: { documentExtensions.contains(ext) },
                    set: { onToggleDocumentExtension(ext, $0) }
                )) {
                    Text(ext)
                        .font(.caption.monospaced())
                }
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif
                .prismClickable()
            }
        }
    }

    private func discoveryAction(
        title: String,
        detail: String,
        icon: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .opacity(0.72)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(DiscoveryActionButtonStyle(prominent: prominent))
        .prismClickable()
    }

    private func stat(_ value: String, label: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(PrismTheme.accent)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(PrismTheme.textSecondary)
        }
    }
}

private struct DiscoveryActionButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Color.white : PrismTheme.textPrimary)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        prominent
                            ? AnyShapeStyle(PrismTheme.accentGradient)
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        prominent ? PrismTheme.accent.opacity(0.8) : PrismTheme.borderStrong,
                        lineWidth: 1
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}
