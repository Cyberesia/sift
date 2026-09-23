import SwiftUI

public struct ConfirmDeleteOriginsSheet: View {
    let paths: [String]
    let onKeep: () -> Void
    let onDelete: () -> Void

    public init(paths: [String], onKeep: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.paths = paths
        self.onKeep = onKeep
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete originals?")
                .font(.title3.weight(.semibold))
            Text("Copied \(paths.count) file(s). Remove originals from their previous locations?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(paths.prefix(8), id: \.self) { path in
                        Text((path as NSString).lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    if paths.count > 8 {
                        Text("…and \(paths.count - 8) more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxHeight: 120)
            HStack {
                Button("Keep originals", action: onKeep)
                    .prismClickable()
                Spacer()
                Button("Delete originals", role: .destructive, action: onDelete)
                    .prismClickable()
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
