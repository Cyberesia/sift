import SiftCore
import SwiftUI

public struct ReorganizeWorkspaceView: View {
    @Binding var transferMode: FileTransferMode
    let destinations: [DestinationBookmark]
    let activeDestinationID: String?
    let activeDestinationName: String
    let pendingCount: Int
    let hasSelectedAsset: Bool
    let batchSelectionCount: Int
    let ruleSuggestions: [OrganizeRuleSuggestion]
    let onSelectDestination: (String) -> Void
    let onRemoveDestination: (String) -> Void
    let onAddDestination: () -> Void
    let onMoveToPhotos: () -> Void
    let onMoveToVideos: () -> Void
    let onMoveToGather: () -> Void
    let onStartDiscover: () -> Void
    let planItems: [OrganizePlanItem]
    let onPreviewPlan: () -> Void
    let onApproveSafe: () -> Void
    let destinationPath: String
    let filingNote: String
    let transferChoiceConfirmed: Bool

    public init(
        transferMode: Binding<FileTransferMode>,
        destinations: [DestinationBookmark],
        activeDestinationID: String?,
        activeDestinationName: String,
        pendingCount: Int,
        hasSelectedAsset: Bool,
        batchSelectionCount: Int = 0,
        ruleSuggestions: [OrganizeRuleSuggestion] = [],
        onSelectDestination: @escaping (String) -> Void,
        onRemoveDestination: @escaping (String) -> Void,
        onAddDestination: @escaping () -> Void,
        onMoveToPhotos: @escaping () -> Void,
        onMoveToVideos: @escaping () -> Void,
        onMoveToGather: @escaping () -> Void,
        onStartDiscover: @escaping () -> Void,
        planItems: [OrganizePlanItem] = [],
        onPreviewPlan: @escaping () -> Void = {},
        onApproveSafe: @escaping () -> Void = {},
        destinationPath: String = "",
        filingNote: String = "",
        transferChoiceConfirmed: Bool = false
    ) {
        _transferMode = transferMode
        self.destinations = destinations
        self.activeDestinationID = activeDestinationID
        self.activeDestinationName = activeDestinationName
        self.pendingCount = pendingCount
        self.hasSelectedAsset = hasSelectedAsset
        self.batchSelectionCount = batchSelectionCount
        self.ruleSuggestions = ruleSuggestions
        self.onSelectDestination = onSelectDestination
        self.onRemoveDestination = onRemoveDestination
        self.onAddDestination = onAddDestination
        self.onMoveToPhotos = onMoveToPhotos
        self.onMoveToVideos = onMoveToVideos
        self.onMoveToGather = onMoveToGather
        self.onStartDiscover = onStartDiscover
        self.planItems = planItems
        self.onPreviewPlan = onPreviewPlan
        self.onApproveSafe = onApproveSafe
        self.destinationPath = destinationPath
        self.filingNote = filingNote
        self.transferChoiceConfirmed = transferChoiceConfirmed
    }

    private var canTransfer: Bool {
        activeDestinationID != nil && (hasSelectedAsset || batchSelectionCount > 0)
    }

    private var selectionLabel: String {
        if batchSelectionCount > 0 {
            return "\(batchSelectionCount) selected in Library (⌘-click)"
        }
        if hasSelectedAsset {
            return "1 item selected"
        }
        return "Select items in Library (⌘-click) or pick one asset"
    }

    private var readyCount: Int {
        planItems.filter { !$0.blocked }.count
    }

    private var heldCount: Int {
        planItems.filter(\.blocked).count
    }

    private var approveTitle: String {
        let name = activeDestinationName.isEmpty ? "the folder" : activeDestinationName
        guard transferChoiceConfirmed else { return "Choose move or copy first" }
        guard readyCount > 0 else { return "Nothing new to file" }
        switch transferMode {
        case .move:
            return "Move \(readyCount) files into \(name)"
        case .copy:
            return "Copy \(readyCount) files into \(name)"
        case .copyThenConfirmDelete:
            return "Copy \(readyCount) files into \(name), then ask"
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Organize")
                        .font(.title2.weight(.semibold))
                    Text("Three steps. Nothing is moved or copied until you press the button at the end.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                stepHeader("1", "Where should the files go?")
                DestinationsPanel(
                    destinations: destinations,
                    activeDestinationID: activeDestinationID,
                    onSelect: onSelectDestination,
                    onRemove: onRemoveDestination,
                    onAdd: onAddDestination
                )
                if activeDestinationName.isEmpty {
                    Text("Add a folder. Files will go inside it, not in the folder above.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text(destinationPath.isEmpty
                         ? "Inside “\(activeDestinationName)”."
                         : "Inside “\(activeDestinationName)” — \(destinationPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                stepHeader("2", "What should happen to the originals?")
                Text(transferChoiceConfirmed
                     ? transferMode.stepDetail
                     : "Pick one. Copy is not assumed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(FileTransferMode.allCases) { option in
                        transferChoice(option)
                    }
                }

                stepHeader("3", "Review, then file")
                if !filingNote.isEmpty {
                    Text(filingNote)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(planItems.isEmpty
                     ? "Review the list before anything changes."
                     : "\(readyCount) waiting · \(heldCount) left as they are.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !ruleSuggestions.isEmpty {
                    Text("\(ruleSuggestions.count) inbox items match a rule you already saved.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 10) {
                    Button("Review the list", action: onPreviewPlan)
                        .prismClickable()
                    Button(approveTitle, action: onApproveSafe)
                        .buttonStyle(.borderedProminent)
                        .disabled(!transferChoiceConfirmed || readyCount == 0 || activeDestinationName.isEmpty)
                        .prismClickable()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Or place only the files you selected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(selectionCaption)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 14) {
                        dropZone(title: "Photos", icon: "photo", bucket: "Photos", action: onMoveToPhotos)
                        dropZone(title: "Videos", icon: "film", bucket: "Videos", action: onMoveToVideos)
                        dropZone(title: "Gather", icon: "tray", bucket: "Gather", action: onMoveToGather)
                    }
                }

                HStack {
                    Text("\(pendingCount) files in the catalog")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Find more files", action: onStartDiscover)
                        .buttonStyle(.bordered)
                        .prismClickable()
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var selectionCaption: String {
        guard transferChoiceConfirmed else {
            return "Choose move or copy above before placing a selection."
        }
        if activeDestinationName.isEmpty {
            return "Choose a destination folder first."
        }
        let verb = transferMode == .move ? "Move" : "Copy"
        if !canTransfer {
            return "Select files in Library, then \(verb.lowercased()) them into a folder inside “\(activeDestinationName)”."
        }
        return "\(verb) \(selectionLabel) into “\(activeDestinationName)”."
    }

    private func stepHeader(_ number: String, _ title: String) -> some View {
        HStack(spacing: 8) {
            Text(number)
                .font(.caption.weight(.bold).monospacedDigit())
                .frame(width: 22, height: 22)
                .background(PrismTheme.accent, in: Circle())
                .foregroundStyle(.white)
            Text(title)
                .font(.headline)
        }
    }

    private func transferChoice(_ option: FileTransferMode) -> some View {
        let selected = transferChoiceConfirmed && transferMode == option
        return Button {
            transferMode = option
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(option.stepTitle)
                    .font(.subheadline.weight(.semibold))
                Text(option.stepDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? PrismTheme.accentSoft : Color.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? PrismTheme.accent : Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .prismClickable()
    }

    private func dropZone(
        title: String,
        icon: String,
        bucket: String,
        action: @escaping () -> Void
    ) -> some View {
        let enabled = canTransfer && transferChoiceConfirmed
        let verb = transferMode == .move ? "Move" : "Copy"
        return Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title)
                Text(title)
                    .font(.headline)
                Text(activeDestinationName.isEmpty ? "Choose a folder first" : "\(verb) into \(bucket)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(enabled ? 0.1 : 0.04)))
            .opacity(enabled ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .prismClickable()
    }
}
