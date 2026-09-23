import SwiftUI

public struct PostOrganizeSuccessSheet: View {
    let assetCount: Int
    let destinationCount: Int
    let activeDestinationName: String
    let onOpenLibrary: () -> Void
    let onOpenOrganize: () -> Void
    let onDismiss: () -> Void

    public init(
        assetCount: Int,
        destinationCount: Int,
        activeDestinationName: String,
        onOpenLibrary: @escaping () -> Void,
        onOpenOrganize: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.assetCount = assetCount
        self.destinationCount = destinationCount
        self.activeDestinationName = activeDestinationName
        self.onOpenLibrary = onOpenLibrary
        self.onOpenOrganize = onOpenOrganize
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Files found", systemImage: "checkmark.circle.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.green)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Nothing was moved or copied. Look through the catalog, or choose the folder they should go into later.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack {
                Button("Choose where they go", action: onOpenOrganize)
                    .prismClickable()
                Button("Look through them", action: onOpenLibrary)
                    .buttonStyle(.borderedProminent)
                    .prismClickable()
                Spacer()
                Button("Done", action: onDismiss)
                    .prismClickable()
            }
        }
        .padding(24)
        .frame(width: 440)
        .prismGlass(cornerRadius: 20, padding: 0)
    }

    private var summaryText: String {
        if destinationCount == 0 {
            return "\(assetCount) files are in the catalog. They are still in their original folders."
        }
        if destinationCount == 1 {
            return "\(assetCount) files are in the catalog. Nothing was moved. “\(activeDestinationName)” is only the folder you chose for later."
        }
        let active = activeDestinationName.isEmpty ? "none selected yet" : activeDestinationName
        return "\(assetCount) files are in the catalog. Nothing was moved. Home folder: \(active)."
    }
}
