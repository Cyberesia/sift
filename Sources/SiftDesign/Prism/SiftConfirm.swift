import SwiftUI

/// A change that waits for an explicit yes. Cancel leaves everything as it is.
public struct SiftConfirm: Identifiable {
    public let id = UUID()
    public var title: String
    public var message: String
    public var confirmTitle: String
    public var destructive: Bool
    public var run: () -> Void

    public init(
        title: String,
        message: String,
        confirmTitle: String,
        destructive: Bool = true,
        run: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.destructive = destructive
        self.run = run
    }
}

extension View {
    public func siftConfirming(_ confirm: Binding<SiftConfirm?>) -> some View {
        alert(
            confirm.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { confirm.wrappedValue != nil },
                set: { if !$0 { confirm.wrappedValue = nil } }
            ),
            presenting: confirm.wrappedValue
        ) { pending in
            Button(pending.confirmTitle, role: pending.destructive ? .destructive : nil) {
                pending.run()
            }
            Button(Locale.current.language.languageCode?.identifier == "fr" ? "Annuler" : "Cancel", role: .cancel) {}
        } message: { pending in
            Text(pending.message)
        }
    }
}

/// Reset asks which side to clear. Both start off, so a click cannot wipe anything by itself.
public struct SiftResetSheet: View {
    @Binding var resetLibrary: Bool
    @Binding var resetSettings: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    public init(
        resetLibrary: Binding<Bool>,
        resetSettings: Binding<Bool>,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        _resetLibrary = resetLibrary
        _resetSettings = resetSettings
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reset")
                .font(.title2.weight(.semibold))
                .foregroundStyle(PrismTheme.textPrimary)
            Text("Choose what to clear. Nothing is erased until you confirm. Files already on this Mac are not deleted.")
                .font(.subheadline)
                .foregroundStyle(PrismTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: $resetLibrary) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Library")
                        .font(.body.weight(.semibold))
                    Text("Erases the catalog, thumbnails, and transfer history. Photos, audio, video, and documents stay in their folders. Discover is empty until you scan again.")
                        .font(.caption)
                        .foregroundStyle(PrismTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .prismClickable()

            Toggle(isOn: $resetSettings) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.body.weight(.semibold))
                    Text("Forgets source folders, destinations, what to look for, and the move-or-copy choice. The Jev key stays in the Keychain.")
                        .font(.caption)
                        .foregroundStyle(PrismTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)

            HStack {
                Button("Cancel", action: onCancel)
                    .prismClickable()
                Spacer()
                Button("Reset what I chose", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .disabled(!resetLibrary && !resetSettings)
                    .prismClickable()
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(PrismTheme.dominantGradient)
    }
}
