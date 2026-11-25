import SiftCore
import SwiftUI

/// Rules mode. Each rule is three stages, Watch, Read and Act, edited in place. Rules are checked from the
/// top of the list down and the first one that fits a file acts on it. A preview shows every file in the
/// watched folder before anything moves; To review holds files waiting for a yes; History can undo.
public struct FolderRulesWorkspaceView: View {
    @ObservedObject var engine: FolderRuleEngine
    @ObservedObject var intelligence: IntelligenceCenter
    let folders: [FolderBookmark]
    let destinations: [DestinationBookmark]
    let onAddWatchedFolder: () async -> String?
    let onAddDestination: () async -> String?
    let onOpenSettings: () -> Void
    let onReveal: (String) -> Void

    @State private var selection: Selection?
    @State private var describeText = ""
    @State private var showDescribe = false
    @State private var isDrafting = false

    enum Selection: Hashable {
        case rule(String)
        case review
        case history
    }

    public init(
        engine: FolderRuleEngine,
        intelligence: IntelligenceCenter,
        folders: [FolderBookmark],
        destinations: [DestinationBookmark],
        onAddWatchedFolder: @escaping () async -> String?,
        onAddDestination: @escaping () async -> String?,
        onOpenSettings: @escaping () -> Void,
        onReveal: @escaping (String) -> Void
    ) {
        self.engine = engine
        self.intelligence = intelligence
        self.folders = folders
        self.destinations = destinations
        self.onAddWatchedFolder = onAddWatchedFolder
        self.onAddDestination = onAddDestination
        self.onOpenSettings = onOpenSettings
        self.onReveal = onReveal
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 272)
            Rectangle().fill(PrismTheme.borderSubtle).frame(width: 1)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .prismGlass(cornerRadius: 22, padding: 0)
        .padding(20)
        .foregroundStyle(PrismTheme.textPrimary)
        .onAppear {
            if selection == nil {
                selection = engine.rules.first.map { .rule($0.id) } ?? (engine.pending.isEmpty ? nil : .review)
            }
            if case .rule(let id) = selection, engine.previews[id] == nil {
                engine.refreshPreview(ruleID: id)
            }
        }
        .sheet(isPresented: $showDescribe) { describeSheet }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(engine.enabledCount > 0 ? Color.green : PrismTheme.textTertiary)
                        .frame(width: 7, height: 7)
                    Text(engine.enabledCount == 0 ? tr("All rules paused", "Toutes les règles en pause")
                                                  : tr("\(engine.enabledCount) active rule(s)", "\(engine.enabledCount) règle(s) active(s)"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PrismTheme.textSecondary)
                }
                Text(tr("Rules work while Sift is open, window closed included: it waits in the menu bar. Quitting Sift stops them.",
                        "Les règles agissent tant que Sift est ouvert, fenêtre fermée comprise : il attend dans la barre de menus. Quitter Sift les arrête."))
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(engine.rules.enumerated()), id: \.element.id) { index, rule in
                        ruleRow(rule, position: index + 1)
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)
            Rectangle().fill(PrismTheme.borderSubtle).frame(height: 1)
            VStack(alignment: .leading, spacing: 2) {
                newRuleMenu
                sidebarButton(.review, title: tr("To review", "À valider"), icon: "tray.full", count: engine.pending.count)
                sidebarButton(.history, title: tr("History", "Historique"), icon: "clock.arrow.circlepath", count: 0)
            }
            .padding(8)
        }
        .background(PrismTheme.surfaceMuted.opacity(0.25))
    }

    private var newRuleMenu: some View {
        Menu {
            Section(tr("Documents Sift reads", "Documents que Sift lit")) {
                ForEach(FolderRuleTemplate.documents) { template in
                    Button { create(template) } label: { Label(template.title, systemImage: template.icon) }
                }
            }
            Section(tr("Files by name, type or size", "Fichiers par nom, type ou taille")) {
                ForEach(FolderRuleTemplate.files) { template in
                    Button { create(template) } label: { Label(template.title, systemImage: template.icon) }
                }
            }
            Divider()
            Button { create(.blank) } label: { Label(FolderRuleTemplate.blank.title, systemImage: FolderRuleTemplate.blank.icon) }
            Button { showDescribe = true } label: { Label(tr("Describe a rule…", "Décrire une règle…"), systemImage: "text.bubble") }
        } label: {
            Label(tr("New rule", "Nouvelle règle"), systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .tint(PrismTheme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .prismClickable()
    }

    private func create(_ template: FolderRuleTemplate) {
        let rule = engine.addRule(from: template)
        selection = .rule(rule.id)
    }

    private func ruleRow(_ rule: FolderRule, position: Int) -> some View {
        let isSelected = selection == .rule(rule.id)
        return HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { engine.setEnabled($0, ruleID: rule.id) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
                .disabled(!rule.hasAction || rule.watchedFolderID == nil)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(rule.isEnabled ? PrismTheme.textPrimary : PrismTheme.textSecondary)
                Text(engine.folderName(for: rule) ?? tr("No folder yet", "Pas encore de dossier"))
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if engine.busyRuleIDs.contains(rule.id) {
                ProgressView().controlSize(.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? PrismTheme.wash.opacity(0.09) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selection = .rule(rule.id)
            if engine.previews[rule.id] == nil { engine.refreshPreview(ruleID: rule.id) }
        }
        .contextMenu {
            Button(tr("Move up", "Monter")) { engine.moveRule(id: rule.id, by: -1) }.disabled(position == 1)
            Button(tr("Move down", "Descendre")) { engine.moveRule(id: rule.id, by: 1) }.disabled(position == engine.rules.count)
            Divider()
            Button(tr("Duplicate", "Dupliquer")) { engine.duplicate(ruleID: rule.id) }
            Button(tr("Delete", "Supprimer"), role: .destructive) {
                engine.delete(ruleID: rule.id)
                if isSelected { selection = engine.rules.first.map { .rule($0.id) } }
            }
        }
        .prismClickable()
    }

    private func sidebarButton(_ target: Selection, title: String, icon: String, count: Int) -> some View {
        Button {
            selection = target
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(PrismTheme.accent))
                        .foregroundStyle(.white)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(selection == target ? PrismTheme.wash.opacity(0.09) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(PrismHandButtonStyle())
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .rule(let id):
            if let rule = engine.rule(id: id) {
                ScrollView {
                    RuleEditorView(
                        rule: rule,
                        position: (engine.rules.firstIndex { $0.id == id } ?? 0) + 1,
                        engine: engine,
                        intelligence: intelligence,
                        folders: folders,
                        destinations: destinations,
                        onAddWatchedFolder: onAddWatchedFolder,
                        onAddDestination: onAddDestination,
                        onOpenSettings: onOpenSettings,
                        onDelete: {
                            engine.delete(ruleID: id)
                            selection = engine.rules.first.map { .rule($0.id) }
                        }
                    )
                    .id(id)
                    .padding(28)
                }
            } else {
                emptyState
            }
        case .review:
            ScrollView { reviewList.padding(28) }
        case .history:
            ScrollView { historyList.padding(28) }
        case nil:
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "wand.and.rays")
                .font(.system(size: 34))
                .foregroundStyle(PrismTheme.accentGradient)
            Text(tr("Let folders tidy themselves", "Laissez les dossiers se ranger seuls"))
                .font(.title2.weight(.semibold))
            Text(tr("A rule watches a folder, reads a new file when it needs to, then renames, moves or tags it. You see what it would do to every file before you switch it on, and every change can be undone.",
                    "Une règle surveille un dossier, lit un nouveau fichier si besoin, puis le renomme, le déplace ou l’étiquette. Vous voyez ce qu’elle ferait à chaque fichier avant de l’activer, et tout peut être annulé."))
                .foregroundStyle(PrismTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], spacing: 10) {
                ForEach(FolderRuleTemplate.documents + FolderRuleTemplate.files) { template in
                    Button { create(template) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: template.icon).frame(width: 22).foregroundStyle(PrismTheme.accent)
                            Text(template.title).font(.subheadline.weight(.medium))
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(PrismTheme.wash.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(PrismTheme.borderSubtle))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PrismHandButtonStyle())
                }
            }
            Button(tr("Describe a rule in your own words…", "Décrire une règle avec vos mots…")) { showDescribe = true }
                .buttonStyle(.borderedProminent)
                .tint(PrismTheme.accent)
                .prismClickable()
        }
        .padding(32)
        .frame(maxWidth: 760, alignment: .leading)
    }

    // MARK: - To review

    private var reviewList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("To review", "À valider")).font(.title2.weight(.semibold))
                    Text(tr("Files a rule would change, waiting for your yes.", "Fichiers qu’une règle changerait, en attente de votre accord."))
                        .font(.callout).foregroundStyle(PrismTheme.textSecondary)
                }
                Spacer()
                if !engine.pending.isEmpty {
                    Button(tr("Apply all \(engine.pending.count)", "Tout appliquer (\(engine.pending.count))")) { engine.filePending() }
                        .buttonStyle(.borderedProminent)
                        .tint(PrismTheme.accent)
                        .prismClickable()
                }
            }
            if engine.pending.isEmpty {
                Label(tr("Nothing to review.", "Rien à valider."), systemImage: "checkmark.circle")
                    .foregroundStyle(PrismTheme.textTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(engine.pending) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "doc").foregroundStyle(PrismTheme.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.fileName).lineLimit(1)
                                Text(item.ruleName).font(.caption).foregroundStyle(PrismTheme.textTertiary)
                            }
                            .frame(width: 220, alignment: .leading)
                            PlanSummary(plan: item.plan)
                            Spacer()
                            Button(tr("Apply", "Appliquer")) { engine.filePending([item.id]) }
                                .buttonStyle(.bordered)
                                .prismClickable()
                            Button { engine.dismissPending(item.id) } label: { Image(systemName: "xmark") }
                                .buttonStyle(.borderless)
                                .help(tr("Leave this file as it is", "Laisser ce fichier tel quel"))
                                .prismClickable()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        Rectangle().fill(PrismTheme.borderSubtle).frame(height: 1)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(PrismTheme.wash.opacity(0.04)))
            }
            errorLine
        }
    }

    // MARK: - History

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("History", "Historique")).font(.title2.weight(.semibold))
                Text(tr("Every rename and move, newest first. Undo puts the file back under its old name.",
                        "Chaque renommage et déplacement, du plus récent au plus ancien. Annuler remet le fichier à sa place, sous son ancien nom."))
                    .font(.callout).foregroundStyle(PrismTheme.textSecondary)
            }
            if engine.activity.isEmpty {
                Label(tr("No changes yet.", "Aucun changement pour l’instant."), systemImage: "clock")
                    .foregroundStyle(PrismTheme.textTertiary)
            }
            VStack(spacing: 0) {
                ForEach(engine.activity) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.isUndone ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                            .foregroundStyle(entry.isUndone ? PrismTheme.textTertiary : Color.green)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(entry.fileName).lineLimit(1).foregroundStyle(PrismTheme.textSecondary)
                                if let newName = entry.newName, newName != entry.fileName {
                                    Image(systemName: "arrow.right").font(.caption).foregroundStyle(PrismTheme.textTertiary)
                                    Text(newName).fontWeight(.semibold).lineLimit(1)
                                }
                            }
                            Text(historyCaption(entry)).font(.caption).foregroundStyle(PrismTheme.textTertiary)
                        }
                        Spacer()
                        if let path = entry.toPath, !entry.isUndone {
                            Button(tr("Show", "Afficher")) { onReveal(path) }
                                .buttonStyle(.borderless)
                                .prismClickable()
                            Button(tr("Undo", "Annuler")) { engine.undo(activityID: entry.id) }
                                .buttonStyle(.bordered)
                                .prismClickable()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    Rectangle().fill(PrismTheme.borderSubtle).frame(height: 1)
                }
            }
            errorLine
        }
    }

    private func historyCaption(_ entry: RuleActivity) -> String {
        var parts = [entry.ruleName, entry.date.formatted(date: .abbreviated, time: .shortened)]
        if !entry.answeredBy.isEmpty { parts.append(tr("read by \(entry.answeredBy)", "lu par \(entry.answeredBy)")) }
        if entry.isUndone { parts.append(tr("undone", "annulé")) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var errorLine: some View {
        if let error = engine.lastError {
            HStack {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(PrismTheme.accentSecondary)
                Text(error).font(.caption).foregroundStyle(PrismTheme.textSecondary)
                Spacer()
                Button(tr("Dismiss", "Fermer")) { engine.lastError = nil }.buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Describe

    private var describeSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Describe a rule", "Décrire une règle")).font(.title3.weight(.semibold))
            Text(tr("For example: “PDF contracts from Downloads go to Contracts, by year, named after the company and the date.”",
                    "Par exemple : « Les contrats PDF des Téléchargements vont dans Contrats, par année, nommés d’après la société et la date. »"))
                .font(.callout)
                .foregroundStyle(.secondary)
            TextEditor(text: $describeText)
                .font(.body)
                .frame(minHeight: 90)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            Text(tr("\(intelligence.status.readerName) drafts it. \(intelligence.status.line) The new rule starts paused.",
                    "\(intelligence.status.readerName) la rédige. \(intelligence.status.line) La nouvelle règle démarre en pause."))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(tr("Cancel", "Annuler")) { showDescribe = false }
                Button(isDrafting ? tr("Drafting…", "Rédaction…") : tr("Draft rule", "Rédiger la règle")) {
                    isDrafting = true
                    let text = describeText
                    Task {
                        let rule = await engine.draftRule(from: text)
                        engine.addRule(rule)
                        selection = .rule(rule.id)
                        isDrafting = false
                        showDescribe = false
                        describeText = ""
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(describeText.trimmingCharacters(in: .whitespaces).isEmpty || isDrafting)
            }
        }
        .padding(22)
        .frame(width: 480)
    }
}

// MARK: - One rule

struct RuleEditorView: View {
    let rule: FolderRule
    let position: Int
    @ObservedObject var engine: FolderRuleEngine
    @ObservedObject var intelligence: IntelligenceCenter
    let folders: [FolderBookmark]
    let destinations: [DestinationBookmark]
    let onAddWatchedFolder: () async -> String?
    let onAddDestination: () async -> String?
    let onOpenSettings: () -> Void
    let onDelete: () -> Void

    @State private var name = ""
    @State private var editing: EditTarget?
    @State private var draft = ""
    @State private var newField = ""
    @State private var showAllRows = false
    @FocusState private var nameFocused: Bool

    enum EditTarget: String, Identifiable {
        case extensions, nameContains, nameExcludes, check, rename, subfolder, tag
        var id: String { rawValue }
    }

    /// One colour per part of the rule. Same type size everywhere: colour alone tells the parts apart.
    private enum Part {
        case when, read, rename, file, tag
        var color: Color {
            switch self {
            case .when: .blue
            case .read: .purple
            case .rename: .teal
            case .file: .orange
            case .tag: .pink
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            ruleBlock
            addRow
            modeRow
            Rectangle().fill(PrismTheme.borderSubtle).frame(height: 1)
            preview
        }
        .popover(item: $editing) { target in editor(target) }
        .onAppear { name = rule.name }
    }

    private func update(_ change: (inout FolderRule) -> Void) {
        guard var current = engine.rule(id: rule.id) else { return }
        change(&current)
        engine.update(current)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            TextField(tr("Rule name", "Nom de la règle"), text: $name)
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))
                .focused($nameFocused)
                .onSubmit(commitName)
                .onChange(of: nameFocused) { _, focused in if !focused { commitName() } }
            Spacer()
            Text(rule.isEnabled ? tr("On", "Active") : tr("Off", "En pause"))
                .font(.subheadline)
                .foregroundStyle(PrismTheme.textSecondary)
            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { engine.setEnabled($0, ruleID: rule.id) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(rule.watchedFolderID == nil || !rule.hasAction)
                .help(rule.hasAction ? tr("Switch the rule on or off", "Activer ou mettre en pause") : tr("Add a rename, a folder or a tag first", "Ajoutez d’abord un renommage, un dossier ou une étiquette"))
            Menu {
                Button(tr("Duplicate", "Dupliquer")) { engine.duplicate(ruleID: rule.id) }
                Button(tr("Move up", "Monter")) { engine.moveRule(id: rule.id, by: -1) }.disabled(position == 1)
                Button(tr("Move down", "Descendre")) { engine.moveRule(id: rule.id, by: 1) }.disabled(position == engine.rules.count)
                Divider()
                Button(tr("Delete rule", "Supprimer la règle"), role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28)
            .prismClickable()
        }
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed != rule.name { update { $0.name = trimmed } }
    }

    // MARK: The rule, in four lines

    private var ruleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            line(.when) { whenLine }
            if rule.needsReading || rule.check != nil {
                line(.read) { readLine }
            }
            if let template = rule.renameTemplate, !template.isEmpty {
                line(.rename) {
                    word(tr("Rename it to", "Le renommer en"), lead: .rename)
                    token(template, .rename) { draft = template; editing = .rename }
                }
            }
            if rule.destinationID != nil {
                line(.file) { fileLine }
            }
            if !rule.tags.isEmpty {
                line(.tag) {
                    word(tr("Tag it", "L’étiqueter"), lead: .tag)
                    ForEach(rule.tags, id: \.self) { tag in
                        menuToken(tag, .tag) {
                            Button(tr("Remove tag", "Retirer l’étiquette"), role: .destructive) { update { $0.tags.removeAll { $0 == tag } } }
                        }
                    }
                }
            }
        }
        .font(.title3)
    }

    /// A coloured mark on the left, then the words of the line, wrapping like a paragraph.
    private func line<Content: View>(_ part: Part, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(part.color)
                .frame(width: 4, height: 24)
                .padding(.top, 2)
            WrapLayout(spacing: 6, lineSpacing: 6) { content() }
        }
    }

    private func word(_ text: String, lead: Part? = nil) -> some View {
        Text(text)
            .font(.title3)
            .foregroundStyle(lead.map { $0.color } ?? PrismTheme.textSecondary)
            .padding(.vertical, 2)
    }

    /// An editable value: the part's colour and a dotted underline. No chip, no other type size.
    private func tokenLabel(_ text: String, _ part: Part, placeholder: Bool = false) -> some View {
        // The size is set here, not inherited: menu labels ignore the surrounding font on macOS.
        Text(text)
            .font(.title3.weight(.medium))
            .foregroundStyle(placeholder ? PrismTheme.textTertiary : part.color)
            .underline(true, pattern: .dot, color: part.color.opacity(0.55))
            .padding(.vertical, 2)
    }

    private func token(_ text: String, _ part: Part, placeholder: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { tokenLabel(text, part, placeholder: placeholder) }
            .buttonStyle(PrismHandButtonStyle())
    }

    private func menuToken<Items: View>(_ text: String, _ part: Part, placeholder: Bool = false, @ViewBuilder items: () -> Items) -> some View {
        Menu { items() } label: { tokenLabel(text, part, placeholder: placeholder) }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .tint(part.color)
            .fixedSize()
            .prismClickable()
    }

    @ViewBuilder
    private var whenLine: some View {
        word(tr("When", "Quand"), lead: .when)
        word(tr("a new file arrives in", "un nouveau fichier arrive dans"))
        menuToken(engine.folderName(for: rule) ?? tr("a folder", "un dossier"), .when, placeholder: rule.watchedFolderID == nil) {
            ForEach(folders) { folder in
                Button(folder.displayName) { update { $0.watchedFolderID = folder.id } }
            }
            Divider()
            Button(tr("Choose a folder…", "Choisir un dossier…")) {
                Task { if let id = await onAddWatchedFolder() { update { $0.watchedFolderID = id } } }
            }
            Toggle(tr("Include subfolders", "Inclure les sous-dossiers"), isOn: Binding(
                get: { rule.includeSubfolders },
                set: { value in update { $0.includeSubfolders = value } }
            ))
        }
        ForEach(rule.conditions) { condition in
            word(tr("and", "et"))
            menuToken(condition.phrase, .when) {
                switch condition {
                case .extensions(let list):
                    Button(tr("Change types…", "Changer les types…")) { draft = list.joined(separator: ", "); editing = .extensions }
                case .nameContains(let text):
                    Button(tr("Change text…", "Changer le texte…")) { draft = text; editing = .nameContains }
                case .nameExcludes(let text):
                    Button(tr("Change text…", "Changer le texte…")) { draft = text; editing = .nameExcludes }
                default:
                    EmptyView()
                }
                Button(tr("Remove", "Retirer"), role: .destructive) { update { $0.conditions.removeAll { $0 == condition } } }
            }
        }
    }

    @ViewBuilder
    private var readLine: some View {
        let status = intelligence.status
        menuToken(status.readerName, .read) {
            Text(status.line)
            Divider()
            Button(tr("Choose who reads files…", "Choisir qui lit les fichiers…"), action: onOpenSettings)
        }
        if let check = rule.check, !check.isEmpty {
            word(tr("reads it to check it’s", "le lit pour vérifier que c’est"))
            token(check, .read) { draft = check; editing = .check }
        } else {
            word(tr("reads it", "le lit"))
        }
        word(rule.fields.isEmpty ? "" : tr("and notes", "et note"))
        ForEach(rule.fields, id: \.self) { field in
            menuToken(field, .read) {
                Button(tr("Remove", "Retirer"), role: .destructive) { update { $0.fields.removeAll { $0 == field } } }
            }
        }
        TextField(tr("+ value", "+ valeur"), text: $newField)
            .textFieldStyle(.plain)
            .font(.title3)
            .foregroundStyle(Part.read.color)
            .frame(width: 90)
            .padding(.vertical, 4)
            .onSubmit {
                let value = newField.trimmingCharacters(in: .whitespaces)
                if !value.isEmpty, !rule.fields.contains(value) { update { $0.fields.append(value) } }
                newField = ""
            }
    }

    @ViewBuilder
    private var fileLine: some View {
        word(tr("Put it in", "Le ranger dans"), lead: .file)
        menuToken(engine.destinationName(for: rule) ?? tr("a folder", "un dossier"), .file) {
            ForEach(destinations) { destination in
                Button(destination.displayName) { update { $0.destinationID = destination.id } }
            }
            Divider()
            Button(tr("Choose a folder…", "Choisir un dossier…")) {
                Task { if let id = await onAddDestination() { update { $0.destinationID = id } } }
            }
            Button(tr("Leave it where it is", "Le laisser où il est"), role: .destructive) { update { $0.destinationID = nil } }
        }
        ForEach(Array(rule.destinationSubpath.split(separator: "/").enumerated()), id: \.offset) { _, part in
            word("›")
            token(String(part), .file) { draft = rule.destinationSubpath; editing = .subfolder }
        }
        if rule.destinationSubpath.isEmpty {
            token(tr("+ subfolder", "+ sous-dossier"), .file, placeholder: true) { draft = ""; editing = .subfolder }
        }
        if rule.freeUpSpace {
            word(tr(", then frees up space once it’s in iCloud", ", puis libère l’espace une fois dans iCloud"))
        }
    }

    // MARK: Add a condition, add a step

    private var addRow: some View {
        HStack(spacing: 18) {
            Text(tr("Add", "Ajouter")).foregroundStyle(PrismTheme.textTertiary)
            Menu(tr("a condition", "une condition")) {
                Button(tr("File type…", "Type de fichier…")) { draft = ""; editing = .extensions }
                Menu(tr("Kind", "Genre")) {
                    Button(tr("Photo", "Photo")) { update { $0.conditions.append(.kind(.image)) } }
                    Button(tr("Video", "Vidéo")) { update { $0.conditions.append(.kind(.video)) } }
                    Button(tr("Audio", "Audio")) { update { $0.conditions.append(.kind(.audio)) } }
                    Button(tr("Document", "Document")) { update { $0.conditions.append(.kind(.document)) } }
                }
                Button(tr("Name contains…", "Le nom contient…")) { draft = ""; editing = .nameContains }
                Button(tr("Name doesn’t contain…", "Le nom ne contient pas…")) { draft = ""; editing = .nameExcludes }
                Menu(tr("Size", "Taille")) {
                    Button(tr("Over 100 MB", "Plus de 100 Mo")) { update { $0.conditions.append(.largerThan(100 << 20)) } }
                    Button(tr("Over 1 GB", "Plus de 1 Go")) { update { $0.conditions.append(.largerThan(1 << 30)) } }
                    Button(tr("Under 1 MB", "Moins de 1 Mo")) { update { $0.conditions.append(.smallerThan(1 << 20)) } }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            Menu(tr("a step", "une étape")) {
                Button(tr("Check what it is…", "Vérifier ce que c’est…")) { draft = rule.check ?? ""; editing = .check }
                Button(tr("Rename it…", "Le renommer…")) { draft = rule.renameTemplate ?? "{name}"; editing = .rename }
                if rule.destinationID == nil {
                    Menu(tr("Put it in", "Le ranger dans")) {
                        ForEach(destinations) { destination in
                            Button(destination.displayName) { update { $0.destinationID = destination.id } }
                        }
                        Button(tr("Choose a folder…", "Choisir un dossier…")) {
                            Task { if let id = await onAddDestination() { update { $0.destinationID = id } } }
                        }
                    }
                } else {
                    Toggle(tr("Free up space once it’s in iCloud", "Libérer l’espace une fois dans iCloud"), isOn: Binding(
                        get: { rule.freeUpSpace },
                        set: { value in update { $0.freeUpSpace = value } }
                    ))
                }
                Button(tr("Tag it…", "L’étiqueter…")) { draft = ""; editing = .tag }
                Divider()
                if rule.check != nil {
                    Button(tr("Stop checking", "Ne plus vérifier"), role: .destructive) { update { $0.check = nil } }
                }
                if rule.renameTemplate != nil {
                    Button(tr("Keep the name", "Garder le nom"), role: .destructive) { update { $0.renameTemplate = nil } }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .font(.subheadline)
        .tint(PrismTheme.accent)
    }

    private var modeRow: some View {
        HStack(spacing: 10) {
            Text(tr("New matching files:", "Nouveaux fichiers retenus :"))
                .foregroundStyle(PrismTheme.textSecondary)
                .fixedSize()
            Picker("", selection: Binding(get: { rule.mode }, set: { value in update { $0.mode = value } })) {
                ForEach(FolderRule.RunMode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)
        }
        .font(.subheadline)
    }

    // MARK: Editors

    private func editor(_ target: EditTarget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(editorTitle(target)).font(.headline)
            TextField(editorPlaceholder(target), text: $draft, onCommit: { commit(target) })
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
            if target == .rename || target == .subfolder {
                Text(tr("Values: \(tokenHint)", "Valeurs : \(tokenHint)")).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button(tr("Cancel", "Annuler")) { editing = nil }
                Button(tr("Done", "OK")) { commit(target) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
    }

    private var tokenHint: String {
        (rule.fields.map { "{\(JudgementPrompt.fieldKey($0))}" } + ["{year}", "{month}", "{day}", "{name}"]).joined(separator: " ")
    }

    private func editorTitle(_ target: EditTarget) -> String {
        switch target {
        case .extensions: tr("File types", "Types de fichier")
        case .nameContains: tr("Name contains", "Le nom contient")
        case .nameExcludes: tr("Name doesn’t contain", "Le nom ne contient pas")
        case .check: tr("It should be…", "Ce doit être…")
        case .rename: tr("New name", "Nouveau nom")
        case .subfolder: tr("Subfolders", "Sous-dossiers")
        case .tag: tr("Finder tag", "Étiquette Finder")
        }
    }

    private func editorPlaceholder(_ target: EditTarget) -> String {
        switch target {
        case .extensions: "pdf, docx"
        case .nameContains, .nameExcludes: "Screenshot"
        case .check: tr("an invoice or receipt", "une facture ou un reçu")
        case .rename: "{vendor} {date}"
        case .subfolder: tr("Invoices/{year}", "Factures/{year}")
        case .tag: tr("Accounting", "Comptabilité")
        }
    }

    private func commit(_ target: EditTarget) {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        update { rule in
            switch target {
            case .extensions:
                rule.conditions.removeAll { if case .extensions = $0 { return true } else { return false } }
                if !list.isEmpty {
                    rule.conditions.insert(.extensions(list.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) }), at: 0)
                }
            case .nameContains:
                if !value.isEmpty { rule.conditions.append(.nameContains(value)) }
            case .nameExcludes:
                if !value.isEmpty { rule.conditions.append(.nameExcludes(value)) }
            case .check:
                rule.check = value.isEmpty ? nil : value
            case .rename:
                rule.renameTemplate = value.isEmpty ? nil : value
            case .subfolder:
                rule.destinationSubpath = value
            case .tag:
                if !value.isEmpty, !rule.tags.contains(value) { rule.tags.append(value) }
            }
        }
        editing = nil
    }

    // MARK: Preview

    @ViewBuilder
    private var preview: some View {
        let preview = engine.previews[rule.id] ?? .empty
        let matching = preview.rows.filter { if case .doesNotFit = $0.status { return false } else { return true } }
        let others = preview.rows.filter { if case .doesNotFit = $0.status { return true } else { return false } }
        let shownOthers = showAllRows ? others : Array(others.prefix(max(0, 6 - matching.count)))
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(tr("Already in \(preview.folderName.isEmpty ? "the folder" : preview.folderName)",
                        "Déjà dans \(preview.folderName.isEmpty ? "le dossier" : preview.folderName)"))
                    .font(.headline)
                Text(preview.isLoading ? tr("Looking…", "Recherche…") : tr("\(preview.fitCount) match", "\(preview.fitCount) retenu(s)"))
                    .font(.subheadline)
                    .foregroundStyle(PrismTheme.textTertiary)
                Spacer()
                Button { engine.refreshPreview(ruleID: rule.id) } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help(tr("Look again", "Regarder à nouveau"))
                    .prismClickable()
                if preview.fitCount > 0, rule.hasAction {
                    Button(tr("File these \(preview.fitCount) now", "Ranger ces \(preview.fitCount) maintenant")) { engine.fileFittingRows(ruleID: rule.id) }
                        .buttonStyle(.bordered)
                        .prismClickable()
                }
            }
            if let problem = preview.problem {
                Text(problem).foregroundStyle(PrismTheme.accentSecondary).font(.callout)
            }
            if !preview.rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(matching + shownOthers) { item in
                        previewRow(item)
                        Rectangle().fill(PrismTheme.borderSubtle).frame(height: 1)
                    }
                    if others.count > shownOthers.count {
                        Button(tr("\(others.count - shownOthers.count) other files don’t match", "\(others.count - shownOthers.count) autres fichiers ne correspondent pas")) { showAllRows = true }
                            .buttonStyle(.borderless)
                            .foregroundStyle(PrismTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .prismClickable()
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(PrismTheme.wash.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(PrismTheme.borderSubtle))
            }
            if preview.unreadCount > 0, !engine.busyRuleIDs.contains(rule.id) {
                Button(tr("Read \(min(preview.unreadCount, engine.previewReadLimit)) more", "En lire \(min(preview.unreadCount, engine.previewReadLimit)) de plus")) { engine.readMore(ruleID: rule.id) }
                    .buttonStyle(.bordered)
                    .prismClickable()
            }
            Text(footer)
                .font(.callout)
                .foregroundStyle(PrismTheme.textTertiary)
        }
    }

    private var footer: String {
        if !rule.isEnabled {
            return tr("Nothing has been touched. Once the rule is on, new files that match are handled as chosen above. Any change can be undone in History.",
                      "Rien n’a été touché. Une fois la règle active, les nouveaux fichiers retenus sont traités comme choisi ci-dessus. Tout changement s’annule dans l’Historique.")
        }
        return rule.mode == .askFirst
            ? tr("On. New files that match wait in To review for your yes. Any change can be undone in History.",
                 "Active. Les nouveaux fichiers retenus attendent votre accord dans À valider. Tout changement s’annule dans l’Historique.")
            : tr("On. New files that match are filed as soon as they finish arriving. Any change can be undone in History.",
                 "Active. Les nouveaux fichiers retenus sont rangés dès leur arrivée complète. Tout changement s’annule dans l’Historique.")
    }

    private func previewRow(_ item: RulePreviewRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: item))
                .foregroundStyle(PrismTheme.textSecondary)
                .frame(width: 18)
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 250, alignment: .leading)
                .foregroundStyle(item.fits ? PrismTheme.textPrimary : PrismTheme.textTertiary)
            switch item.status {
            case .fits(let plan):
                PlanSummary(plan: plan)
            case .doesNotFit(let reason):
                Text(reason).foregroundStyle(PrismTheme.textTertiary).lineLimit(1)
            case .waitingToRead:
                Text(tr("Not read yet", "Pas encore lu")).foregroundStyle(PrismTheme.textTertiary)
            case .reading:
                ProgressView().controlSize(.mini)
                Text(tr("\(intelligence.status.readerName) is reading…", "\(intelligence.status.readerName) lit…")).foregroundStyle(PrismTheme.textTertiary)
            case .cloudOnly:
                Label(tr("In iCloud only, not downloaded", "Dans iCloud seulement, non téléchargé"), systemImage: "icloud")
                    .foregroundStyle(PrismTheme.textTertiary)
                Button(tr("Download", "Télécharger")) { engine.requestDownload(path: item.path) }
                    .buttonStyle(.borderless)
                    .prismClickable()
            case .stillArriving:
                Text(tr("Still downloading", "Téléchargement en cours")).foregroundStyle(PrismTheme.textTertiary)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(PrismTheme.accentSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func icon(for item: RulePreviewRow) -> String {
        switch item.kind {
        case .image: "photo"
        case .video: "film"
        case .audio: "waveform"
        case .document: "doc.text"
        case nil: "shippingbox"
        }
    }
}

/// Where a file will end up: the folder path in small type, the new name in bold.
struct PlanSummary: View {
    let plan: RulePlan

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.turn.down.right").font(.caption).foregroundStyle(PrismTheme.accent)
            Text(plan.destinationLabel.replacingOccurrences(of: " › ", with: "/") + "/")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(PrismTheme.textTertiary)
                .lineLimit(1)
                .truncationMode(.head)
            Text(plan.newName)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

/// Lays children out left to right and wraps onto new lines.
struct WrapLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: min(proposal.width ?? width, width), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let last = rows[rows.count - 1]
            let needed = last.indices.isEmpty ? size.width : last.width + spacing + size.width
            if needed > width, !last.indices.isEmpty { rows.append(Row()) }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
