import SiftCore
import SwiftUI

public struct LibraryBrowseBar: View {
    @Binding var browseScope: LibraryBrowseScope
    @Binding var librarySort: LibraryAssetSort
    @Binding var kindFilter: LibraryKindFilter
    let folderSources: [FolderBookmark]
    let subfolderOptions: [LibraryBrowseFilter.SubfolderOption]
    let filteredCount: Int

    public init(
        browseScope: Binding<LibraryBrowseScope>,
        librarySort: Binding<LibraryAssetSort>,
        kindFilter: Binding<LibraryKindFilter> = .constant(.all),
        folderSources: [FolderBookmark],
        subfolderOptions: [LibraryBrowseFilter.SubfolderOption],
        filteredCount: Int
    ) {
        _browseScope = browseScope
        _librarySort = librarySort
        _kindFilter = kindFilter
        self.folderSources = folderSources
        self.subfolderOptions = subfolderOptions
        self.filteredCount = filteredCount
    }

    public var body: some View {
        HStack(spacing: 10) {
            sourceMenu
            if case .source = browseScope, subfolderOptions.count > 1 {
                subfolderMenu
            }
            sortMenu
            kindMenu
            Spacer()
            Text("\(filteredCount) shown")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PrismTheme.surfaceMuted.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(PrismTheme.borderSubtle, lineWidth: 1)
                )
        )
    }

    private var sourceMenu: some View {
        Menu {
            Button("Entire Mac") {
                browseScope = .entireCatalog
            }
            Button("All folders") {
                browseScope = .allSources
            }
            Button("Inbox (at source)") {
                browseScope = .inbox
            }
            if !folderSources.isEmpty {
                Divider()
                ForEach(folderSources) { bookmark in
                    Button {
                        browseScope = .source(bookmarkID: bookmark.id, subfolder: nil)
                    } label: {
                        Text(bookmark.displayName)
                    }
                }
            }
        } label: {
            Label(sourceTitle, systemImage: "folder")
                .font(.caption.weight(.semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .prismClickable()
    }

    private var subfolderMenu: some View {
        Menu {
            ForEach(subfolderOptions) { option in
                Button {
                    if case .source(let id, _) = browseScope {
                        let path = option.relativePath.isEmpty ? nil : option.relativePath
                        browseScope = .source(bookmarkID: id, subfolder: path)
                    }
                } label: {
                    Text("\(option.title) (\(option.assetCount))")
                }
            }
        } label: {
            Label(subfolderTitle, systemImage: "folder.badge.gearshape")
                .font(.caption.weight(.semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .prismClickable()
    }

    private var sortMenu: some View {
        Menu {
            ForEach(LibraryAssetSort.allCases, id: \.self) { sort in
                Button {
                    librarySort = sort
                } label: {
                    if librarySort == sort {
                        Label(sort.displayName, systemImage: "checkmark")
                    } else {
                        Text(sort.displayName)
                    }
                }
            }
        } label: {
            Label(librarySort.displayName, systemImage: "arrow.up.arrow.down")
                .font(.caption.weight(.semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .prismClickable()
    }

    private var kindMenu: some View {
        Menu {
            ForEach(LibraryKindFilter.allCases, id: \.self) { filter in
                Button {
                    kindFilter = filter
                } label: {
                    if kindFilter == filter {
                        Label(filter.displayName, systemImage: "checkmark")
                    } else {
                        Text(filter.displayName)
                    }
                }
            }
        } label: {
            Label(kindFilter.displayName, systemImage: "line.3.horizontal.decrease")
                .font(.caption.weight(.semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .prismClickable()
    }

    private var sourceTitle: String {
        switch browseScope {
        case .allSources: "All folders"
        case .entireCatalog: "Entire Mac"
        case .inbox: "Inbox"
        case .source(let id, _):
            folderSources.first(where: { $0.id == id })?.displayName ?? "Folder"
        }
    }

    private var subfolderTitle: String {
        guard case .source(_, let sub) = browseScope else { return "Subfolder" }
        if let sub, !sub.isEmpty { return sub }
        return "All in source"
    }
}
