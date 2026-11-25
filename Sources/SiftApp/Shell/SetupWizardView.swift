#if os(macOS)
import SiftCore
import SiftDesign
import SwiftUI

/// First-run setup: language and look, folders to catalog, where tidied files go, who reads files,
/// a first rule for Downloads, then a start page with the main things Sift does.
/// Every step can be skipped and the whole setup can be run again from Settings.
struct SetupWizardView: View {
    @ObservedObject var session: SiftRootSession
    @ObservedObject private var bookmarks: BookmarkStore
    @ObservedObject private var destinations: DestinationStore
    @ObservedObject private var intelligence: IntelligenceCenter
    @ObservedObject private var appearance = PrismAppearanceStore.shared

    @State private var step: Step = .welcome
    @State private var chosenTemplates: Set<FolderRuleTemplate> = [.invoices]
    @State private var rulesCreated = false

    enum Step: Int, CaseIterable {
        case welcome, folders, destination, reader, rules, start

        var title: String {
            switch self {
            case .welcome: tr("Welcome", "Bienvenue")
            case .folders: tr("Folders", "Dossiers")
            case .destination: tr("Destination", "Destination")
            case .reader: tr("Reading", "Lecture")
            case .rules: tr("Downloads", "Téléchargements")
            case .start: tr("Start", "Démarrer")
            }
        }
    }

    init(session: SiftRootSession) {
        self.session = session
        #if DEBUG
        if let raw = SiftRuntime.defaults.string(forKey: "siftSetupStep"),
           let index = Int(raw), let initial = Step(rawValue: index) {
            _step = State(initialValue: initial)
        }
        #endif
        _bookmarks = ObservedObject(wrappedValue: session.bookmarkStore)
        _destinations = ObservedObject(wrappedValue: session.destinationStore)
        _intelligence = ObservedObject(wrappedValue: session.intelligence)
    }

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.top, 26)
                .padding(.horizontal, 40)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    content
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            footer
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(PrismTheme.surfaceMuted.opacity(0.4))
        }
        .background(PrismTheme.dominantGradient.ignoresSafeArea())
        .foregroundStyle(PrismTheme.textPrimary)
        .tint(PrismTheme.accent)
        .onChange(of: session.setupStepRequest) { _, request in
            if let request, let target = Step(rawValue: request) {
                withAnimation(PrismMotion.quick) { step = target }
            }
        }
    }

    // MARK: - Chrome

    private var progress: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.self) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? PrismTheme.accent : PrismTheme.wash.opacity(0.12))
                        .frame(height: 4)
                    Text(item.title)
                        .font(.caption2.weight(item == step ? .semibold : .regular))
                        .foregroundStyle(item == step ? PrismTheme.textPrimary : PrismTheme.textTertiary)
                }
                .onTapGesture { step = item }
            }
        }
    }

    private var footer: some View {
        HStack {
            if step != .welcome {
                Button(tr("Back", "Retour")) { move(-1) }
                    .keyboardShortcut(.cancelAction)
            } else {
                Button(tr("Skip setup", "Passer la configuration")) {
                    session.finishSetup(startScan: false, openMode: nil)
                }
            }
            Spacer()
            if step != .start {
                if step != .welcome {
                    Button(tr("Skip this step", "Passer cette étape")) { move(1) }
                        .buttonStyle(.borderless)
                        .foregroundStyle(PrismTheme.textSecondary)
                }
                Button(tr("Continue", "Continuer")) {
                    if step == .rules { createRules() }
                    move(1)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
    }

    private func move(_ delta: Int) {
        var next = step.rawValue + delta
        // The Downloads rule step only makes sense once a Downloads folder is saved.
        if Step(rawValue: next) == .rules, downloadsBookmark == nil {
            next += delta
        }
        if let target = Step(rawValue: next) {
            withAnimation(PrismMotion.quick) { step = target }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .folders: folders
        case .destination: destination
        case .reader: reader
        case .rules: rules
        case .start: start
        }
    }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 30, weight: .bold))
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(PrismTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) { content() }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .prismGlass(cornerRadius: 18, padding: 0)
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading(
                tr("Sift tidies your Mac, without surprises.", "Sift range votre Mac, sans surprise."),
                tr("It finds your photos, videos, music and documents where they are, lets you search them by what they show, and files new downloads with rules you can read. Nothing moves until you say so, and every move can be undone.",
                   "Il retrouve vos photos, vidéos, musiques et documents là où ils sont, permet de les chercher par ce qu’ils montrent, et range les nouveaux téléchargements avec des règles lisibles. Rien ne bouge sans votre accord, et tout peut être annulé.")
            )
            HStack(alignment: .top, spacing: 14) {
                feature("sparkle.magnifyingglass", tr("Find", "Trouver"), tr("A catalog of what is already on this Mac.", "Un catalogue de ce qui est déjà sur ce Mac."))
                feature("photo.on.rectangle.angled", tr("Browse", "Parcourir"), tr("Search by what a photo shows, or by its text.", "Cherchez par ce que montre une photo, ou par son texte."))
                feature("wand.and.rays", tr("Tidy", "Ranger"), tr("Rules rename and file new downloads.", "Des règles renomment et rangent les téléchargements."))
            }
            card {
                Text(tr("Language", "Langue")).font(.headline)
                Picker("", selection: $appearance.language) {
                    ForEach(SiftLanguage.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            card {
                Text(tr("Look", "Apparence")).font(.headline)
                PrismAppearancePicker(store: appearance, compact: true)
            }
        }
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(PrismTheme.accentGradient)
            Text(title).font(.headline)
            Text(text)
                .font(.callout)
                .foregroundStyle(PrismTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .prismGlass(cornerRadius: 16, padding: 0)
    }

    private struct Suggestion: Identifiable {
        let id: String
        let name: String
        let icon: String
        let note: String
        var url: URL { SetupWizardView.home.appendingPathComponent(id, isDirectory: true) }
    }

    private var suggestions: [Suggestion] {
        [
            Suggestion(id: "Pictures", name: tr("Pictures", "Images"), icon: "photo", note: tr("Photos and screenshots", "Photos et captures")),
            Suggestion(id: "Downloads", name: tr("Downloads", "Téléchargements"), icon: "arrow.down.circle", note: tr("Where invoices and installers land", "Là où arrivent factures et installeurs")),
            Suggestion(id: "Desktop", name: tr("Desktop", "Bureau"), icon: "menubar.dock.rectangle", note: tr("Often synced with iCloud", "Souvent synchronisé avec iCloud")),
            Suggestion(id: "Documents", name: "Documents", icon: "doc.text", note: tr("PDFs, Office files, notes", "PDF, fichiers Office, notes")),
            Suggestion(id: "Movies", name: tr("Movies", "Vidéos"), icon: "film", note: tr("Videos", "Vidéos")),
            Suggestion(id: "Music", name: tr("Music", "Musique"), icon: "music.note", note: tr("Audio files", "Fichiers audio")),
        ]
    }

    private func savedBookmark(for url: URL) -> FolderBookmark? {
        let target = url.standardizedFileURL.resolvingSymlinksInPath().path
        return bookmarks.folders.first { bookmark in
            (try? bookmarks.resolve(bookmark).standardizedFileURL.resolvingSymlinksInPath().path) == target
        }
    }

    /// The real home folder, or the demo's stand-in during a recording.
    static var home: URL {
        if SiftRuntime.isDemo, let demo = SiftRuntime.defaults.string(forKey: "siftDemoHome") {
            return URL(fileURLWithPath: demo, isDirectory: true)
        }
        return BookmarkStore.userHome
    }

    private var downloadsBookmark: FolderBookmark? {
        savedBookmark(for: SetupWizardView.home.appendingPathComponent("Downloads", isDirectory: true))
            ?? bookmarks.folders.first { $0.displayName.caseInsensitiveCompare("Downloads") == .orderedSame }
    }

    private var folders: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(
                tr("What should Sift look at?", "Que doit regarder Sift ?"),
                tr("Pick the folders to catalog. macOS asks you to confirm each one: the window opens on it, press Add.",
                   "Choisissez les dossiers à cataloguer. macOS demande de confirmer chacun : la fenêtre s’ouvre dessus, appuyez sur Ajouter.")
            )
            VStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    let saved = savedBookmark(for: suggestion.url) != nil
                    HStack(spacing: 14) {
                        Image(systemName: suggestion.icon)
                            .font(.title3)
                            .frame(width: 28)
                            .foregroundStyle(saved ? PrismTheme.accent : PrismTheme.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.name).font(.headline)
                            Text(suggestion.note).font(.caption).foregroundStyle(PrismTheme.textTertiary)
                        }
                        Spacer()
                        if saved {
                            Label(tr("Added", "Ajouté"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline.weight(.semibold))
                        } else {
                            Button(tr("Add…", "Ajouter…")) {
                                Task { _ = await session.addSourceFolder(suggested: suggestion.url) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(PrismTheme.wash.opacity(0.05)))
                }
            }
            HStack {
                Button(tr("Another folder or disk…", "Un autre dossier ou disque…")) {
                    Task { _ = await session.addSourceFolder(suggested: nil) }
                }
                Spacer()
                Text(tr("\(bookmarks.folders.count) saved", "\(bookmarks.folders.count) enregistré(s)"))
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textTertiary)
            }
            note("icloud", tr("Folders synced with iCloud are fine. Sift reads names, sizes and dates only and never downloads a file to look at it.",
                              "Les dossiers synchronisés avec iCloud ne posent pas de problème. Sift lit seulement noms, tailles et dates et ne télécharge jamais un fichier pour le regarder."))
        }
    }

    private var destination: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(
                tr("Where should tidied files go?", "Où ranger les fichiers ?"),
                tr("One folder for everything Sift files: rules put invoices in it, and Organize can sort photos and videos into it. A new folder such as Documents/Sorted works well.",
                   "Un dossier pour tout ce que Sift range : les règles y mettent les factures, et Organiser peut y classer photos et vidéos. Un nouveau dossier comme Documents/Rangé fonctionne bien.")
            )
            card {
                if destinations.destinations.isEmpty {
                    Text(tr("No destination yet.", "Pas encore de destination.")).foregroundStyle(PrismTheme.textSecondary)
                } else {
                    ForEach(destinations.destinations) { dest in
                        HStack {
                            Image(systemName: "externaldrive.fill").foregroundStyle(dest.id == destinations.activeDestinationID ? PrismTheme.accent : PrismTheme.textTertiary)
                            Text(dest.displayName).font(.headline)
                            Spacer()
                            if dest.id == destinations.activeDestinationID {
                                Text(tr("Used by default", "Utilisée par défaut")).font(.caption).foregroundStyle(PrismTheme.accent)
                            } else {
                                Button(tr("Use", "Utiliser")) { destinations.setActive(id: dest.id) }
                            }
                        }
                    }
                }
                Button(destinations.destinations.isEmpty ? tr("Choose a folder…", "Choisir un dossier…") : tr("Choose another folder…", "Choisir un autre dossier…")) {
                    Task {
                        _ = await session.addDestinationFolder(
                            suggested: BookmarkStore.userHome.appendingPathComponent("Documents", isDirectory: true)
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            note("arrow.uturn.backward", tr("Sift only writes inside this folder, and keeps a log so any move can be undone.",
                                             "Sift n’écrit que dans ce dossier, et garde un journal pour pouvoir annuler chaque déplacement."))
        }
    }

    private var reader: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(
                tr("Who reads files for rules?", "Qui lit les fichiers pour les règles ?"),
                tr("To know that a PDF is an invoice and find its vendor, date and amount, a rule reads the start of the file. Choose who does that reading. You can change it any time in Settings.",
                   "Pour savoir qu’un PDF est une facture et trouver fournisseur, date et montant, une règle lit le début du fichier. Choisissez qui fait cette lecture. Modifiable à tout moment dans les Réglages.")
            )
            HStack(alignment: .top, spacing: 12) {
                readerCard(.sift, icon: "lock.laptopcomputer", badge: tr("Private", "Privé"))
                readerCard(.apple, icon: "apple.logo", badge: tr("Private", "Privé"))
                readerCard(.localServer, icon: "server.rack", badge: tr("Your server", "Votre serveur"))
                readerCard(.claude, icon: "sparkles", badge: tr("Online", "En ligne"))
            }
            card {
                IntelligenceSettingsSection(intelligence: intelligence)
            }
        }
    }

    private func readerCard(_ kind: IntelligenceProviderKind, icon: String, badge: String) -> some View {
        let selected = intelligence.settings.provider == kind
        return Button {
            intelligence.settings.provider = kind
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).font(.title3)
                    Spacer()
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(PrismTheme.wash.opacity(0.08)))
                }
                Text(kind.title).font(.headline)
                Text(kind.summary)
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14).fill(PrismTheme.wash.opacity(selected ? 0.10 : 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? PrismTheme.accent : PrismTheme.borderSubtle, lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PrismHandButtonStyle())
    }

    private var rules: some View {
        let destinationName = destinations.activeDestination?.displayName ?? tr("your destination", "votre destination")
        return VStack(alignment: .leading, spacing: 18) {
            heading(
                tr("Tidy Downloads as files arrive?", "Ranger les téléchargements à leur arrivée ?"),
                tr("Pick what Sift should look for in Downloads. These are starting points: every rule can be edited, reordered or deleted, and you can add your own. Files that match wait in Rules › To review until you say yes.",
                   "Choisissez ce que Sift doit repérer dans Téléchargements. Ce sont des points de départ : chaque règle se modifie, se réordonne ou se supprime, et vous pouvez ajouter les vôtres. Les fichiers retenus attendent dans Règles › À valider jusqu’à votre accord.")
            )
            VStack(spacing: 10) {
                ruleChoice(.invoices, icon: "doc.text.magnifyingglass",
                           tr("PDF invoices and receipts", "Factures et reçus en PDF"),
                           tr("Read, renamed “Vendor 2026-11-03.pdf”, filed in \(destinationName) › Invoices › year.",
                              "Lus, renommés « Fournisseur 2026-11-03.pdf », rangés dans \(destinationName) › Factures › année."))
                ruleChoice(.contracts, icon: "signature",
                           tr("Contracts and agreements", "Contrats et accords"),
                           tr("Read, renamed “Company 2026-11-03.pdf”, filed in \(destinationName) › Contracts › year.",
                              "Lus, renommés « Société 2026-11-03.pdf », rangés dans \(destinationName) › Contrats › année."))
                ruleChoice(.screenshots, icon: "camera.viewfinder",
                           tr("Screenshots", "Captures d’écran"),
                           tr("Filed in \(destinationName) › Screenshots › year-month.", "Rangées dans \(destinationName) › Captures › année-mois."))
                ruleChoice(.installers, icon: "shippingbox",
                           tr("Installers and archives (.dmg, .pkg, .zip)", "Installeurs et archives (.dmg, .pkg, .zip)"),
                           tr("Moved to \(destinationName) › Installers.", "Déplacés dans \(destinationName) › Installeurs."))
            }
            if destinations.activeDestination == nil {
                note("exclamationmark.triangle", tr("Choose a destination first (previous step), or the rules will wait without one.",
                                                    "Choisissez d’abord une destination (étape précédente), sinon les règles attendront sans."))
            }
            note(intelligence.status.staysOnDevice ? "lock.laptopcomputer" : "icloud.and.arrow.up", intelligence.status.line)
        }
    }

    private func ruleChoice(_ template: FolderRuleTemplate, icon: String, _ title: String, _ detail: String) -> some View {
        let on = chosenTemplates.contains(template)
        return Button {
            if on { chosenTemplates.remove(template) } else { chosenTemplates.insert(template) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(on ? PrismTheme.accent : PrismTheme.textTertiary)
                Image(systemName: icon).font(.title3).frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(detail).font(.callout).foregroundStyle(PrismTheme.textSecondary)
                }
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(PrismTheme.wash.opacity(on ? 0.08 : 0.04)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PrismHandButtonStyle())
    }

    private func createRules() {
        guard !rulesCreated, let downloads = downloadsBookmark else { return }
        rulesCreated = true
        for template in FolderRuleTemplate.allCases where chosenTemplates.contains(template) {
            var rule = template.make(watchedFolderID: downloads.id, destinationID: destinations.activeDestinationID)
            rule.isEnabled = rule.hasAction
            rule.mode = .askFirst
            session.folderRules.addRule(rule)
        }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading(
                tr("You’re set.", "C’est prêt."),
                tr("Start with a scan of the folders you picked, or jump straight to what you came for.",
                   "Commencez par scanner les dossiers choisis, ou allez directement à ce qui vous intéresse.")
            )
            card {
                summaryRow("folder", tr("Folders", "Dossiers"), bookmarks.folders.isEmpty ? tr("None yet", "Aucun pour l’instant") : bookmarks.folders.map(\.displayName).joined(separator: ", "))
                summaryRow("externaldrive", tr("Destination", "Destination"), destinations.activeDestination?.displayName ?? tr("None yet", "Aucune pour l’instant"))
                summaryRow("text.viewfinder", tr("Reading", "Lecture"), intelligence.status.readerName)
                summaryRow("wand.and.rays", tr("Rules", "Règles"), session.folderRules.rules.isEmpty ? tr("None yet", "Aucune pour l’instant") : session.folderRules.rules.map(\.name).joined(separator: ", "))
            }
            if !bookmarks.folders.isEmpty {
                Button {
                    session.finishSetup(startScan: true, openMode: .sources)
                } label: {
                    Label(tr("Scan my folders now", "Scanner mes dossiers maintenant"), systemImage: "sparkle.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            Text(tr("Or go to", "Ou aller à")).font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                shortcut("photo.on.rectangle.angled", tr("My library", "Ma bibliothèque"), tr("Browse and search what is cataloged.", "Parcourir et chercher dans le catalogue."), .library)
                shortcut("wand.and.rays", tr("Rules", "Règles"), tr("See where each download would go.", "Voir où irait chaque téléchargement."), .rules)
                shortcut("arrow.left.arrow.right.square", tr("Organize", "Organiser"), tr("Sort photos and videos into the destination.", "Classer photos et vidéos dans la destination."), .organize)
                shortcut("sparkles", tr("Duplicates and people", "Doublons et personnes"), tr("Review groups Sift found.", "Revoir les groupes trouvés par Sift."), .review)
            }
        }
    }

    private func summaryRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(PrismTheme.accent)
            Text(title).font(.subheadline.weight(.semibold)).frame(width: 110, alignment: .leading)
            Text(value).font(.subheadline).foregroundStyle(PrismTheme.textSecondary)
            Spacer(minLength: 0)
        }
    }

    private func shortcut(_ icon: String, _ title: String, _ detail: String, _ mode: AppMode) -> some View {
        Button {
            session.finishSetup(startScan: false, openMode: mode)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title2).foregroundStyle(PrismTheme.accentGradient).frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(detail).font(.caption).foregroundStyle(PrismTheme.textSecondary).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(PrismTheme.textTertiary)
            }
            .padding(14)
            .prismGlass(cornerRadius: 14, padding: 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(PrismHandButtonStyle())
    }

    private func note(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(PrismTheme.textTertiary)
            Text(text)
                .font(.callout)
                .foregroundStyle(PrismTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
