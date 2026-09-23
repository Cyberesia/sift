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
    @State private var confirm: SiftConfirm?

    public init(
        folders: [FolderBookmark],
        style: FolderSourcesPanelStyle = .shell,
        onReplace: ((String) -> Void)? = nil,
        onRemove: @escaping (String) -> Void
    ) {
        self.folders = folders
        self.style = style
        self.onReplace = onReplace
        self.onRemove = onRemove
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
        "Sift scans these folders and lists what it finds in your library. Files stay where they are until you Move or Copy them into a destination. Removing a source clears its catalog only—not files on disk."
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
            }
            Spacer(minLength: 8)
            if let onReplace {
                Button("Change…") {
                    onReplace(folder.id)
                }
                .controlSize(.small)
                .help("Choose a replacement location and rebuild this part of the catalog")
                .prismClickable()
            }
            Button("Remove", role: .destructive) {
                confirm = SiftConfirm(
                    title: "Remove \(folder.displayName)?",
                    message: "This folder is forgotten as a source. Files already there stay on the Mac. They disappear from the catalog.",
                    confirmTitle: "Remove from catalog"
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
}
