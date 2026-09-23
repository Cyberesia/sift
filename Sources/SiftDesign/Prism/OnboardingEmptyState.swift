import SwiftUI

public struct OnboardingEmptyState: View {
    let onScanMac: () -> Void
    let onChooseLocations: () -> Void
    let onEnablePhotos: () -> Void

    public init(
        onScanMac: @escaping () -> Void,
        onChooseLocations: @escaping () -> Void,
        onEnablePhotos: @escaping () -> Void
    ) {
        self.onScanMac = onScanMac
        self.onChooseLocations = onChooseLocations
        self.onEnablePhotos = onEnablePhotos
    }

    public var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(PrismTheme.accentGradient)
                .shadow(color: PrismTheme.accentGlow, radius: 16, y: 4)
            VStack(spacing: 8) {
                Text("Find files on this Mac")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PrismTheme.textPrimary)
                Text("Start by making a catalog of photos, video, and audio.\nEvery file stays where it is until you choose to move or copy it.")
                    .font(.subheadline)
                    .foregroundStyle(PrismTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 10) {
                Button("Scan this Mac", action: onScanMac)
                    .buttonStyle(.borderedProminent)
                    .tint(PrismTheme.accent)
                    .prismClickable()
                HStack(spacing: 14) {
                    Button("Choose folders", action: onChooseLocations)
                        .buttonStyle(.bordered)
                        .tint(PrismTheme.textSecondary)
                        .prismClickable()
                    Button("Photos Library", action: onEnablePhotos)
                        .buttonStyle(.bordered)
                        .tint(PrismTheme.textSecondary)
                        .prismClickable()
                }
            }
        }
        .padding(48)
        .prismGlass(cornerRadius: 32, padding: 0)
    }
}
