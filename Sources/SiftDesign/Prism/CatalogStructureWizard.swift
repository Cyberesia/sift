import SiftCore
import SwiftUI

public struct CatalogStructureWizard: View {
    let activeDestinationName: String
    let destinationPath: String
    @Binding var selectedFolders: Set<String>
    let onChooseDestination: () -> Void
    let onCreateStructure: () -> Void
    let onClose: () -> Void
    @State private var confirm: SiftConfirm?

    public init(
        activeDestinationName: String,
        destinationPath: String = "",
        selectedFolders: Binding<Set<String>>,
        onChooseDestination: @escaping () -> Void,
        onCreateStructure: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.activeDestinationName = activeDestinationName
        self.destinationPath = destinationPath
        _selectedFolders = selectedFolders
        self.onChooseDestination = onChooseDestination
        self.onCreateStructure = onCreateStructure
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Folders inside the destination", systemImage: "wand.and.stars")
                .font(.title2.weight(.semibold))
                .foregroundStyle(PrismTheme.textPrimary)

            Text("Turn on the folders you want. Sift creates only those empty folders inside the destination. No file is moved or copied in this step.")
                .font(.subheadline)
                .foregroundStyle(PrismTheme.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(FileTransferCoordinator.suggestedCatalogFolders, id: \.self) { folder in
                    let on = selectedFolders.contains(folder)
                    Button {
                        if on {
                            selectedFolders.remove(folder)
                        } else {
                            selectedFolders.insert(folder)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? PrismTheme.accent : PrismTheme.textTertiary)
                            Label(folder, systemImage: icon(for: folder))
                                .font(.subheadline.weight(.medium))
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(on ? PrismTheme.accentSoft : Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                    .prismClickable()
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Destination")
                        .font(.caption.weight(.semibold))
                    Text(destinationCaption)
                        .font(.caption)
                        .foregroundStyle(activeDestinationName.isEmpty ? .orange : PrismTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Button(activeDestinationName.isEmpty ? "Choose folder…" : "Change folder…", action: onChooseDestination)
                    .buttonStyle(.bordered)
                    .prismClickable()
            }
            .padding(12)
            .background(PrismTheme.surfaceMuted.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Button("Not now", action: onClose)
                    .prismClickable()
                Spacer()
                Button("Create the selected folders") {
                    let names = selectedFolders.sorted().joined(separator: ", ")
                    confirm = SiftConfirm(
                        title: "Create these folders?",
                        message: names.isEmpty
                            ? "No folder is selected."
                            : "Empty folders are created inside \(activeDestinationName): \(names). No file is moved.",
                        confirmTitle: "Create folders",
                        destructive: false,
                        run: onCreateStructure
                    )
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(activeDestinationName.isEmpty || selectedFolders.isEmpty)
                    .prismClickable()
            }
        }
        .padding(24)
        .frame(width: 570)
        .background(PrismTheme.dominantGradient)
        .siftConfirming($confirm)
    }

    private var destinationCaption: String {
        if activeDestinationName.isEmpty { return "Not chosen yet" }
        if destinationPath.isEmpty { return "Inside “\(activeDestinationName)”" }
        return "Inside “\(activeDestinationName)” — \(destinationPath)"
    }

    private func icon(for folder: String) -> String {
        if folder == "Photos" { return "photo" }
        if folder == "Videos" { return "film" }
        if folder == "Music & Audio" { return "waveform" }
        if folder == "Screenshots & Documents" { return "doc.richtext" }
        if folder == "Duplicates" { return "square.on.square" }
        return "questionmark.folder"
    }
}
