import SiftCore
import SwiftUI

public struct DestinationWizard: View {
    let destinations: [DestinationBookmark]
    let activeDestinationID: String?
    let onAddDestination: () -> Void
    let onSelectDestination: (String) -> Void
    let onRemoveDestination: (String) -> Void
    let onCancel: () -> Void
    let onDone: () -> Void

    public init(
        destinations: [DestinationBookmark],
        activeDestinationID: String?,
        onAddDestination: @escaping () -> Void,
        onSelectDestination: @escaping (String) -> Void,
        onRemoveDestination: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.destinations = destinations
        self.activeDestinationID = activeDestinationID
        self.onAddDestination = onAddDestination
        self.onSelectDestination = onSelectDestination
        self.onRemoveDestination = onRemoveDestination
        self.onCancel = onCancel
        self.onDone = onDone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a home folder")
                .font(.title3.weight(.semibold))
            Text("Pick the folder files should go inside. Nothing is moved or copied here. You choose move or copy on the next step.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            DestinationsPanel(
                destinations: destinations,
                activeDestinationID: activeDestinationID,
                onSelect: onSelectDestination,
                onRemove: onRemoveDestination,
                onAdd: onAddDestination
            )

            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                    .prismClickable()
                Spacer()
                Button("Add folder…", action: onAddDestination)
                    .prismClickable()
                Button("Done") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .prismClickable()
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .frame(minHeight: 420)
        .prismGlass(cornerRadius: 20, padding: 0)
    }
}
