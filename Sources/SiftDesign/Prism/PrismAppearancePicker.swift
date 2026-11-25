import SiftCore
import SwiftUI

/// Skin swatches, light or dark, and interface size. Used in Settings and in setup.
public struct PrismAppearancePicker: View {
    @ObservedObject var store: PrismAppearanceStore
    var compact = false

    public init(store: PrismAppearanceStore = .shared, compact: Bool = false) {
        self.store = store
        self.compact = compact
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                label(tr("Colours", "Couleurs"))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 92 : 110), spacing: 10)], spacing: 10) {
                    ForEach(PrismSkin.allCases) { skin in
                        skinButton(skin)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                label(tr("Light or dark", "Clair ou sombre"))
                Picker("", selection: $store.mode) {
                    Text(tr("Same as the Mac", "Comme le Mac")).tag(PrismAppearanceMode.system)
                    Text(tr("Light", "Clair")).tag(PrismAppearanceMode.light)
                    Text(tr("Dark", "Sombre")).tag(PrismAppearanceMode.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 8) {
                label(tr("Text and interface size", "Taille du texte et de l’interface"))
                Picker("", selection: $store.size) {
                    Text(tr("Small", "Petite")).tag(PrismInterfaceSize.compact)
                    Text(tr("Standard", "Standard")).tag(PrismInterfaceSize.standard)
                    Text(tr("Large", "Grande")).tag(PrismInterfaceSize.large)
                    Text(tr("Larger", "Très grande")).tag(PrismInterfaceSize.larger)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PrismTheme.textSecondary)
    }

    private func skinButton(_ skin: PrismSkin) -> some View {
        let selected = store.skin == skin
        return Button {
            store.skin = skin
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(Array(skin.swatch.enumerated()), id: \.offset) { _, color in
                        Rectangle().fill(color)
                    }
                }
                .frame(height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(skin.title)
                    .font(.caption.weight(selected ? .semibold : .regular))
                    .foregroundStyle(PrismTheme.textPrimary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(PrismTheme.wash.opacity(selected ? 0.10 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(selected ? PrismTheme.accent : PrismTheme.borderSubtle, lineWidth: selected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PrismHandButtonStyle())
        .accessibilityLabel(skin.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
