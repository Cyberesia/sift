import SiftCore
import SwiftUI

public struct FolderIntakeWizard: View {
    let folderName: String
    let estimate: FolderTreeEstimate
    @Binding var selectedPaths: Set<String>
    @Binding var includeSubfolders: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var step = 0
    @State private var search = ""

    public init(
        folderName: String,
        estimate: FolderTreeEstimate,
        selectedPaths: Binding<Set<String>>,
        includeSubfolders: Binding<Bool>,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.folderName = folderName
        self.estimate = estimate
        _selectedPaths = selectedPaths
        _includeSubfolders = includeSubfolders
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add “\(folderName)”")
                .font(.title2.weight(.semibold))

            if step == 0 {
                overviewStep
            } else if step == 1 {
                subfolderStep
            } else {
                confirmStep
            }

            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                    .prismClickable()
                Spacer()
                if step > 0 {
                    Button("Back") {
                        step -= 1
                        if step == 0 {
                            syncSelectionForSubfolderStep()
                        }
                    }
                    .prismClickable()
                }
                Button(step < 2 ? "Continue" : "Continue to destination") {
                    advanceStep()
                }
                .buttonStyle(.borderedProminent)
                .prismClickable()
                .keyboardShortcut(.defaultAction)
                .disabled(step == 1 && includeSubfolders && selectedPaths.isEmpty)
            }
        }
        .padding(28)
        .frame(width: 520)
        .frame(minHeight: 420)
        .prismGlass(cornerRadius: 24, padding: 0)
        .onAppear {
            syncSelectionForSubfolderStep()
        }
        .onChange(of: includeSubfolders) { _, _ in
            if step == 0 {
                syncSelectionForSubfolderStep()
            }
        }
    }

    private func advanceStep() {
        if step == 0 {
            syncSelectionForSubfolderStep()
        }
        if step < 2 {
            step += 1
        } else {
            onConfirm()
        }
    }

    /// Aligns checkboxes with the “Look inside subfolders” toggle before showing step 2.
    private func syncSelectionForSubfolderStep() {
        if includeSubfolders {
            var paths = allSubfolderPaths()
            if estimate.hasRootMedia {
                paths.insert(rootPath)
            }
            selectedPaths = paths
        } else {
            if estimate.hasRootMedia {
                selectedPaths = [rootPath]
            } else {
                selectedPaths = []
            }
        }
    }

    private var overviewStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("We’ll scan this folder structure and help you collect scattered media.")
                .foregroundStyle(.secondary)

            rootSummaryRow

            HStack(spacing: 16) {
                statCard("\(estimate.totalImages)", label: "Photos")
                statCard("\(estimate.totalVideos)", label: "Videos")
                statCard(byteLabel(estimate.totalBytes), label: "Estimated size")
            }

            if includeSubfolders, subfolderOnlyCount > 0 {
                Text("Including \(subfolderOnlyCount) subfolder(s) with media.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Toggle(isOn: $includeSubfolders) {
                Text("Look inside subfolders")
            }
            .toggleStyle(.switch)
        }
    }

    private var rootSummaryRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            if estimate.hasRootMedia {
                Text("In this folder: \(estimate.rootImages) photos, \(estimate.rootVideos) videos")
            } else {
                Text("No photos or videos directly in this folder")
            }
        }
        .font(.subheadline)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
    }

    private var subfolderStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !includeSubfolders {
                Text("Only files in “\(folderName)” will be scanned. Select subfolders below to include them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Search subfolders", text: $search)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Select all") {
                    includeSubfolders = true
                    syncSelectionForSubfolderStep()
                }
                .prismClickable()
                Button("Root only") {
                    includeSubfolders = false
                    syncSelectionForSubfolderStep()
                }
                .prismClickable()
            }
            .font(.caption)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if estimate.hasRootMedia {
                        subfolderRow(rootNode)
                    }
                    ForEach(filteredNodes(), id: \.relativePath) { node in
                        subfolderRow(node)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
    }

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(confirmSummary)
            Text("Next: choose a destination folder with Photos, Videos, and Gather zones.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var confirmSummary: String {
        if !includeSubfolders {
            return "Ready to scan this folder only (\(estimate.rootMedia) file(s))."
        }
        let count = selectedPaths.isEmpty ? allSelectablePaths().count : selectedPaths.count
        return "Ready to collect from \(count) location(s)."
    }

    private var rootNode: SubfolderNode {
        SubfolderNode(
            id: rootPath,
            relativePath: rootPath,
            displayName: "This folder",
            imageCount: estimate.rootImages,
            videoCount: estimate.rootVideos
        )
    }

    private func subfolderRow(_ node: SubfolderNode) -> some View {
        let path = node.relativePath
        let isOn = selectedPaths.contains(path)
        let isRoot = path.isEmpty
        return Button {
            if isOn {
                selectedPaths.remove(path)
            } else {
                selectedPaths.insert(path)
                if !isRoot {
                    includeSubfolders = true
                }
            }
        } label: {
            HStack {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? PrismTheme.accent : .secondary)
                Text(node.displayName)
                Spacer()
                Text(mediaCountLabel(node))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(isOn ? 0.1 : 0.06)))
        }
        .buttonStyle(.plain)
        .prismClickable()
    }

    private func mediaCountLabel(_ node: SubfolderNode) -> String {
        var parts: [String] = []
        if node.imageCount > 0 { parts.append("\(node.imageCount) photos") }
        if node.videoCount > 0 { parts.append("\(node.videoCount) videos") }
        return parts.isEmpty ? "0" : parts.joined(separator: ", ")
    }

    private func statCard(_ value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08)))
    }

    private func byteLabel(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private var rootPath: String { "" }

    private var subfolderOnlyCount: Int {
        allSubfolderPaths().count
    }

    private func allSubfolderPaths() -> Set<String> {
        Set(flatPaths(from: estimate.nodes).filter { !$0.isEmpty })
    }

    private func allSelectablePaths() -> Set<String> {
        var paths = allSubfolderPaths()
        if estimate.hasRootMedia {
            paths.insert(rootPath)
        }
        return paths
    }

    private func flatPaths(from nodes: [SubfolderNode]) -> [String] {
        nodes.flatMap { node -> [String] in
            [node.relativePath] + flatPaths(from: node.children)
        }
    }

    private func filteredNodes() -> [SubfolderNode] {
        let flat = flatten(estimate.nodes).filter { !$0.relativePath.isEmpty }
        guard !search.isEmpty else { return flat }
        let q = search.lowercased()
        return flat.filter {
            $0.displayName.lowercased().contains(q) || $0.relativePath.lowercased().contains(q)
        }
    }

    private func flatten(_ nodes: [SubfolderNode]) -> [SubfolderNode] {
        nodes.flatMap { [$0] + flatten($0.children) }
    }
}
