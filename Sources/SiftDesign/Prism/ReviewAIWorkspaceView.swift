import SiftCore
import SwiftUI

/// Review AI mode — smart groups, duplicates, and on-device tagging controls.
public struct ReviewAIWorkspaceView: View {
    @State private var pendingTrash: DuplicateGroup?
    let collections: [StratumCollectionRecord]
    let personGroups: [PersonReviewGroup]
    let duplicateGroups: [DuplicateGroup]
    let assetCount: Int
    let analyzedCount: Int
    let pendingAnalysisCount: Int
    let isScanningDuplicates: Bool
    let duplicateScanLabel: String
    let duplicateScanFraction: Double
    let onRenameCollection: (String, String) -> Void
    let onAcceptCollection: (String) -> Void
    let onRejectCollection: (String) -> Void
    let onRunAITagging: () -> Void
    let onScanDuplicates: () -> Void
    let onOpenDuplicateGroup: (DuplicateGroup) -> Void
    let onTrashDuplicateExtras: (DuplicateGroup) -> Void
    let onOpenPersonGroup: (PersonReviewGroup) -> Void

    public init(
        collections: [StratumCollectionRecord],
        personGroups: [PersonReviewGroup] = [],
        duplicateGroups: [DuplicateGroup],
        assetCount: Int,
        analyzedCount: Int,
        pendingAnalysisCount: Int,
        isScanningDuplicates: Bool,
        duplicateScanLabel: String = "",
        duplicateScanFraction: Double = 0,
        onRenameCollection: @escaping (String, String) -> Void,
        onAcceptCollection: @escaping (String) -> Void,
        onRejectCollection: @escaping (String) -> Void,
        onRunAITagging: @escaping () -> Void,
        onScanDuplicates: @escaping () -> Void,
        onOpenDuplicateGroup: @escaping (DuplicateGroup) -> Void,
        onTrashDuplicateExtras: @escaping (DuplicateGroup) -> Void = { _ in },
        onOpenPersonGroup: @escaping (PersonReviewGroup) -> Void = { _ in }
    ) {
        self.collections = collections
        self.personGroups = personGroups
        self.duplicateGroups = duplicateGroups
        self.assetCount = assetCount
        self.analyzedCount = analyzedCount
        self.pendingAnalysisCount = pendingAnalysisCount
        self.isScanningDuplicates = isScanningDuplicates
        self.duplicateScanLabel = duplicateScanLabel
        self.duplicateScanFraction = duplicateScanFraction
        self.onRenameCollection = onRenameCollection
        self.onAcceptCollection = onAcceptCollection
        self.onRejectCollection = onRejectCollection
        self.onRunAITagging = onRunAITagging
        self.onScanDuplicates = onScanDuplicates
        self.onOpenDuplicateGroup = onOpenDuplicateGroup
        self.onTrashDuplicateExtras = onTrashDuplicateExtras
        self.onOpenPersonGroup = onOpenPersonGroup
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statusCard
                duplicatesSection
                if collections.isEmpty && personGroups.isEmpty {
                    emptyGroupsCard
                } else {
                    groupsSection
                }
                actionRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            "Move the extra files to the Trash?",
            isPresented: Binding(
                get: { pendingTrash != nil },
                set: { if !$0 { pendingTrash = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Move extras to Trash", role: .destructive) {
                if let pendingTrash {
                    onTrashDuplicateExtras(pendingTrash)
                }
                pendingTrash = nil
            }
            Button("Cancel", role: .cancel) { pendingTrash = nil }
        } message: {
            Text("The extra files go to the Trash. The suggested file stays where it is.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Review AI")
                .font(.title2.weight(.semibold))
                .foregroundStyle(PrismTheme.textPrimary)
            Text("Tag photos on device, scan for duplicates, then name and accept face groups. Accepted people appear under Library → Named people.")
                .font(.subheadline)
                .foregroundStyle(PrismTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 20) {
            statusTile(title: "Indexed", value: "\(assetCount)", icon: "photo.stack")
            statusTile(title: "Analyzed", value: "\(analyzedCount)", icon: "sparkles")
            statusTile(
                title: "Pending",
                value: "\(pendingAnalysisCount)",
                icon: "clock.arrow.circlepath"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusTile(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(PrismTheme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PrismTheme.textTertiary)
                Text(value)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(PrismTheme.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PrismTheme.surfaceMuted.opacity(0.65))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(PrismTheme.borderSubtle, lineWidth: 1)
                }
        )
    }

    private var duplicatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Duplicates")
                    .font(.headline)
                    .foregroundStyle(PrismTheme.textPrimary)
                Spacer()
                Button(isScanningDuplicates ? "Scanning…" : "Scan library", action: onScanDuplicates)
                    .buttonStyle(.bordered)
                    .disabled(isScanningDuplicates || assetCount == 0)
                    .prismClickable()
            }
            if isScanningDuplicates {
                VStack(alignment: .leading, spacing: 6) {
                    Text(duplicateScanLabel.isEmpty ? "Scanning the library…" : duplicateScanLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PrismTheme.textSecondary)
                    ProgressView(value: min(max(duplicateScanFraction, 0.02), 1))
                        .tint(PrismTheme.accent)
                    Text("Comparing on-device feature prints. Photos stay where they are.")
                        .font(.caption2)
                        .foregroundStyle(PrismTheme.textTertiary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PrismTheme.surfaceMuted.opacity(0.55))
                )
            }
            if duplicateGroups.isEmpty {
                Text("Find exact and near-duplicate photos using on-device feature prints.")
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textTertiary)
            } else {
                let reclaim = duplicateGroups.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
                Text("\(duplicateGroups.count) groups · up to \(formatBytes(reclaim)) reclaimable")
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textSecondary)
                ForEach(duplicateGroups) { group in
                    duplicateRow(group)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func duplicateRow(_ group: DuplicateGroup) -> some View {
        HStack(spacing: 12) {
            Button {
                onOpenDuplicateGroup(group)
            } label: {
                HStack(spacing: 6) {
                    ForEach(group.memberIDs.prefix(4), id: \.self) { id in
                        ThumbnailImageView(path: group.thumbnailPaths[id], contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                if id == group.suggestedKeepID {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(PrismTheme.accent, lineWidth: 2)
                                }
                            }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.kind == .exact ? "Exact match" : "Near duplicate")
                            .font(.subheadline.weight(.semibold))
                        Text("\(group.memberIDs.count) files · outlined one stays")
                            .font(.caption)
                            .foregroundStyle(PrismTheme.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .prismClickable()
            Spacer()
            Text(formatBytes(group.reclaimableBytes))
                .font(.caption.monospacedDigit())
                .foregroundStyle(PrismTheme.accent)
            Button("Trash extras") {
                pendingTrash = group
            }
            .font(.caption.weight(.semibold))
            .prismClickable()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PrismTheme.surfaceMuted.opacity(0.5))
        )
    }

    private var emptyGroupsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No smart groups yet", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(PrismTheme.textPrimary)
            Text("After indexing finishes, run AI tagging to cluster faces, trips, and screenshots.")
                .font(.subheadline)
                .foregroundStyle(PrismTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PrismTheme.surfaceMuted.opacity(0.5))
        )
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested groups")
                .font(.headline)
                .foregroundStyle(PrismTheme.textPrimary)
            Text("Accept adds the person to the library sidebar. Dismiss only hides the card. Neither one deletes photos. Duplicate extras are removed with Trash extras.")
                .font(.caption)
                .foregroundStyle(PrismTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(personGroups) { group in
                    personCard(group)
                }
                ForEach(collections, id: \.id) { collection in
                    groupCard(collection)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func personCard(_ group: PersonReviewGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                onOpenPersonGroup(group)
            } label: {
                HStack(spacing: 6) {
                    ForEach(group.previews) { preview in
                        ThumbnailImageView(path: preview.thumbnailPath, contentMode: .fill)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    Spacer(minLength: 0)
                    Text("\(group.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(PrismTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .prismClickable()
            TextField("Name", text: binding(for: group))
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                Button("Accept") { onAcceptCollection(group.id) }
                    .font(.caption.weight(.semibold))
                    .prismClickable()
                Button("Dismiss") { onRejectCollection(group.id) }
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textTertiary)
                    .prismClickable()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PrismTheme.surfaceMuted.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(PrismTheme.borderSubtle, lineWidth: 1)
                }
        )
    }

    private func groupCard(_ collection: StratumCollectionRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(PrismTheme.accent)
                Spacer()
                Text("\(collection.assets?.count ?? 0)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PrismTheme.textTertiary)
            }
            TextField("Name", text: binding(for: collection))
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                Button("Accept") { onAcceptCollection(collection.id) }
                    .font(.caption.weight(.semibold))
                    .prismClickable()
                Button("Dismiss") { onRejectCollection(collection.id) }
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textTertiary)
                    .prismClickable()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PrismTheme.surfaceMuted.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(PrismTheme.borderSubtle, lineWidth: 1)
                }
        )
    }

    private var actionRow: some View {
        HStack {
            Spacer()
            Button("Run AI tagging", action: onRunAITagging)
                .buttonStyle(.borderedProminent)
                .tint(PrismTheme.accent)
                .disabled(assetCount == 0)
                .prismClickable()
        }
        .frame(maxWidth: .infinity)
    }

    private func binding(for group: PersonReviewGroup) -> Binding<String> {
        Binding(
            get: { group.title },
            set: { onRenameCollection(group.id, $0) }
        )
    }

    private func binding(for collection: StratumCollectionRecord) -> Binding<String> {
        Binding(
            get: { collection.displayTitle },
            set: { onRenameCollection(collection.id, $0) }
        )
    }

    private func formatBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
