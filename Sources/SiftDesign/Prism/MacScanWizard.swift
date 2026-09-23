import SiftCore
import SwiftUI

public struct MacScanWizard: View {
    let fullDiskAccess: Bool
    let lookingFor: String
    let onScanMac: () -> Void
    let onChooseLocations: () -> Void
    let onOpenSettings: () -> Void
    let onClose: () -> Void

    public init(
        fullDiskAccess: Bool,
        lookingFor: String = "Looking for photos, videos, audio, and documents…",
        onScanMac: @escaping () -> Void,
        onChooseLocations: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.fullDiskAccess = fullDiskAccess
        self.lookingFor = lookingFor
        self.onScanMac = onScanMac
        self.onChooseLocations = onChooseLocations
        self.onOpenSettings = onOpenSettings
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Find files on this Mac", systemImage: "sparkle.magnifyingglass")
                .font(.title2.weight(.semibold))
                .foregroundStyle(PrismTheme.textPrimary)

            Text(lookingFor)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PrismTheme.textPrimary)

            Text("This only builds a catalog. Files stay in their folders. You choose later whether to move or copy them.")
                .font(.subheadline)
                .foregroundStyle(PrismTheme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Label(
                    fullDiskAccess ? "Full Disk Access detected" : "Full Disk Access is not enabled",
                    systemImage: fullDiskAccess ? "checkmark.shield.fill" : "lock.shield"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(fullDiskAccess ? .green : .orange)
                Text(fullDiskAccess
                     ? "Scan this Mac checks your home folders and mounted disks."
                     : "Choose folders works now. To scan the whole Mac, allow Full Disk Access and come back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

            Label(
                "Always skipped: macOS system trees, apps, caches, .git, node_modules, DerivedData, .build, Pods, and package bundles.",
                systemImage: "checkmark.shield"
            )
            .font(.caption)
            .foregroundStyle(PrismTheme.textSecondary)

            HStack {
                Button("Cancel", action: onClose)
                    .prismClickable()
                Spacer()
                if !fullDiskAccess {
                    Button("Enable Full Disk Access", action: onOpenSettings)
                        .prismClickable()
                }
                if fullDiskAccess {
                    Button("Choose folders", action: onChooseLocations)
                        .buttonStyle(.bordered)
                        .prismClickable()
                    Button("Scan this Mac", action: onScanMac)
                        .buttonStyle(.borderedProminent)
                        .prismClickable()
                } else {
                    Button("Choose folders", action: onChooseLocations)
                        .buttonStyle(.borderedProminent)
                        .prismClickable()
                }
            }
        }
        .padding(24)
        .frame(width: 580)
        .background(PrismTheme.dominantGradient)
    }
}

public struct OrganizePlanSheet: View {
    let items: [OrganizePlanItem]
    let confirmLabel: String
    let canConfirm: Bool
    let onApproveSafe: () -> Void
    let onClose: () -> Void

    public init(
        items: [OrganizePlanItem],
        confirmLabel: String = "File the waiting ones",
        canConfirm: Bool = true,
        onApproveSafe: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.items = items
        self.confirmLabel = confirmLabel
        self.canConfirm = canConfirm
        self.onApproveSafe = onApproveSafe
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What will change")
                .font(.title2.weight(.semibold))
            Text("Nothing happens until you confirm on the Organize screen. Files already inside the destination, and originals that already have a copy, stay put.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            let safe = items.filter { !$0.blocked }
            let held = items.filter(\.blocked)
            Text("\(safe.count) waiting · \(held.count) left as they are")
                .font(.caption.monospacedDigit())
            List(items.prefix(40)) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName)
                    Text(item.blocked ? (item.blockReason ?? "Left as it is") : "→ \(item.proposedFolder)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 180)
            HStack {
                Button("Close", action: onClose)
                    .prismClickable()
                Spacer()
                Button(confirmLabel, action: onApproveSafe)
                    .buttonStyle(.borderedProminent)
                    .disabled(safe.isEmpty || !canConfirm)
                    .prismClickable()
            }
        }
        .padding(20)
        .frame(width: 520, height: 460)
    }
}
