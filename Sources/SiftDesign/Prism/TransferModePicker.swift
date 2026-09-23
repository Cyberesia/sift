import SiftCore
import SwiftUI

public enum TransferModePickerStyle {
    /// Segmented control for Organize workspace (compact labels).
    case workspace
    /// Radio list for Settings window (full labels, no clipping).
    case settings
    /// Dark Prism settings (accent radio, hand cursor).
    case prism
}

public struct TransferModePicker: View {
    @Binding var mode: FileTransferMode
    let style: TransferModePickerStyle

    public init(mode: Binding<FileTransferMode>, style: TransferModePickerStyle = .workspace) {
        _mode = mode
        self.style = style
    }

    public var body: some View {
        switch style {
        case .workspace:
            workspaceBody
        case .settings:
            settingsBody
        case .prism:
            prismBody
        }
    }

    private var workspaceBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When organizing files")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Picker("Transfer mode", selection: $mode) {
                ForEach(FileTransferMode.allCases) { option in
                    Text(option.shortLabel).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(mode.detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var settingsBody: some View {
        radioList(accent: Color.accentColor, titleColor: .primary, detailColor: .secondary)
    }

    private var prismBody: some View {
        radioList(
            accent: PrismTheme.accent,
            titleColor: PrismTheme.textPrimary,
            detailColor: PrismTheme.textTertiary
        )
    }

    private func radioList(
        accent: Color,
        titleColor: Color,
        detailColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(FileTransferMode.allCases) { option in
                let selected = mode == option
                Button {
                    mode = option
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selected ? accent : PrismTheme.textTertiary)
                            .font(.body)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.label)
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .foregroundStyle(titleColor)
                                .multilineTextAlignment(.leading)
                            Text(option.detail)
                                .font(.caption)
                                .foregroundStyle(detailColor)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(PrismTheme.accentSoft)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(PrismTheme.accent.opacity(0.35), lineWidth: 1)
                                }
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .prismClickable()
            }
        }
    }
}
