import SiftCore
import SwiftUI

public enum FolderSourcesPanelStyle {
    /// Dark glass card inside the main Prism shell.
    case shell
    /// Plain grouped content for the macOS Settings window.
    case settings
    /// Inside another glass section (no nested card).
    case embedded
}

public struct FolderSourcesPanel: View {
    let folders: [FolderBookmark]
    let style: FolderSourcesPanelStyle
    let onReplace: ((String) -> Void)?
    let onRemove: (String) -> Void
    let onScan: ((String) -> Void)?
    let onSetIncludeSubfolders: ((String, Bool) -> Void)?
    let compositions: [String: CatalogComposition]
    let onDecide: ((CatalogSlice) -> Void)?
    @State private var confirm: SiftConfirm?
    @State private var expanded: Set<String> = []
    @State private var excluded: [String: Set<String>] = [:]

    public init(
        folders: [FolderBookmark],
        style: FolderSourcesPanelStyle = .shell,
        onReplace: ((String) -> Void)? = nil,
        onRemove: @escaping (String) -> Void,
        onScan: ((String) -> Void)? = nil,
        onSetIncludeSubfolders: ((String, Bool) -> Void)? = nil,
        compositions: [String: CatalogComposition] = [:],
        onDecide: ((CatalogSlice) -> Void)? = nil
    ) {
        self.folders = folders
        self.style = style
        self.onReplace = onReplace
        self.onRemove = onRemove
        self.onScan = onScan
        self.onSetIncludeSubfolders = onSetIncludeSubfolders
        self.compositions = compositions
        self.onDecide = onDecide
    }

    public var body: some View {
        Group {
            switch style {
            case .shell: shellBody
            case .settings: settingsBody
            case .embedded: embeddedBody
            }
        }
        .siftConfirming($confirm)
    }

    private var shellBody: some View {
        panelContent
            .padding(16)
            .prismGlass(cornerRadius: 20, padding: 0)
    }

    private var settingsBody: some View {
        panelContent
    }

    private var embeddedBody: some View {
        panelContent
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if style == .shell {
                Text("Source folders")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            if folders.isEmpty {
                Text("No source folders yet.")
                    .font(style == .settings ? .body : .subheadline)
                    .foregroundStyle(
                        style == .settings ? AnyShapeStyle(.secondary) : AnyShapeStyle(PrismTheme.textTertiary)
                    )
            } else {
                ForEach(folders) { folder in
                    VStack(alignment: .leading, spacing: 0) {
                        folderRow(folder)
                        if style == .shell, let composition = compositions[folder.displayName], composition.total > 0 {
                            compositionSection(folder: folder, composition: composition)
                        }
                    }
                }
            }

            if style == .shell {
                Text(footerCopy)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footerCopy: String {
        Self.copy(
            "Sift scans these folders and lists what it finds. Files stay where they are until you Move or Copy them. Forget folder only removes the folder from this list.",
            "Sift scanne ces dossiers et liste ce qu’il trouve. Les fichiers restent où ils sont jusqu’à un Move ou un Copy. Oublier le dossier ne retire le dossier que de cette liste."
        )
    }

    @ViewBuilder
    private func folderRow(_ folder: FolderBookmark) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "folder.fill")
                .foregroundStyle(style == .settings ? Color.accentColor : PrismTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(style == .settings ? .body : .subheadline)
                    .foregroundStyle(style == .settings ? AnyShapeStyle(.primary) : AnyShapeStyle(PrismTheme.textPrimary))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(folder.includeSubfolders ? "Includes subfolders" : "This folder only")
                    .font(.caption)
                    .foregroundStyle(style == .settings ? AnyShapeStyle(.secondary) : AnyShapeStyle(PrismTheme.textTertiary))
                if onSetIncludeSubfolders != nil {
                    Toggle(isOn: Binding(
                        get: { folder.includeSubfolders },
                        set: { onSetIncludeSubfolders?(folder.id, $0) }
                    )) {
                        Text(Self.copy("Include subfolders", "Inclure les sous-dossiers"))
                            .font(.caption)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help(Self.copy(
                        "Off scans only the files in this folder. The next scan of this folder drops nested files from the catalog. Nothing is deleted from the Mac.",
                        "Désactivé, seul ce dossier est scanné. Le prochain scan retire les fichiers des sous-dossiers du catalogue. Rien n’est effacé du Mac."
                    ))
                    .prismClickable()
                }
            }
            Spacer(minLength: 8)
            if style == .shell, let onDecide, let composition = compositions[folder.displayName], composition.total > 0 {
                Button {
                    onDecide(CatalogSlice(
                        sourceLabel: folder.displayName,
                        excludedExtensions: excluded[folder.id] ?? []
                    ))
                } label: {
                    Label(Self.copy("Organize this catalog", "Organiser ce catalogue"), systemImage: "bubble.left.and.text.bubble.right")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(Self.copy(
                    "Opens the assistant for the \(composition.total) files already cataloged here. Nothing moves.",
                    "Ouvre l’assistant pour les \(composition.total) fichiers déjà catalogués ici. Rien ne bouge."
                ))
                .prismClickable()
            }
            if let onScan {
                Button(Self.copy("Scan again", "Scanner à nouveau")) {
                    confirm = SiftConfirm(
                        title: Self.copy("Scan \(folder.displayName) again?", "Scanner \(folder.displayName) à nouveau ?"),
                        message: Self.copy(
                            folder.includeSubfolders
                                ? "Sift walks this folder and its subfolders and updates the catalog. Files stay where they are. Use this after new files appear, or to finish a scan you stopped."
                                : "Sift walks only the files in this folder, not its subfolders, and updates the catalog. Nested files leave the catalog. Nothing is deleted from the Mac.",
                            folder.includeSubfolders
                                ? "Sift parcourt ce dossier et ses sous-dossiers et met le catalogue à jour. Les fichiers restent où ils sont. Utile après de nouveaux fichiers, ou pour finir un scan interrompu."
                                : "Sift ne parcourt que les fichiers de ce dossier, pas les sous-dossiers, et met le catalogue à jour. Les fichiers imbriqués quittent le catalogue. Rien n’est effacé du Mac."
                        ),
                        confirmTitle: Self.copy("Scan again", "Scanner à nouveau"),
                        destructive: false
                    ) {
                        onScan(folder.id)
                    }
                }
                .controlSize(.small)
                .help(Self.copy(
                    "Scan this saved folder again for new files, or to finish a scan you stopped.",
                    "Rescanne ce dossier enregistré pour les nouveaux fichiers, ou pour finir un scan interrompu."
                ))
                .prismClickable()
            }
            if let onReplace {
                Button("Change…") {
                    onReplace(folder.id)
                }
                .controlSize(.small)
                .help("Choose a replacement location and rebuild this part of the catalog")
                .prismClickable()
            }
            Button(Self.copy("Forget folder", "Oublier le dossier"), role: .destructive) {
                confirm = SiftConfirm(
                    title: Self.copy("Forget \(folder.displayName)?", "Oublier \(folder.displayName) ?"),
                    message: Self.copy(
                        "Sift stops listing this folder. The files stay in the folder. Nothing is moved, copied, or deleted.",
                        "Sift arrête de lister ce dossier. Les fichiers restent dans le dossier. Rien n’est déplacé, copié ou supprimé."
                    ),
                    confirmTitle: Self.copy("Forget folder", "Oublier le dossier"),
                    destructive: false
                ) {
                    onRemove(folder.id)
                }
            }
            .controlSize(.small)
            .prismClickable()
        }
        .padding(.horizontal, style == .settings ? 0 : 12)
        .padding(.vertical, style == .settings ? 6 : 8)
        .background {
            if style == .shell || style == .embedded {
                RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06))
            }
        }
    }

    @ViewBuilder
    private func compositionSection(folder: FolderBookmark, composition: CatalogComposition) -> some View {
        let open = expanded.contains(folder.id)
        let out = excluded[folder.id] ?? []
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if open { expanded.remove(folder.id) } else { expanded.insert(folder.id) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: open ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.bold))
                    Text(Self.copy(
                        "In the catalog: \(composition.total) files · \(composition.extensions.count) types",
                        "Au catalogue : \(composition.total) fichiers · \(composition.extensions.count) types"
                    ))
                    .font(.caption.weight(.medium))
                    if composition.unanalyzed > 0 {
                        Text(Self.copy("\(composition.unanalyzed) not analyzed yet", "\(composition.unanalyzed) pas encore analysés"))
                            .font(.caption2)
                            .foregroundStyle(PrismTheme.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(PrismTheme.textSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .prismClickable()

            if open {
                FlowLayout(spacing: 6) {
                    ForEach(composition.extensions) { item in
                        let on = !out.contains(item.fileExtension)
                        Button {
                            var next = out
                            if on { next.insert(item.fileExtension) } else { next.remove(item.fileExtension) }
                            excluded[folder.id] = next
                        } label: {
                            HStack(spacing: 4) {
                                Text(item.fileExtension.isEmpty ? Self.copy("no ext.", "sans ext.") : item.fileExtension)
                                    .font(.caption.monospaced().weight(.semibold))
                                Text("\(item.count)")
                                    .font(.caption2.monospacedDigit())
                                    .opacity(0.75)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(on ? PrismTheme.accentSoft : Color.white.opacity(0.05)))
                            .overlay(Capsule().strokeBorder(on ? PrismTheme.accent.opacity(0.6) : PrismTheme.borderSubtle, lineWidth: 1))
                            .foregroundStyle(on ? PrismTheme.textPrimary : PrismTheme.textTertiary)
                            .strikethrough(!on)
                        }
                        .buttonStyle(.plain)
                        .help(Self.copy(
                            on ? "Leave .\(item.fileExtension) out of the decision" : "Put .\(item.fileExtension) back in",
                            on ? "Écarter .\(item.fileExtension) de la décision" : "Remettre .\(item.fileExtension)"
                        ))
                        .prismClickable()
                    }
                }
                HStack {
                    Text(periodCaption(composition))
                        .font(.caption2)
                        .foregroundStyle(PrismTheme.textTertiary)
                    Spacer()
                    if let onDecide {
                        let kept = composition.extensions.filter { !out.contains($0.fileExtension) }
                        Button {
                            onDecide(CatalogSlice(sourceLabel: folder.displayName, excludedExtensions: out))
                        } label: {
                            Label(
                                Self.copy("Open assistant for this selection", "Ouvrir l’assistant pour cette sélection"),
                                systemImage: "bubble.left.and.text.bubble.right"
                            )
                            .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(kept.isEmpty)
                        .help(Self.copy("Opens the assistant with these files. Nothing moves.", "Ouvre l’assistant avec ces fichiers. Rien ne bouge."))
                        .prismClickable()
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func periodCaption(_ composition: CatalogComposition) -> String {
        let size = ByteCountFormatter.string(fromByteCount: composition.totalBytes, countStyle: .file)
        guard let earliest = composition.earliest, let latest = composition.latest else { return size }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(size) · \(formatter.string(from: earliest)) – \(formatter.string(from: latest))"
    }

    private static func copy(_ en: String, _ fr: String) -> String {
        Locale.current.language.languageCode?.identifier == "fr" ? fr : en
    }
}
