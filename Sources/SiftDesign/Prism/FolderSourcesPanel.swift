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
    @State private var confirm: SiftConfirm?

    public init(
        folders: [FolderBookmark],
        style: FolderSourcesPanelStyle = .shell,
        onReplace: ((String) -> Void)? = nil,
        onRemove: @escaping (String) -> Void,
        onScan: ((String) -> Void)? = nil,
        onSetIncludeSubfolders: ((String, Bool) -> Void)? = nil
    ) {
        self.folders = folders
        self.style = style
        self.onReplace = onReplace
        self.onRemove = onRemove
        self.onScan = onScan
        self.onSetIncludeSubfolders = onSetIncludeSubfolders
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
                    folderRow(folder)
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

    private static func copy(_ en: String, _ fr: String) -> String {
        Locale.current.language.languageCode?.identifier == "fr" ? fr : en
    }
}
