import SiftCore
import SwiftUI

public struct LibraryToolbar: View {
    @Binding var viewMode: LibraryViewMode
    let assetCount: Int
    let folderCount: Int
    let onAddFolder: () -> Void
    let onOpenSources: () -> Void
    let onSearch: () -> Void
    let statusNote: String

    public init(
        viewMode: Binding<LibraryViewMode>,
        assetCount: Int,
        folderCount: Int,
        onAddFolder: @escaping () -> Void,
        onOpenSources: @escaping () -> Void,
        onSearch: @escaping () -> Void,
        statusNote: String = ""
    ) {
        _viewMode = viewMode
        self.assetCount = assetCount
        self.folderCount = folderCount
        self.onAddFolder = onAddFolder
        self.onOpenSources = onOpenSources
        self.onSearch = onSearch
        self.statusNote = statusNote
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button(action: onAddFolder) {
                Label("Add folder", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .prismClickable()

            Button(action: onOpenSources) {
                Label("Sources (\(folderCount))", systemImage: "externaldrive")
            }
            .buttonStyle(.bordered)
            .prismClickable()

            Button(action: onSearch) {
                Label("Search content", systemImage: "sparkle.magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .help("Find visible content, OCR text, people, labels, and filenames in the indexed catalog (⌘K)")
            .keyboardShortcut("k", modifiers: .command)
            .prismClickable()

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(assetCount) in the catalog")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !statusNote.isEmpty {
                    Text(statusNote)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }

            Picker("View", selection: $viewMode) {
                ForEach(LibraryViewMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 230)
            .prismClickable()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .prismGlass(cornerRadius: 16, padding: 0)
    }
}
