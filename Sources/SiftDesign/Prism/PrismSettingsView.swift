import SiftCore
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// The pages of the Settings panel, in sidebar order.
public enum SettingsPage: String, CaseIterable, Identifiable, Sendable {
    case general
    case folders
    case reading
    case organizing
    case search
    case updates
    case maintenance

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: tr("General", "Général")
        case .folders: tr("Folders", "Dossiers")
        case .reading: tr("Reading files", "Lecture des fichiers")
        case .organizing: tr("Organizing", "Rangement")
        case .search: tr("Search", "Recherche")
        case .updates: tr("Updates", "Mises à jour")
        case .maintenance: tr("Maintenance", "Maintenance")
        }
    }

    public var icon: String {
        switch self {
        case .general: "paintpalette"
        case .folders: "folder"
        case .reading: "text.viewfinder"
        case .organizing: "arrow.left.arrow.right.square"
        case .search: "magnifyingglass"
        case .updates: "arrow.down.circle"
        case .maintenance: "wrench.and.screwdriver"
        }
    }
}

/// Settings, drawn over the main window with a sidebar and a Back button.
public struct PrismSettingsView: View {
    let folders: [FolderBookmark]
    let destinations: [DestinationBookmark]
    let activeDestinationID: String?
    @Binding var transferMode: FileTransferMode
    @Binding var watchSourceFolders: Bool
    let recentTransfers: [TransferRecord]
    let onAddFolder: () -> Void
    let onRemoveFolder: (String) -> Void
    let onScanFolder: (String) -> Void
    let onSetIncludeSubfolders: (String, Bool) -> Void
    let onRescanSources: () -> Void
    let onStartAITagging: () -> Void
    let onUndoTransfer: (TransferRecord) -> Void
    let onFactoryReset: (Bool, Bool) -> Void
    let intelligence: IntelligenceCenter?
    let onClose: (() -> Void)?
    let onRunSetup: (() -> Void)?
    @State private var page: SettingsPage
    @ObservedObject private var appearance = PrismAppearanceStore.shared
    @State private var jevKey = ""
    @State private var showJevHelp = false
    @State private var confirm: SiftConfirm?
    @State private var showResetChoices = false
    @State private var resetLibrary = false
    @State private var resetSettings = false
    @State private var showPageHelp = false
    @State private var jevSaved = false
    @ObservedObject private var updates = SiftUpdateCenter.shared

    public init(
        folders: [FolderBookmark],
        destinations: [DestinationBookmark],
        activeDestinationID: String?,
        transferMode: Binding<FileTransferMode>,
        watchSourceFolders: Binding<Bool>,
        recentTransfers: [TransferRecord],
        onAddFolder: @escaping () -> Void,
        onRemoveFolder: @escaping (String) -> Void,
        onScanFolder: @escaping (String) -> Void = { _ in },
        onSetIncludeSubfolders: @escaping (String, Bool) -> Void = { _, _ in },
        onRescanSources: @escaping () -> Void,
        onStartAITagging: @escaping () -> Void,
        onUndoTransfer: @escaping (TransferRecord) -> Void,
        onFactoryReset: @escaping (Bool, Bool) -> Void,
        intelligence: IntelligenceCenter? = nil,
        initialPage: SettingsPage = .general,
        onClose: (() -> Void)? = nil,
        onRunSetup: (() -> Void)? = nil
    ) {
        self.intelligence = intelligence
        self.onClose = onClose
        self.onRunSetup = onRunSetup
        _page = State(initialValue: initialPage)
        self.folders = folders
        self.destinations = destinations
        self.activeDestinationID = activeDestinationID
        _transferMode = transferMode
        _watchSourceFolders = watchSourceFolders
        self.recentTransfers = recentTransfers
        self.onAddFolder = onAddFolder
        self.onRemoveFolder = onRemoveFolder
        self.onScanFolder = onScanFolder
        self.onSetIncludeSubfolders = onSetIncludeSubfolders
        self.onRescanSources = onRescanSources
        self.onStartAITagging = onStartAITagging
        self.onUndoTransfer = onUndoTransfer
        self.onFactoryReset = onFactoryReset
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 236)
            Rectangle()
                .fill(PrismTheme.borderSubtle)
                .frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    pageHeader
                    pageContent
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, 36)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
        }
        .background(PrismTheme.dominantGradient.ignoresSafeArea())
        .foregroundStyle(PrismTheme.textPrimary)
        .onAppear {
            jevSaved = JevCredential.isConfigured
            Task { await updates.checkIfNeeded() }
        }
        .onExitCommand { onClose?() }
        .siftConfirming($confirm)
        .sheet(isPresented: $showResetChoices) {
            SiftResetSheet(
                resetLibrary: $resetLibrary,
                resetSettings: $resetSettings,
                onCancel: { showResetChoices = false },
                onConfirm: {
                    let library = resetLibrary
                    let settings = resetSettings
                    showResetChoices = false
                    onFactoryReset(library, settings)
                }
            )
        }
        .sheet(isPresented: $showPageHelp) {
            SiftHelpView(mode: "settings", onClose: { showPageHelp = false })
        }
        .tint(PrismTheme.accent)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let onClose {
                Button(action: onClose) {
                    Label(tr("Back to Sift", "Retour à Sift"), systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(PrismTheme.wash.opacity(0.06)))
                }
                .buttonStyle(PrismHandButtonStyle())
                .keyboardShortcut(.cancelAction)
                .padding(.bottom, 14)
            }
            Text(tr("Settings", "Réglages"))
                .font(.title3.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            ForEach(SettingsPage.allCases) { item in
                Button {
                    page = item
                } label: {
                    Label(item.title, systemImage: item.icon)
                        .font(.subheadline.weight(page == item ? .semibold : .regular))
                        .foregroundStyle(page == item ? PrismTheme.textPrimary : PrismTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(page == item ? PrismTheme.accentSoft : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PrismHandButtonStyle())
            }
            Spacer()
            if let onRunSetup {
                Button(action: onRunSetup) {
                    Label(tr("Run setup again", "Relancer la configuration"), systemImage: "wand.and.stars")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(PrismHandButtonStyle())
                .foregroundStyle(PrismTheme.textSecondary)
            }
            Button {
                showPageHelp = true
            } label: {
                Label(tr("Help", "Aide"), systemImage: "questionmark.circle")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(PrismHandButtonStyle())
            .foregroundStyle(PrismTheme.textSecondary)
        }
        .padding(18)
        .background(PrismTheme.surfaceMuted.opacity(0.35))
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(page.title)
                .font(.largeTitle.weight(.bold))
            Text(pageIntro)
                .font(.callout)
                .foregroundStyle(PrismTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pageIntro: String {
        switch page {
        case .general: tr("Language, colours, light or dark, and how big everything is drawn.", "Langue, couleurs, clair ou sombre, et taille de l’interface.")
        case .folders: tr("The folders Sift catalogs. Files stay where they are.", "Les dossiers que Sift catalogue. Les fichiers restent où ils sont.")
        case .reading: tr("Who reads a file when a rule needs to know what it is, and where that text goes.", "Qui lit un fichier quand une règle doit savoir ce que c’est, et où va ce texte.")
        case .organizing: tr("Where tidied files go, and whether Sift moves or copies them.", "Où vont les fichiers rangés, et si Sift les déplace ou les copie.")
        case .search: tr("Visual search runs on this Mac.", "La recherche visuelle tourne sur ce Mac.")
        case .updates: tr("Sift checks GitHub for new versions.", "Sift vérifie les nouvelles versions sur GitHub.")
        case .maintenance: tr("Rescan, tag, or start over. Your files are never touched.", "Rescanner, étiqueter ou repartir de zéro. Vos fichiers ne sont jamais touchés.")
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .general: generalPage
        case .folders: foldersPage
        case .reading: readingPage
        case .organizing: organizingPage
        case .search: searchPage
        case .updates: updatesSection
        case .maintenance: maintenancePage
        }
    }

    // MARK: - General

    private var generalPage: some View {
        VStack(alignment: .leading, spacing: 28) {
            PrismSettingsSection(title: tr("Language", "Langue"), footer: tr(
                "Screens not yet translated stay in English. Translations are welcome on GitHub.",
                "Les écrans pas encore traduits restent en anglais. Les traductions sont bienvenues sur GitHub."
            )) {
                Picker("", selection: $appearance.language) {
                    ForEach(SiftLanguage.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            PrismSettingsSection(title: tr("Appearance", "Apparence"), footer: nil) {
                PrismAppearancePicker(store: appearance)
            }
            PrismSettingsSection(title: tr("Privacy", "Confidentialité"), footer: tr(
                "Photos, videos, music and documents are read on this Mac. Text only leaves it if you choose Claude, Jev, or a model on another machine.",
                "Photos, vidéos, musique et documents sont lus sur ce Mac. Du texte n’en sort que si vous choisissez Claude, Jev ou un modèle sur une autre machine."
            )) {
                VStack(alignment: .leading, spacing: 12) {
                    privacyRow(tr("Catalog, Vision and CLIP run on this Mac", "Catalogue, Vision et CLIP tournent sur ce Mac"), icon: "lock.shield.fill")
                    privacyRow(tr("Files in iCloud only are never downloaded", "Les fichiers restés dans iCloud ne sont jamais téléchargés"), icon: "icloud.slash")
                }
            }
        }
    }

    // MARK: - Folders

    private var foldersPage: some View {
        VStack(alignment: .leading, spacing: 28) {
            PrismSettingsSection(
                title: tr("Source folders", "Dossiers sources"),
                footer: tr("Folders on your Mac that Sift scans. Files stay in place until you Move or Copy into a destination.",
                           "Les dossiers de votre Mac que Sift scanne. Les fichiers restent en place tant que vous ne les déplacez ou copiez pas.")
            ) {
                FolderSourcesPanel(
                    folders: folders,
                    style: .embedded,
                    onRemove: onRemoveFolder,
                    onScan: onScanFolder,
                    onSetIncludeSubfolders: onSetIncludeSubfolders
                )
                Button(action: onAddFolder) {
                    Label(tr("Add folder…", "Ajouter un dossier…"), systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PrismTheme.accent)
                .prismClickable()
            }
            PrismSettingsSection(
                title: tr("Watching", "Surveillance"),
                footer: tr("New files in source folders are added to the catalog as they arrive. Folder rules that are on watch their folders either way.",
                           "Les nouveaux fichiers des dossiers sources entrent au catalogue dès leur arrivée. Les règles allumées surveillent leurs dossiers dans tous les cas.")
            ) {
                Toggle(tr("Watch source folders", "Surveiller les dossiers sources"), isOn: $watchSourceFolders)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Reading files

    private var readingPage: some View {
        VStack(alignment: .leading, spacing: 28) {
            if let intelligence {
                PrismSettingsSection(
                    title: tr("Who reads files for rules", "Qui lit les fichiers pour les règles"),
                    footer: tr("A rule reads the start of a matching file to check what it is and note values like the vendor or the date. Sift’s own reading needs no model. A local model or Apple Intelligence keeps text on this Mac. Claude sends the start of the text to Anthropic.",
                               "Une règle lit le début d’un fichier pour vérifier ce que c’est et noter des valeurs comme le fournisseur ou la date. La lecture de Sift n’a besoin d’aucun modèle. Un modèle local ou Apple Intelligence garde le texte sur ce Mac. Claude envoie le début du texte à Anthropic.")
                ) {
                    IntelligenceSettingsSection(intelligence: intelligence)
                }
            }
            jevSection
        }
    }

    private var jevSection: some View {
        PrismSettingsSection(
            title: tr("Jev intelligence", "Jev"),
            footer: JevClient.disclosure
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TypeSafe System One")
                        .font(.subheadline.weight(.semibold))
                    Text(tr("Jev makes bounded choices for routing, review priority, and organization proposals. It does not upload media or replace CLIP.",
                            "Jev fait des choix bornés : navigation, priorités de revue, propositions de rangement. Il n’envoie aucun média et ne remplace pas CLIP."))
                        .font(.caption)
                        .foregroundStyle(PrismTheme.textSecondary)
                }
                Spacer()
                Button {
                    showJevHelp.toggle()
                } label: {
                    Label(tr("Why?", "Pourquoi ?"), systemImage: "questionmark.circle")
                }
                .buttonStyle(.bordered)
                .prismClickable()
                .popover(isPresented: $showJevHelp) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("How Jev is used", "Comment Jev est utilisé"))
                            .font(.headline)
                        Text("With a key saved, Jev can classify an assistant command from the phrase, allowed actions, and a short catalog summary. Organization proposals can include filenames, extensions, kinds, source folders, sizes, dates, dimensions, durations, scored labels, and up to three short OCR lines. Document labeling can send opening lines, headings, sheet names, and column headers. Files, photos, video, and audio stay on this Mac. No key, or a failed answer, keeps the on-device result.")
                        Text("Create or copy an API key from your TypeSafe account, paste it below, then choose Save to Keychain.")
                        Link("Open TypeSafe documentation", destination: URL(string: "https://docs.typesafe.ai")!)
                    }
                    .font(.caption)
                    .padding(16)
                    .frame(width: 340)
                }
            }
            HStack {
                SecureField(jevSaved ? tr("Replace stored API key…", "Remplacer la clé enregistrée…") : "Paste TYPESAFE_API_KEY…", text: $jevKey)
                    .textFieldStyle(.roundedBorder)
                Button(tr("Save to Keychain", "Enregistrer dans le trousseau")) {
                    JevCredential.save(jevKey)
                    jevSaved = JevCredential.isConfigured
                    jevKey = ""
                }
                .disabled(jevKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if jevSaved {
                    Button(tr("Remove", "Retirer")) {
                        confirm = SiftConfirm(
                            title: tr("Remove the Jev key?", "Retirer la clé Jev ?"),
                            message: tr("The key is deleted from the Keychain. Routing and document labels then stay on this Mac.",
                                        "La clé est supprimée du trousseau. La navigation et les étiquettes restent alors sur ce Mac."),
                            confirmTitle: tr("Remove key", "Retirer la clé")
                        ) {
                            JevCredential.save("")
                            jevSaved = false
                            jevKey = ""
                        }
                    }
                }
            }
            Label(
                jevSaved ? tr("Configured · credential stored in the macOS Keychain", "Configuré · clé dans le trousseau macOS")
                         : tr("Not configured · local catalog and Vision search still work", "Non configuré · le catalogue et la recherche Vision fonctionnent quand même"),
                systemImage: jevSaved ? "checkmark.shield.fill" : "key.slash"
            )
            .font(.caption)
            .foregroundStyle(jevSaved ? .green : PrismTheme.textTertiary)
        }
    }

    // MARK: - Organizing

    private var organizingPage: some View {
        VStack(alignment: .leading, spacing: 28) {
            PrismSettingsSection(
                title: tr("Destinations", "Destinations"),
                footer: tr("Move or Copy sends files into Photos, Videos, and Gather under the active destination. Rules can use any destination. Add one in Organize or during setup.",
                           "Déplacer ou Copier envoie les fichiers dans Photos, Vidéos et Gather de la destination active. Les règles peuvent utiliser n’importe quelle destination. Ajoutez-en une dans Organiser ou pendant la configuration.")
            ) {
                destinationsContent
            }
            PrismSettingsSection(title: tr("Move or copy", "Déplacer ou copier"), footer: nil) {
                TransferModePicker(mode: $transferMode, style: .prism)
            }
            PrismSettingsSection(
                title: tr("Recent transfers", "Transferts récents"),
                footer: tr("Undo works while the file is still at the destination.", "Annuler fonctionne tant que le fichier est encore à destination.")
            ) {
                if recentTransfers.isEmpty {
                    Text(tr("No transfers yet.", "Aucun transfert pour l’instant."))
                        .font(.caption)
                        .foregroundStyle(PrismTheme.textTertiary)
                } else {
                    ForEach(recentTransfers, id: \.id) { record in
                        transferRow(record)
                    }
                }
            }
        }
    }

    // MARK: - Search

    private var searchPage: some View {
        PrismSettingsSection(
            title: tr("Visual content search", "Recherche par contenu"),
            footer: tr("Exact files, text in images, people, and Vision labels work without CLIP.", "Fichiers exacts, texte dans les images, personnes et labels Vision marchent sans CLIP.")
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Local CLIP model", "Modèle CLIP local"))
                        .font(.subheadline.weight(.semibold))
                    Text(
                        ClipEmbeddingStore.status == .ready
                            ? tr("Model files are on this Mac. Visual search can run locally.", "Le modèle est sur ce Mac. La recherche visuelle tourne en local.")
                            : tr("The model downloads the first time Sift opens. Until then, searches use Vision labels and filenames.", "Le modèle se télécharge au premier lancement. D’ici là, la recherche utilise les labels Vision et les noms de fichiers.")
                    )
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textSecondary)
                }
                Spacer()
                Label(
                    ClipEmbeddingStore.status == .ready ? tr("Ready", "Prêt") : tr("Unavailable", "Indisponible"),
                    systemImage: ClipEmbeddingStore.status == .ready ? "checkmark.circle.fill" : "exclamationmark.triangle"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(ClipEmbeddingStore.status == .ready ? .green : .orange)
            }
        }
    }

    // MARK: - Maintenance

    private var maintenancePage: some View {
        PrismSettingsSection(title: tr("Maintenance", "Maintenance"), footer: nil) {
            VStack(alignment: .leading, spacing: 10) {
                settingsActionButton(tr("Rescan all source folders", "Rescanner tous les dossiers sources"), icon: "arrow.clockwise") {
                    confirm = SiftConfirm(
                        title: tr("Rescan the saved folders?", "Rescanner les dossiers enregistrés ?"),
                        message: tr("Sift walks the folders you already saved and updates the catalog. Files stay where they are.",
                                    "Sift parcourt les dossiers enregistrés et met le catalogue à jour. Les fichiers restent où ils sont."),
                        confirmTitle: tr("Rescan", "Rescanner"),
                        destructive: false,
                        run: onRescanSources
                    )
                }
                settingsActionButton(tr("Start AI tagging", "Lancer l’étiquetage"), icon: "sparkles") {
                    confirm = SiftConfirm(
                        title: tr("Start tagging?", "Lancer l’étiquetage ?"),
                        message: tr("Sift reads photos on this Mac. For documents it reads the opening, the headings, and the column names. With a Jev key, that short outline is sent once per file. The files stay where they are.",
                                    "Sift lit les photos sur ce Mac. Pour les documents, il lit le début, les titres et les noms de colonnes. Avec une clé Jev, ce court résumé est envoyé une fois par fichier. Les fichiers restent où ils sont."),
                        confirmTitle: tr("Start tagging", "Lancer"),
                        destructive: false,
                        run: onStartAITagging
                    )
                }
                settingsActionButton(tr("Reset library & settings…", "Réinitialiser bibliothèque et réglages…"), icon: "trash") {
                    resetLibrary = false
                    resetSettings = false
                    showResetChoices = true
                }
            }
        }
    }

    private var updatesSection: some View {
        PrismSettingsSection(
            title: SiftUpdateCenter.text("Updates", "Mises à jour"),
            footer: SiftUpdateCenter.text(
                "Sift asks GitHub once a day. Download the latest DMG to update. Your catalog stays on this Mac.",
                "Sift interroge GitHub une fois par jour. Téléchargez le dernier DMG pour mettre à jour. Le catalogue reste sur ce Mac."
            )
        ) {
            HStack(spacing: 10) {
                if updates.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else if updates.updateAvailable {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(PrismTheme.accent)
                } else if updates.lastError != nil && !updates.noReleaseYet {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sift \(updates.installedVersion)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PrismTheme.textPrimary)
                    Text(updates.statusText)
                        .font(.caption)
                        .foregroundStyle(PrismTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button(SiftUpdateCenter.text("Check for updates", "Rechercher des mises à jour")) {
                    Task { await updates.check(force: true) }
                }
                .buttonStyle(.bordered)
                .disabled(updates.isChecking)
                .prismClickable()

                if updates.updateAvailable {
                    Button(SiftUpdateCenter.text("Download update", "Télécharger la mise à jour")) {
                        updates.openDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PrismTheme.accent)
                    .prismClickable()
                }
            }
        }
    }

    @ViewBuilder
    private var destinationsContent: some View {
        if destinations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("No destination yet", "Pas encore de destination"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PrismTheme.textPrimary)
                Text(tr("Add a folder where tidied files should live, in Organize or during setup.", "Ajoutez un dossier où ranger les fichiers, dans Organiser ou pendant la configuration."))
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sectionInnerBackground)
        } else {
            VStack(spacing: 8) {
                ForEach(destinations) { dest in
                    destinationRow(dest)
                }
            }
        }
    }

    private func destinationRow(_ dest: DestinationBookmark) -> some View {
        let isActive = dest.id == activeDestinationID
        return HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(isActive ? PrismTheme.accent : PrismTheme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(dest.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PrismTheme.textPrimary)
                    .lineLimit(2)
                if isActive {
                    Text(tr("Active destination", "Destination active"))
                        .font(.caption)
                        .foregroundStyle(PrismTheme.accent)
                }
            }
            Spacer(minLength: 0)
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(PrismTheme.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(sectionInnerBackground)
    }

    private var sectionInnerBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(PrismTheme.surfaceMuted.opacity(0.5))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(PrismTheme.borderSubtle, lineWidth: 1)
            }
    }

    private func settingsActionButton(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PrismTheme.textTertiary)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PrismTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sectionInnerBackground)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .prismClickable()
    }

    private func transferRow(_ record: TransferRecord) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text((record.destinationPath as NSString).lastPathComponent)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(record.sourcePath)
                    .font(.caption2)
                    .foregroundStyle(PrismTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            if !record.isUndone {
                Button(tr("Undo", "Annuler")) {
                    confirm = SiftConfirm(
                        title: "Undo this transfer?",
                        message: "Sift tries to put the file back. That only works if the file is still at the destination.",
                        confirmTitle: "Undo transfer"
                    ) {
                        onUndoTransfer(record)
                    }
                }
                    .font(.caption.weight(.semibold))
                    .prismClickable()
            } else {
                Text(tr("Undone", "Annulé"))
                    .font(.caption2)
                    .foregroundStyle(PrismTheme.textTertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private func privacyRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(PrismTheme.accent)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(PrismTheme.textSecondary)
        }
    }
}

// MARK: - Section chrome

struct PrismSettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(PrismTheme.textPrimary)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .prismGlass(cornerRadius: 20, padding: 0)

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(PrismTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
