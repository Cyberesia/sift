import SiftCore
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// macOS Settings window — matches Prism shell (dark, glass sections).
public struct PrismSettingsView: View {
    let folders: [FolderBookmark]
    let destinations: [DestinationBookmark]
    let activeDestinationID: String?
    @Binding var transferMode: FileTransferMode
    @Binding var watchSourceFolders: Bool
    let recentTransfers: [TransferRecord]
    let onAddFolder: () -> Void
    let onRemoveFolder: (String) -> Void
    let onRescanSources: () -> Void
    let onStartAITagging: () -> Void
    let onUndoTransfer: (TransferRecord) -> Void
    let onFactoryReset: () -> Void
    @State private var jevKey = ""
    @State private var showJevHelp = false
    @State private var jevSaved = false

    public init(
        folders: [FolderBookmark],
        destinations: [DestinationBookmark],
        activeDestinationID: String?,
        transferMode: Binding<FileTransferMode>,
        watchSourceFolders: Binding<Bool>,
        recentTransfers: [TransferRecord],
        onAddFolder: @escaping () -> Void,
        onRemoveFolder: @escaping (String) -> Void,
        onRescanSources: @escaping () -> Void,
        onStartAITagging: @escaping () -> Void,
        onUndoTransfer: @escaping (TransferRecord) -> Void,
        onFactoryReset: @escaping () -> Void
    ) {
        self.folders = folders
        self.destinations = destinations
        self.activeDestinationID = activeDestinationID
        _transferMode = transferMode
        _watchSourceFolders = watchSourceFolders
        self.recentTransfers = recentTransfers
        self.onAddFolder = onAddFolder
        self.onRemoveFolder = onRemoveFolder
        self.onRescanSources = onRescanSources
        self.onStartAITagging = onStartAITagging
        self.onUndoTransfer = onUndoTransfer
        self.onFactoryReset = onFactoryReset
    }

    public var body: some View {
        ZStack {
            PrismTheme.dominantGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    PrismSettingsSection(
                        title: "Source folders",
                        footer: "Folders on your Mac that Sift scans. Files stay in place until you Move or Copy into a destination."
                    ) {
                        FolderSourcesPanel(
                            folders: folders,
                            style: .embedded,
                            onRemove: onRemoveFolder
                        )

                        Button(action: onAddFolder) {
                            Label("Add folder…", systemImage: "folder.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PrismTheme.accent)
                        .prismClickable()
                    }

                    PrismSettingsSection(
                        title: "Destinations",
                        footer: "Move or Copy sends files into Photos, Videos, and Gather under the active destination. Manage destinations in Organize."
                    ) {
                        destinationsContent
                    }

                    PrismSettingsSection(
                        title: "Jev intelligence",
                        footer: JevClient.disclosure
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("TypeSafe System One")
                                    .font(.subheadline.weight(.semibold))
                                Text("Jev makes bounded choices for routing, review priority, and organization proposals. It does not upload media or replace CLIP.")
                                    .font(.caption)
                                    .foregroundStyle(PrismTheme.textSecondary)
                            }
                            Spacer()
                            Button {
                                showJevHelp.toggle()
                            } label: {
                                Label("Why?", systemImage: "questionmark.circle")
                            }
                            .buttonStyle(.bordered)
                            .popover(isPresented: $showJevHelp) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("How Jev is used")
                                        .font(.headline)
                                    Text("With a key saved, Return in search can ask Jev which screen to open, or which of a short list fits best. A document is described by tags for its type, such as spreadsheet, multi-sheet, slides, or meeting. An organization preview can ask which existing folder fits a small group. The query, filenames, and those tags go out. Photos, videos, audio, document text, and the files never do. If Jev is unsure, or no key is saved, Sift keeps the local result.")
                                    Text("Create or copy an API key from your TypeSafe account, paste it below, then choose Save to Keychain.")
                                    Link("Open TypeSafe documentation", destination: URL(string: "https://docs.typesafe.ai")!)
                                }
                                .font(.caption)
                                .padding(16)
                                .frame(width: 340)
                            }
                        }

                        HStack {
                            SecureField(jevSaved ? "Replace stored API key…" : "Paste TYPESAFE_API_KEY…", text: $jevKey)
                                .textFieldStyle(.roundedBorder)
                            Button("Save to Keychain") {
                                JevCredential.save(jevKey)
                                jevSaved = JevCredential.isConfigured
                                jevKey = ""
                            }
                            .disabled(jevKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            if jevSaved {
                                Button("Remove") {
                                    JevCredential.save("")
                                    jevSaved = false
                                    jevKey = ""
                                }
                            }
                        }
                        Label(
                            jevSaved ? "Configured · model jev-latest · credential stored in macOS Keychain" : "Not configured · local catalog and Vision search still work",
                            systemImage: jevSaved ? "checkmark.shield.fill" : "key.slash"
                        )
                        .font(.caption)
                        .foregroundStyle(jevSaved ? .green : PrismTheme.textTertiary)
                    }

                    PrismSettingsSection(
                        title: "Visual content search",
                        footer: "The search window is always available. Exact files, OCR, people, and on-device Vision labels work without CLIP."
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Local CLIP model")
                                    .font(.subheadline.weight(.semibold))
                                Text(
                                    ClipEmbeddingStore.status == .ready
                                        ? "Model files are on this Mac. Visual search can run locally."
                                        : "The model downloads the first time Sift opens. Until then, searches such as “cat” use Vision labels and filenames."
                                )
                                .font(.caption)
                                .foregroundStyle(PrismTheme.textSecondary)
                            }
                            Spacer()
                            Label(
                                ClipEmbeddingStore.status == .ready ? "Ready" : "Unavailable",
                                systemImage: ClipEmbeddingStore.status == .ready ? "checkmark.circle.fill" : "exclamationmark.triangle"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ClipEmbeddingStore.status == .ready ? .green : .orange)
                        }
                    }

                    PrismSettingsSection(
                        title: "Automation",
                        footer: "When enabled, new files in source folders are indexed automatically."
                    ) {
                        Toggle("Watch source folders", isOn: $watchSourceFolders)
                            .font(.subheadline)
                            .foregroundStyle(PrismTheme.textPrimary)
                    }

                    PrismSettingsSection(
                        title: "Organizing files",
                        footer: nil
                    ) {
                        TransferModePicker(mode: $transferMode, style: .prism)
                    }

                    PrismSettingsSection(
                        title: "Recent transfers",
                        footer: "Undo moves while the file still exists at the destination."
                    ) {
                        if recentTransfers.isEmpty {
                            Text("No transfers yet.")
                                .font(.caption)
                                .foregroundStyle(PrismTheme.textTertiary)
                        } else {
                            ForEach(recentTransfers, id: \.id) { record in
                                transferRow(record)
                            }
                        }
                    }

                    PrismSettingsSection(
                        title: "Maintenance",
                        footer: nil
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            settingsActionButton(
                                "Rescan all source folders",
                                icon: "arrow.clockwise",
                                action: onRescanSources
                            )
                            settingsActionButton(
                                "Start AI tagging",
                                icon: "sparkles",
                                action: onStartAITagging
                            )
                            settingsActionButton(
                                "Reset library & settings…",
                                icon: "trash",
                                action: onFactoryReset
                            )
                        }
                    }

                    PrismSettingsSection(
                        title: "Privacy",
                        footer: "Your library and Vision models never leave this Mac."
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            privacyRow("All processing is on-device", icon: "lock.shield.fill")
                            privacyRow("No network required", icon: "airplane")
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
        }
        .onAppear { jevSaved = JevCredential.isConfigured }
        .preferredColorScheme(.dark)
        .tint(PrismTheme.accent)
        .frame(width: 560)
        .frame(minHeight: 620, idealHeight: 700, maxHeight: 900)
        #if os(macOS)
        .background(SettingsWindowChrome())
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "camera.aperture")
                    .font(.title2)
                    .foregroundStyle(PrismTheme.accentGradient)
                Text("Sift")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PrismTheme.textPrimary)
            }
            Text("Sources, destinations, and how files are organized.")
                .font(.subheadline)
                .foregroundStyle(PrismTheme.textSecondary)
        }
    }

    @ViewBuilder
    private var destinationsContent: some View {
        if destinations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("No destination yet")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PrismTheme.textPrimary)
                Text("Open Organize and add a folder where Photos, Videos, and Gather should live.")
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sectionInnerBackground)
        } else {
            VStack(spacing: 8) {
                ForEach(destinations) { dest in
                    destinationRow(dest)
                }
            }
        }
    }

    private func destinationRow(_ dest: DestinationBookmark) -> some View {
        let isActive = dest.id == activeDestinationID
        return HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(isActive ? PrismTheme.accent : PrismTheme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(dest.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PrismTheme.textPrimary)
                    .lineLimit(2)
                if isActive {
                    Text("Active destination")
                        .font(.caption)
                        .foregroundStyle(PrismTheme.accent)
                }
            }
            Spacer(minLength: 0)
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(PrismTheme.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(sectionInnerBackground)
    }

    private var sectionInnerBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(PrismTheme.surfaceMuted.opacity(0.5))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(PrismTheme.borderSubtle, lineWidth: 1)
            }
    }

    private func settingsActionButton(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PrismTheme.textTertiary)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PrismTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sectionInnerBackground)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .prismClickable()
    }

    private func transferRow(_ record: TransferRecord) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text((record.destinationPath as NSString).lastPathComponent)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(record.sourcePath)
                    .font(.caption2)
                    .foregroundStyle(PrismTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            if !record.isUndone {
                Button("Undo") { onUndoTransfer(record) }
                    .font(.caption.weight(.semibold))
                    .prismClickable()
            } else {
                Text("Undone")
                    .font(.caption2)
                    .foregroundStyle(PrismTheme.textTertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private func privacyRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(PrismTheme.accent)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(PrismTheme.textSecondary)
        }
    }
}

// MARK: - Section chrome

struct PrismSettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(PrismTheme.textPrimary)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .prismGlass(cornerRadius: 20, padding: 0)

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if os(macOS)
/// Forces Settings window to dark chrome so the white system sheet does not bleed through.
private struct SettingsWindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { applyChrome(from: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { applyChrome(from: nsView) }
    }

    private func applyChrome(from view: NSView) {
        guard let window = view.window else { return }
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(
            red: 0.06,
            green: 0.055,
            blue: 0.08,
            alpha: 1
        )
        window.titlebarAppearsTransparent = true
        window.isOpaque = true
    }
}
#endif
