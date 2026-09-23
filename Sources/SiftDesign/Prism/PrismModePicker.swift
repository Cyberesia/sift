import SwiftUI

/// Top mode switcher with hand cursor on every segment (replaces native segmented picker).
public struct PrismModePicker: View {
    @Binding var selection: AppMode

    public init(selection: Binding<AppMode>) {
        _selection = selection
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(AppMode.allCases) { mode in
                modeButton(mode)
            }
        }
        .padding(4)
        .prismGlass(cornerRadius: 22, padding: 0)
        .frame(maxWidth: 520)
    }

    private func modeButton(_ mode: AppMode) -> some View {
        let isSelected = selection == mode
        return Button {
            withAnimation(PrismMotion.quick) {
                selection = mode
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.systemImage)
                    .font(.caption.weight(.semibold))
                Text(mode.label)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? Color.white : PrismTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(PrismTheme.accentGradient)
                        .shadow(color: PrismTheme.accentGlow, radius: 8, y: 2)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PrismHandButtonStyle())
    }
}
