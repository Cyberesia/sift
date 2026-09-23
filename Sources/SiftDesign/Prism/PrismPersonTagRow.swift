import SiftCore
import SwiftUI

/// Name the people in a photo (links to a person collection for browsing).
public struct PrismPersonTagRow: View {
    let faceCount: Int
    let initialName: String
    let onCommit: (String) -> Void

    @State private var draftName: String = ""
    @FocusState private var isFocused: Bool

    public init(
        faceCount: Int,
        initialName: String,
        onCommit: @escaping (String) -> Void
    ) {
        self.faceCount = faceCount
        self.initialName = initialName
        self.onCommit = onCommit
        _draftName = State(initialValue: initialName)
    }

    public var body: some View {
        PrismSettingRow(
            title: "People",
            icon: "person.crop.circle",
            description: "Give a name to group this photo with others of the same person. Appears under Named people in the sidebar."
        ) {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "face.smiling")
                        .foregroundStyle(.secondary)
                    Text(faceCount == 1 ? "1 face detected" : "\(faceCount) faces detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Name this person…", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit(commit)

                HStack(spacing: 8) {
                    Button("Save name") { commit() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if !initialName.isEmpty {
                        Button("Clear") {
                            draftName = ""
                            onCommit("")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .onChange(of: initialName) { _, newValue in
            if !isFocused {
                draftName = newValue
            }
        }
    }

    private func commit() {
        onCommit(draftName)
        isFocused = false
    }
}
