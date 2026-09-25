import SiftCore
import SwiftUI

/// One conversational field that morphs into a scan, slice, or organization card.
public struct AssistantWorkspaceView: View {
    @Binding var text: String
    let state: AssistantUIState
    let result: AssistantResult
    let command: AssistantCommand
    let composition: CatalogComposition?
    let preview: [OrganizePlanItem]
    let onTextChange: (String) -> Void
    let onChooseIntent: (AssistantIntent) -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void
    let scopeLabel: String?
    let onClearScope: () -> Void
    let find: AssistantFindResult?
    let onOpenHit: (MediaAssetSummary) -> Void
    let onScanMore: () -> Void
    @FocusState private var focused: Bool

    public init(
        text: Binding<String>,
        state: AssistantUIState,
        result: AssistantResult,
        command: AssistantCommand,
        composition: CatalogComposition?,
        preview: [OrganizePlanItem],
        onTextChange: @escaping (String) -> Void,
        onChooseIntent: @escaping (AssistantIntent) -> Void,
        onSubmit: @escaping () -> Void,
        onClear: @escaping () -> Void,
        scopeLabel: String? = nil,
        onClearScope: @escaping () -> Void = {},
        find: AssistantFindResult? = nil,
        onOpenHit: @escaping (MediaAssetSummary) -> Void = { _ in },
        onScanMore: @escaping () -> Void = {}
    ) {
        self.scopeLabel = scopeLabel
        self.onClearScope = onClearScope
        self.find = find
        self.onOpenHit = onOpenHit
        self.onScanMore = onScanMore
        _text = text
        self.state = state
        self.result = result
        self.command = command
        self.composition = composition
        self.preview = preview
        self.onTextChange = onTextChange
        self.onChooseIntent = onChooseIntent
        self.onSubmit = onSubmit
        self.onClear = onClear
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Tell Sift what to do")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PrismTheme.textSecondary)
                if let scopeLabel {
                    Button(action: onClearScope) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text("Only \(scopeLabel)")
                            Image(systemName: "xmark")
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(PrismTheme.accentSoft))
                    }
                    .buttonStyle(.plain)
                    .help("Use the whole catalog again")
                    .prismClickable()
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Image(systemName: activeIntent?.icon ?? "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PrismTheme.accentGradient)
                    .frame(width: 30)
                TextField(
                    "",
                    text: $text,
                    prompt: Text(composition == nil
                        ? "For example: pictures with dogs, scan this Mac, or move videos into Videos"
                        : "For example: only the jpg, or move these files into Photos")
                        .foregroundStyle(PrismTheme.textTertiary),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.title3.weight(.medium))
                .lineLimit(1...3)
                .focused($focused)
                .onChange(of: text) { _, value in onTextChange(value) }
                .onSubmit(onSubmit)

                if !text.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PrismTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear (Esc)")
                    .prismClickable()
                }
            }

            stateContent
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PrismTheme.surfaceMuted.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(PrismTheme.accent.opacity(focused ? 0.85 : 0.38), lineWidth: focused ? 1.6 : 1)
        )
        .shadow(color: PrismTheme.accent.opacity(focused ? 0.14 : 0.05), radius: 24, y: 10)
        .animation(.snappy(duration: 0.32), value: state)
        .onExitCommand(perform: onClear)
        .task { focused = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sift command field")
    }

    @ViewBuilder
    private var stateContent: some View {
        switch state {
        case .input:
            suggestions
        case .choose(let first, let second):
            VStack(alignment: .leading, spacing: 9) {
                Text("Did you mean…")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PrismTheme.textSecondary)
                HStack {
                    intentChip(first)
                    intentChip(second)
                }
            }
        case .ghost(let intent):
            intentCard(intent, ghost: true)
        case .committed(let intent, _):
            intentCard(intent, ghost: false)
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(text.isEmpty
                 ? "Ask for files by what they show, or say how to organize them"
                 : "Sift is not sure what “\(text)” should do. Keep typing, or pick one:")
                .font(.caption)
                .foregroundStyle(PrismTheme.textSecondary)
            FlowLayout(spacing: 7) {
                intentChip(.find)
                intentChip(.scan)
                if composition != nil { intentChip(.slice) }
                intentChip(.organizeByType)
                intentChip(.organizeByDate)
                intentChip(.review)
            }
        }
    }

    private func intentChip(_ intent: AssistantIntent) -> some View {
        Button {
            onChooseIntent(intent)
        } label: {
            Label(intent.title, systemImage: intent.icon)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .overlay(Capsule().strokeBorder(PrismTheme.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .prismClickable()
    }

    private func intentCard(_ intent: AssistantIntent, ghost: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(intent.title, systemImage: intent.icon)
                    .font(.headline)
                Spacer()
                Text(result.engine == "jev" ? "Jev" : "On-device")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PrismTheme.textTertiary)
                if ghost {
                    Text("Preview")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PrismTheme.accent)
                }
            }

            switch intent {
            case .find:
                findCard
            case .scan:
                scanCard
            case .slice:
                sliceCard
            case .organizeByType, .organizeByDate, .organizeByContent:
                planCard(intent)
            case .leaveInPlace:
                Label("Files stay exactly where they are.", systemImage: "hand.raised")
                    .font(.subheadline)
            case .review:
                Label("Open uncertain suggestions, duplicates, and face groups.", systemImage: "checklist")
                    .font(.subheadline)
            case .none:
                EmptyView()
            }

            HStack {
                Text("Esc to clear")
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textTertiary)
                Spacer()
                if intent == .find {
                    findActions
                } else {
                    Button(intent.actionTitle, action: onSubmit)
                        .buttonStyle(.borderedProminent)
                        .disabled(ghost)
                        .prismClickable()
                }
            }
        }
        .opacity(ghost && intent != .find ? 0.67 : 1)
    }

    private var findSubject: String {
        let kinds = command.kinds
        if kinds == [.image] { return "photos" }
        if kinds == [.video] { return "videos" }
        if kinds == [.audio] { return "audio files" }
        if kinds == [.document] { return "documents" }
        return "files"
    }

    @ViewBuilder
    private var findCard: some View {
        let query = find?.query ?? command.searchQuery
        let searched = find?.searchedCount ?? 0
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if query.isEmpty {
                    Text("Say what the \(findSubject) show, contain, or are called. For example: dogs, beach, invoice.")
                } else if find == nil || (find?.searching == true && find?.hits.isEmpty == true) {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Looking through \(searched) \(findSubject) for “\(query)”…")
                    }
                } else if let find {
                    switch find.match {
                    case .labeled:
                        Text("\(find.labeledCount) of \(searched) \(findSubject) match “\(query)”.")
                            .fontWeight(.semibold)
                    case .lookalike:
                        Text("No \(singular(findSubject)) is labeled “\(query)”. These are the closest-looking ones.")
                            .fontWeight(.semibold)
                    case .nothing:
                        Text(searched == 0
                             ? "The catalog has no \(findSubject) yet, so there is nothing to search."
                             : "Nothing among \(searched) \(findSubject) matches “\(query)”.")
                            .fontWeight(.semibold)
                    }
                }
            }
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)

            if let hits = find?.hits, !hits.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(hits) { asset in
                            Button { onOpenHit(asset) } label: {
                                ThumbnailStripTile(asset: asset, size: 72)
                            }
                            .buttonStyle(.plain)
                            .help(asset.fileName)
                            .prismClickable()
                        }
                    }
                }
                .frame(height: 76)
            }

            if let find, !find.searching {
                Text(findGuidance(find))
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func findGuidance(_ find: AssistantFindResult) -> String {
        switch find.match {
        case .labeled:
            return "Click a picture to open it, or show every match in the Library."
        case .lookalike:
            return "Sift did not recognize “\(find.query)” with certainty. Check them in the Library, try another word, or scan more folders."
        case .nothing where find.searchedCount == 0:
            return "Scan a folder or this Mac first. Files stay where they are."
        case .nothing:
            return find.visualSearchReady
                ? "Try another word, or scan more folders where these could be."
                : "Visual search is still loading, so only labels, text, and names were read. Try again in a moment, or scan more folders."
        }
    }

    @ViewBuilder
    private var findActions: some View {
        let hasHits = !(find?.hits.isEmpty ?? true)
        if !hasHits, find?.searching == false {
            Button("Scan more folders ↵", action: onScanMore)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .prismClickable()
        } else {
            Button("Scan more folders", action: onScanMore)
                .buttonStyle(.bordered)
                .prismClickable()
            Button(find?.match == .lookalike ? "Check them in Library ↵" : "Show all in Library ↵", action: onSubmit)
                .buttonStyle(.borderedProminent)
                .disabled(!hasHits)
                .prismClickable()
        }
    }

    private func singular(_ subject: String) -> String {
        switch subject {
        case "photos": "photo"
        case "videos": "video"
        case "audio files": "audio file"
        case "documents": "document"
        default: "file"
        }
    }

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(
                command.scansWholeMac ? "Home folders and connected disks" : "Choose the folders or disks to catalog",
                systemImage: command.scansWholeMac ? "internaldrive" : "folder.badge.plus"
            )
            .font(.subheadline.weight(.medium))
            Text("Sift catalogs files in place. Nothing is moved or copied.")
                .font(.caption)
                .foregroundStyle(PrismTheme.textSecondary)
        }
    }

    private var sliceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let source = command.sourceLabel ?? composition?.sourceLabel {
                Label(source, systemImage: "folder")
                    .font(.subheadline.weight(.medium))
            }
            FlowLayout(spacing: 6) {
                ForEach(sliceExtensions, id: \.name) { item in
                    Text("\(item.name) \(item.count)")
                        .font(.caption.monospaced())
                        .strikethrough(item.excluded)
                        .foregroundStyle(item.excluded ? PrismTheme.textTertiary : PrismTheme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(item.excluded ? Color.white.opacity(0.04) : PrismTheme.accentSoft))
                }
            }
            Text("This changes only the current selection. Files already in the catalog stay.")
                .font(.caption)
                .foregroundStyle(PrismTheme.textSecondary)
        }
    }

    private func planCard(_ intent: AssistantIntent) -> some View {
        let ready = preview.filter { !$0.blocked }
        let held = preview.filter(\.blocked)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Label("\(ready.count) ready", systemImage: "checkmark.circle")
                    .foregroundStyle(PrismTheme.textPrimary)
                Label("\(held.count) held", systemImage: "pause.circle")
                    .foregroundStyle(PrismTheme.textSecondary)
            }
            .font(.subheadline.weight(.semibold))

            ForEach(ready.prefix(4)) { item in
                HStack(spacing: 8) {
                    Image(systemName: "doc")
                        .foregroundStyle(PrismTheme.textTertiary)
                    Text(item.fileName)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(PrismTheme.textTertiary)
                    Text(item.proposedFolder)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .font(.caption)
            }
            if ready.count > 4 {
                Text("+ \(ready.count - 4) more")
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textSecondary)
            }
            if intent == .organizeByContent, held.contains(where: { $0.blockReason == "Content evidence is not ready" }) {
                Text("Files without complete content evidence stay in review.")
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textSecondary)
            }
            HStack(spacing: 6) {
                stepBadge(1, "Destination", active: false)
                Image(systemName: "chevron.right").foregroundStyle(PrismTheme.textTertiary)
                stepBadge(2, "Move or Copy", active: false)
                Image(systemName: "chevron.right").foregroundStyle(PrismTheme.textTertiary)
                stepBadge(3, "Review and file", active: false)
            }
            .font(.caption)
            Text("Enter opens these three steps on the Organize page, with this plan loaded. Nothing moves until step 3.")
                .font(.caption)
                .foregroundStyle(PrismTheme.textSecondary)
        }
    }

    private func stepBadge(_ number: Int, _ title: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .frame(width: 16, height: 16)
                .background(Circle().fill(active ? PrismTheme.accent : Color.white.opacity(0.1)))
            Text(title)
                .fontWeight(active ? .semibold : .regular)
                .foregroundStyle(active ? PrismTheme.textPrimary : PrismTheme.textSecondary)
        }
    }

    private var activeIntent: AssistantIntent? { state.activeIntent }

    private var sliceExtensions: [(name: String, count: Int, excluded: Bool)] {
        let all = composition?.extensions ?? []
        if all.isEmpty {
            let names = command.included.union(command.excluded).sorted()
            return names.map { ($0, 0, command.excluded.contains($0)) }
        }
        return all.map { item in
            (item.fileExtension.isEmpty ? "no ext." : item.fileExtension, item.count, command.excluded.contains(item.fileExtension))
        }
    }
}

private extension AssistantIntent {
    var title: String {
        switch self {
        case .find: "Find in catalog"
        case .scan: "Add files to the catalog"
        case .slice: "Choose catalog files"
        case .organizeByType: "Organize by type"
        case .organizeByDate: "Organize by date"
        case .organizeByContent: "Organize by content"
        case .leaveInPlace: "Leave files in place"
        case .review: "Review first"
        case .none: "Sift"
        }
    }

    var icon: String {
        switch self {
        case .find: "magnifyingglass"
        case .scan: "sparkle.magnifyingglass"
        case .slice: "line.3.horizontal.decrease.circle"
        case .organizeByType: "folder.badge.gearshape"
        case .organizeByDate: "calendar"
        case .organizeByContent: "sparkles.rectangle.stack"
        case .leaveInPlace: "hand.raised"
        case .review: "checklist"
        case .none: "sparkles"
        }
    }

    var actionTitle: String {
        switch self {
        case .find: "Show all in Library ↵"
        case .scan: "Choose and scan ↵"
        case .slice: "Show these files ↵"
        case .organizeByType, .organizeByDate, .organizeByContent: "Continue in Organize ↵"
        case .leaveInPlace: "Keep files here ↵"
        case .review: "Open review ↵"
        case .none: "Continue ↵"
        }
    }
}
