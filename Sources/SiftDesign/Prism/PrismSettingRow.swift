import SwiftUI

/// Labeled setting row for floating inspector panels.
public struct PrismSettingRow<Trailing: View, Body: View>: View {
    let title: String
    let icon: String
    let description: String?
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: () -> Body

    @State private var showInfo = false

    public init(
        title: String,
        icon: String,
        description: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: @escaping () -> Body = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.description = description
        self.trailing = trailing
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.primary.opacity(0.85))

                if let description {
                    Button {
                        showInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showInfo) {
                        Text(description)
                            .font(.caption)
                            .padding(12)
                            .frame(maxWidth: 220)
                    }
                    .prismClickable()
                }

                Spacer(minLength: 4)
                trailing()
            }
            content()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
