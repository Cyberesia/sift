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
    let onScanFolder: (String) -> Void
    let onSetIncludeSubfolders: (String, Bool) -> Void
    let onRescanSources: () -> Void
    let onStartAITagging: () -> Void
    let onUndoTransfer: (TransferRecord) -> Void
    let onFactoryReset: (Bool, Bool) -> Void
    @State private var jevKey = ""
    @State private var showJevHelp = false
    @State private var confirm: SiftConfirm?
    @State private var showResetChoices = false
    @State private var resetLibrary = false
    @State private var resetSettings = false
    @State private var showPageHelp = false
    @State private var jevSaved = false
    @ObservedObject private var updates = SiftUpdateCenter.shared

    public init(
        folders: [FolderBookmark],
        destinations: [DestinationBookmark],
        activeDestinationID: String?,
        transferMode: Binding<FileTransferMode>,
        watchSourceFolders: Binding<Bool>,
        recentTransfers: [TransferRecord],
        onAddFolder: @escaping () -> Void,
        onRemoveFolder: @escaping (String) -> Void,
        onScanFolder: @escaping (String) -> Void = { _ in },
        onSetIncludeSubfolders: @escaping (String, Bool) -> Void = { _, _ in },
        onRescanSources: @escaping () -> Void,
        onStartAITagging: @escaping () -> Void,
        onUndoTransfer: @escaping (TransferRecord) -> Void,
        onFactoryReset: @escaping (Bool, Bool) -> Void
    ) {
        self.folders = folders
        self.destinations = destinations
        self.activeDestinationID = activeDestinationID
        _transferMode = transferMode
        _watchSourceFolders = watchSourceFolders
        self.recentTransfers = recentTransfers
        self.onAddFolder = onAddFolder
        self.onRemoveFolder = onRemoveFolder
        self.onScanFolder = onScanFolder
        self.onSetIncludeSubfolders = onSetIncludeSubfolders
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

                    updatesSection

                    PrismSettingsSection(
                        title: "Source folders",
                        footer: "Folders on your Mac that Sift scans. Files stay in place until you Move or Copy into a destination."
                    ) {
                        FolderSourcesPanel(
                            folders: folders,
                            style: .embedded,
                            onRemove: onRemoveFolder,
                            onScan: onScanFolder,
                            onSetIncludeSubfolders: onSetIncludeSubfolders
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
                            .prismClickable()
                            .popover(isPresented: $showJevHelp) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("How Jev is used")
                                        .font(.headline)
                                    Text("With a key saved, Jev can classify an assistant command from the phrase, allowed actions, and a short catalog summary. Organization proposals can include filenames, extensions, kinds, source folders, sizes, dates, dimensions, durations, scored labels, and up to three short OCR lines. Document labeling can send opening lines, headings, sheet names, and column headers. Files, photos, video, and audio stay on this Mac. No key, or a failed answer, keeps the on-device result.")
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
                                    confirm = SiftConfirm(
                                        title: "Remove the Jev key?",
                                        message: "The key is deleted from the Keychain. Routing and document labels then stay on this Mac. You can paste a key again later.",
                                        confirmTitle: "Remove key"
                                    ) {
                                        JevCredential.save("")
                                        jevSaved = false
                                        jevKey = ""
                                    }
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
                                action: {
                                    confirm = SiftConfirm(
                                        title: "Rescan the saved folders?",
                                        message: "Sift walks the folders you already saved and updates the catalog. Files stay where they are.",
                                        confirmTitle: "Rescan",
                                        destructive: false,
                                        run: onRescanSources
                                    )
                                }
                            )
                            settingsActionButton(
                                "Start AI tagging",
                                icon: "sparkles",
                                action: {
                                    confirm = SiftConfirm(
                                        title: "Start tagging?",
                                        message: "Sift reads photos on this Mac. For documents it reads the opening, the headings, and the column names. With a Jev key, that short outline is sent once per file. The files stay where they are.",
                                        confirmTitle: "Start tagging",
                                        destructive: false,
                                        run: onStartAITagging
                                    )
                                }
                            )
                            settingsActionButton(
                                "Reset library & settings…",
                                icon: "trash",
                                action: {
                                    resetLibrary = false
                                    resetSettings = false
                                    showResetChoices = true
                                }
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
        .onAppear {
            jevSaved = JevCredential.isConfigured
            Task { await updates.checkIfNeeded() }
        }
        .siftConfirming($confirm)
        .sheet(isPresented: $showResetChoices) {
            SiftResetSheet(
                resetLibrary: $resetLibrary,
                resetSettings: $resetSettings,
                onCancel: { showResetChoices = false },
                onConfirm: {
                    let library = resetLibrary
                    let settings = resetSettings
                    showResetChoices = false
                    onFactoryReset(library, settings)
                }
            )
        }
        .sheet(isPresented: $showPageHelp) {
            SiftHelpView(mode: "settings", onClose: { showPageHelp = false })
        }
        .preferredColorScheme(.dark)
        .tint(PrismTheme.accent)
        .frame(width: 560)
        .frame(minHeight: 620, idealHeight: 700, maxHeight: 900)
        #if os(macOS)
        .background(SettingsWindowChrome())
        #endif
    }

    private var updatesSection: some View {
        PrismSettingsSection(
            title: SiftUpdateCenter.text("Updates", "Mises à jour"),
            footer: SiftUpdateCenter.text(
                "Sift asks GitHub once a day. Download the latest DMG to update. Your catalog stays on this Mac.",
                "Sift interroge GitHub une fois par jour. Téléchargez le dernier DMG pour mettre à jour. Le catalogue reste sur ce Mac."
            )
        ) {
            HStack(spacing: 10) {
                if updates.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else if updates.updateAvailable {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(PrismTheme.accent)
                } else if updates.lastError != nil && !updates.noReleaseYet {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sift \(updates.installedVersion)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PrismTheme.textPrimary)
                    Text(updates.statusText)
                        .font(.caption)
                        .foregroundStyle(PrismTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button(SiftUpdateCenter.text("Check for updates", "Rechercher des mises à jour")) {
                    Task { await updates.check(force: true) }
                }
                .buttonStyle(.bordered)
                .disabled(updates.isChecking)
                .prismClickable()

                if updates.updateAvailable {
                    Button(SiftUpdateCenter.text("Download update", "Télécharger la mise à jour")) {
                        updates.openDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PrismTheme.accent)
                    .prismClickable()
                }
            }
        }
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
                Spacer()
                Button {
                    showPageHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.bordered)
                .help("Help for settings")
                .prismClickable()
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
                Button("Undo") {
                    confirm = SiftConfirm(
                        title: "Undo this transfer?",
                        message: "Sift tries to put the file back. That only works if the file is still at the destination.",
                        confirmTitle: "Undo transfer"
                    ) {
                        onUndoTransfer(record)
                    }
                }
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
