import SiftCore
import SwiftUI

public struct DestinationsPanel: View {
    let destinations: [DestinationBookmark]
    let activeDestinationID: String?
    let onSelect: (String) -> Void
    let onRemove: (String) -> Void
    let onAdd: () -> Void

    public init(
        destinations: [DestinationBookmark],
        activeDestinationID: String?,
        onSelect: @escaping (String) -> Void,
        onRemove: @escaping (String) -> Void,
        onAdd: @escaping () -> Void
    ) {
        self.destinations = destinations
        self.activeDestinationID = activeDestinationID
        self.onSelect = onSelect
        self.onRemove = onRemove
        self.onAdd = onAdd
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Destinations")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button("Add destination…", action: onAdd)
                    .font(.caption.weight(.semibold))
                    .prismClickable()
            }

            if destinations.isEmpty {
                Text("Add the folder files should go inside.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(destinations) { dest in
                    destinationRow(dest)
                }
            }

            Text("The selected folder is where files go. They are placed inside it, not next to it.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .prismGlass(cornerRadius: 16, padding: 0)
    }

    private func destinationRow(_ dest: DestinationBookmark) -> some View {
        let isActive = dest.id == activeDestinationID
        return HStack(spacing: 10) {
            Button {
                onSelect(dest.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isActive ? PrismTheme.accent : .secondary)
                    Image(systemName: "externaldrive.fill")
                        .foregroundStyle(PrismTheme.accent.opacity(0.8))
                    Text(dest.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .prismClickable()

            Button("Remove", role: .destructive) {
                onRemove(dest.id)
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .prismClickable()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? PrismTheme.accentSoft : PrismTheme.surfaceMuted.opacity(0.8))
        )
    }
}
