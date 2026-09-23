import SwiftUI

public struct StartAITaggingSheet: View {
    @Binding var dontAskAgain: Bool
    let pendingCount: Int
    let onLater: () -> Void
    let onStart: () -> Void

    public init(
        dontAskAgain: Binding<Bool>,
        pendingCount: Int,
        onLater: @escaping () -> Void,
        onStart: @escaping () -> Void
    ) {
        _dontAskAgain = dontAskAgain
        self.pendingCount = pendingCount
        self.onLater = onLater
        self.onStart = onStart
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enable content search?")
                .font(.title3.weight(.semibold))
            Text("Sift has cataloged the files. The next optional step analyzes \(pendingCount) remaining items on-device so searches like “cat”, “beach”, visible text, and similar photos can find their content—not only filenames.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label("Media stays on this Mac. You can keep browsing while analysis runs.", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(PrismTheme.textSecondary)
            Toggle("Don’t ask again", isOn: $dontAskAgain)
            HStack {
                Button("Use filename search for now", action: onLater)
                    .prismClickable()
                Spacer()
                Button("Analyze for content search", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .prismClickable()
            }
        }
        .padding(24)
        .frame(width: 510)
        .prismGlass(cornerRadius: 20, padding: 0)
    }
}
