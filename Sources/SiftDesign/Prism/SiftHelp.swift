import SwiftUI

public struct SiftHelpArticle: Identifiable, Hashable, Sendable {
    public let id: String
    public let modes: [String]
    public let title: [String: String]
    public let body: [String: String]
    public let keywords: [String]

    public func resolvedTitle() -> String { Self.resolve(title) }
    public func resolvedBody() -> String { Self.resolve(body) }

    public func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        let hay = ([resolvedTitle(), resolvedBody()] + keywords + Array(title.values) + Array(body.values))
            .joined(separator: " ")
            .lowercased()
        return q.split(whereSeparator: \.isWhitespace).allSatisfy { hay.contains($0) }
    }

    private static func resolve(_ map: [String: String]) -> String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        if let text = map[code], !text.isEmpty { return text }
        if let text = map["en"], !text.isEmpty { return text }
        return map.values.first ?? ""
    }
}

public enum SiftHelpCatalog {
    /// The article that opens when help is asked from this page.
    public static func primaryID(for mode: String) -> String {
        switch mode {
        case "sources": "discover"
        case "library": "library"
        case "organize": "organize"
        case "review": "review"
        case "settings": "settings"
        default: "what"
        }
    }

    public static func pageName(for mode: String) -> String {
        let french = Locale.current.language.languageCode?.identifier == "fr"
        switch mode {
        case "sources": return french ? "Découvrir" : "Discover"
        case "library": return french ? "Bibliothèque" : "Library"
        case "organize": return french ? "Organiser" : "Organize"
        case "review": return french ? "Revue" : "Review AI"
        case "settings": return french ? "Réglages" : "Settings"
        default: return french ? "Aide" : "Help"
        }
    }

    /// Only the articles written for this page. Shared topics stay out of this list.
    public static func forPage(_ mode: String) -> [SiftHelpArticle] {
        let primary = primaryID(for: mode)
        return all
            .filter { $0.modes.contains(mode) }
            .sorted { ($0.id == primary ? 0 : 1) < ($1.id == primary ? 0 : 1) }
    }

    public static func otherPages(_ mode: String) -> [SiftHelpArticle] {
        all.filter { !$0.modes.contains(mode) }
    }

    public static let all: [SiftHelpArticle] = SiftHelpArticles.list

    static func article(
        _ id: String,
        _ modes: [String],
        _ enTitle: String,
        _ frTitle: String,
        _ enBody: String,
        _ frBody: String,
        _ keywords: [String]
    ) -> SiftHelpArticle {
        SiftHelpArticle(
            id: id,
            modes: modes,
            title: ["en": enTitle, "fr": frTitle],
            body: ["en": enBody, "fr": frBody],
            keywords: keywords
        )
    }
}

enum SiftHelpArticles {
    static let list: [SiftHelpArticle] = [
        SiftHelpCatalog.article("what", [], "What Sift does", "Ce que fait Sift",
                "Sift builds a catalog of photos, video, audio, and documents that already live on this Mac. A scan does not move, copy, or delete those files. Move and Copy happen only on Organize, after you pick a destination folder and a card, then confirm. The four pages are Discover, Library, Organize, and Review AI. Settings is the gear. Help is the ? next to it, and it opens on the page you are looking at. The articles under this page explain every control and every dialog on that page. Other pages holds the rest, including this article, the notch, and the command search.",
                "Sift construit un catalogue des photos, vidéos, audio et documents déjà sur ce Mac. Un scan ne déplace, ne copie et ne supprime pas ces fichiers. Move et Copy n’arrivent que dans Organiser, après un dossier de destination, une carte, puis une confirmation. Les quatre pages sont Découvrir, Bibliothèque, Organiser et Revue. Les Réglages sont l’engrenage. L’aide est le ? à côté, et elle s’ouvre sur la page que vous regardez. Les articles de cette page expliquent chaque contrôle et chaque dialogue. Autres pages contient le reste, dont cet article, le notch et la recherche.",
                ["catalog", "pages", "help"]),
        SiftHelpCatalog.article("discover", ["sources"], "Discover", "Découvrir",
                "Discover is Find files on this Mac. The line under the title says Sift makes a catalog and leaves every file where it is. Moving or copying happens later, and only after you choose.\n\nWhat to look for is a row of switches: Photos, Videos, Audio, Documents. The last switch that is still on cannot be turned off. A line under the switches names the kinds that are on and says files already in the catalog stay. Turning a kind off only changes the next scan. When Documents is on, each extension has its own switch: docx, xlsx, pptx, pdf, csv, md, mdx, txt, rtf. The last remaining extension cannot be turned off either.\n\nScan this Mac opens a dialog before anything starts. If folders are already saved, Scan saved folders walks them again without Finder. Choose folders opens the system folder picker, then Add “name”, where Look inside subfolders can be turned off. Scan saved folders, in Catalog locations, names those folders, then asks before it walks them. Each row has Scan again and an Include subfolders switch. Choose a home folder opens a dialog that picks where files should go later. Nothing is moved there.\n\nWhat happens is three steps: choose what to look for, find the files, later decide whether to move or copy them. A note lists what a scan always skips: project folders, apps, caches, and system trees.\n\nCatalog locations lists each saved folder. Includes subfolders or This folder only describes the scan. Change… replaces the folder. Remove asks, then forgets it as a source. The files stay on disk and leave the catalog.\n\nThe counts are how many files are cataloged, how many have been read, and how many locations are saved. The bar at the bottom is the scan itself: Find media or Find or update media, Update, Pause, Resume, Stop, and Cancel. After a stop, Continue or Continue AI (N), Reset AI tags, and Clear can appear.",
                "Découvrir est Trouver des fichiers sur ce Mac. La ligne sous le titre dit que Sift fait un catalogue et laisse chaque fichier où il est. Déplacer ou copier arrive plus tard, et seulement après votre choix.\n\nQuoi chercher est une rangée d’interrupteurs : Photos, Vidéos, Audio, Documents. Le dernier interrupteur encore allumé ne peut pas être éteint. Une ligne sous les interrupteurs nomme les types actifs et dit que les fichiers déjà au catalogue restent. Éteindre un type ne change que le scan suivant. Quand Documents est actif, chaque extension a son interrupteur : docx, xlsx, pptx, pdf, csv, md, mdx, txt, rtf. La dernière extension restante ne peut pas être éteinte non plus.\n\nScanner ce Mac ouvre un dialogue avant de démarrer. Si des dossiers sont déjà enregistrés, Scanner les dossiers enregistrés les reparcourt sans le Finder. Choisir des dossiers ouvre le sélecteur du système, puis Ajouter « nom », où Regarder dans les sous-dossiers peut être désactivé. Scanner les dossiers enregistrés, dans Emplacements du catalogue, nomme ces dossiers, puis demande avant de les parcourir. Chaque ligne a Scanner à nouveau et un interrupteur Inclure les sous-dossiers. Choisir un dossier d’accueil ouvre un dialogue pour l’endroit où les fichiers iront plus tard. Rien n’y est déplacé.\n\nCe qui se passe tient en trois étapes : choisir quoi chercher, trouver les fichiers, décider plus tard de les déplacer ou de les copier. Une note liste ce qu’un scan ignore toujours : dossiers de projet, apps, caches et arbres système.\n\nEmplacements du catalogue liste chaque dossier enregistré. Inclut les sous-dossiers ou Ce dossier seulement décrit le scan. Changer… remplace le dossier. Retirer demande, puis l’oublie comme source. Les fichiers restent sur le disque et quittent le catalogue.\n\nLes comptes sont le nombre de fichiers catalogués, le nombre déjà lus, et le nombre d’emplacements. La barre du bas est le scan : Trouver des médias ou Trouver ou mettre à jour, Mettre à jour, Pause, Reprendre, Stop et Annuler. Après un arrêt, Continuer ou Continue AI (N), Effacer les tags IA, et Effacer peuvent apparaître.",
                ["scan", "look again", "folders"]),
        article("discover-kinds", ["sources"], "What to look for", "Quoi chercher",
                "Each kind is a switch. The last remaining kind cannot be turned off. When documents are on, each extension has its own switch: docx, xlsx, pptx, pdf, csv, md, mdx, txt, rtf. Narrowing the next scan does not remove files already in the catalog.",
                "Chaque type est un interrupteur. Le dernier type restant ne peut pas être éteint. Quand les documents sont actifs, chaque extension a son interrupteur : docx, xlsx, pptx, pdf, csv, md, mdx, txt, rtf. Rétrécir le scan suivant ne retire pas les fichiers déjà au catalogue.",
                ["pdf", "audio", "extensions"]),
        article("library", ["library"], "Library", "Bibliothèque",
                "The library is the catalog. Switching Grid, List, or Garden does not restart a scan. Grid is the mosaic. List is one row per file. Garden has four layouts: Orbit, Spiral, Depth, and Drift. Orbit scrolls or drags to turn, photos change after a three-quarter turn, and a click inspects. Spiral, Depth, and Drift use the same catalog photos and a click still opens the viewer. A date is shown on documents and audio only. It is the day the file entered the catalog.\n\nHovering opens a card. A click opens the viewer. Audio shows a waveform, the filename, and a player that does not start by itself. Video plays in the card. Documents open in Quick Look, in the card and in the viewer.\n\nThe sidebar is Library. Each media kind has a count, and choosing one filters the grid. Named people lists only people you accepted in Review AI. The caption says naming happens in Review AI.\n\nWhat is shown: Entire Mac is the whole catalog. All folders keeps files from saved folders. Inbox (at source) keeps files still in the folder where they were found. Each saved folder can be chosen alone, with its count. The number shown is the filter, not the disk.\n\nThe toolbar is Add folder, Sources (N), and Search content. The count is N in the catalog. Add folder starts the same folder intake as Discover. Sources (N) opens Discover. Search content opens the command search.\n\nThe viewer shows one of N and the kind. Close, or Esc, leaves it. Info opens size, kind, pixel size, labels, and the source. Arrow keys move through the items you opened.",
                "La bibliothèque est le catalogue. Passer de Grille à Liste ou Garden ne relance pas un scan. Grille est la mosaïque. Liste est une ligne par fichier. Garden a quatre dispositions : Orbit, Spiral, Depth et Drift. Orbit se tourne en défilant ou en glissant, les photos changent après trois quarts de tour, et un clic inspecte. Spiral, Depth et Drift montrent les mêmes photos du catalogue, et un clic ouvre encore le lecteur. Une date n’apparaît que sur les documents et l’audio. C’est le jour d’entrée dans le catalogue.\n\nLe survol ouvre une carte. Un clic ouvre le lecteur. L’audio montre une forme d’onde, le nom, et un lecteur qui ne démarre pas seul. La vidéo se lit dans la carte. Les documents s’ouvrent dans Quick Look, dans la carte et dans le lecteur.\n\nLa barre latérale est Bibliothèque. Chaque type a un compte, et le choisir filtre la grille. Personnes nommées ne liste que les personnes acceptées dans Revue. La légende dit que le nommage se fait dans Revue.\n\nCe qui est affiché : Mac entier est tout le catalogue. Tous les dossiers garde les fichiers des dossiers enregistrés. Inbox (à la source) garde les fichiers encore dans le dossier où ils ont été trouvés. Chaque dossier enregistré peut être choisi seul, avec son compte. Le nombre affiché est le filtre, pas le disque.\n\nLa barre est Ajouter un dossier, Sources (N), et Rechercher le contenu. Le compte est N dans le catalogue. Ajouter un dossier lance le même ajout que Découvrir. Sources (N) ouvre Découvrir. Rechercher le contenu ouvre la recherche.\n\nLe lecteur montre un élément sur N et le type. Fermer, ou Échap, le quitte. Info ouvre la taille, le type, la taille en pixels, les labels et la source. Les flèches parcourent les éléments ouverts.",
                ["hover", "garden", "player"]),
        article("organize", ["organize"], "Organize", "Organiser",
                "The title is Organize. The line under it says three steps, and nothing is moved or copied until you press the button at the end.\n\nStep 1, Where should the files go? Add a folder, or pick one already listed. Files go inside that folder, not in the folder above it. Add destination… opens the system picker. Remove asks, then forgets the folder as a destination. Files already there stay on disk. The caption says they are placed inside it, not next to it. Nothing moves on this step.\n\nStep 2, What should happen to the originals? Three cards, and the line says pick one, copy is not assumed. Move: originals leave their current folder and exist only inside the destination. Copy: originals stay, and you get a second copy inside the destination. Copy, then ask: a copy is made first, then Delete originals? lists the paths. Keep originals leaves both. Delete originals removes them from the old place. The same three choices are in Settings under Organizing files, labeled Move (remove from source), Copy (keep originals), and Copy, then remove originals.\n\nStep 3, Review, then file. The line is N waiting and N left as they are, or Review the list before anything changes. A separate note can say how many are already inside the destination, still at the origin, or filed beside the folder. If inbox items match a rule you already saved, that count is shown. It does not file them by itself. Review the list opens What will change. The button next to it is disabled until a destination is chosen, a card is chosen, and at least one file is waiting. Its title is the verb and the folder. Clicking it opens Change these files? and repeats that title. Confirm runs it. Cancel changes nothing.\n\nOr place only the files you selected has Photos, Videos, and Gather. They stay dim until a destination, a card, and a library selection exist. Each zone asks before it moves or copies only that selection, into a folder of that name inside the destination. Find more files returns to Discover and moves nothing.",
                "Le titre est Organiser. La ligne sous le titre dit trois étapes, et que rien n’est déplacé ni copié avant le bouton de la fin.\n\nÉtape 1, Où doivent aller les fichiers ? Ajoutez un dossier, ou choisissez-en un déjà listé. Les fichiers entrent dans ce dossier, pas dans celui du dessus. Ajouter une destination… ouvre le sélecteur du système. Retirer demande, puis oublie le dossier comme destination. Les fichiers déjà là restent sur le disque. La légende dit qu’ils sont placés dedans, pas à côté. Rien ne bouge à cette étape.\n\nÉtape 2, Que doit-il arriver aux originaux ? Trois cartes, et la ligne dit d’en choisir une, Copy n’est pas supposé. Move : les originaux quittent leur dossier et n’existent plus que dans la destination. Copy : les originaux restent, et vous avez une seconde copie dans la destination. Copy, puis demander : une copie est faite d’abord, puis Supprimer les originaux ? liste les chemins. Garder les originaux laisse les deux. Supprimer les originaux les retire de l’ancien endroit. Les trois mêmes choix sont dans Réglages, Organiser les fichiers : Move (remove from source), Copy (keep originals), et Copy, then remove originals.\n\nÉtape 3, Revoir, puis ranger. La ligne est N en attente et N laissés, ou Revoir la liste avant qu’un fichier ne change. Une note à part peut dire combien sont déjà dans la destination, encore à l’origine, ou rangés à côté du dossier. Si des éléments de l’inbox correspondent à une règle déjà enregistrée, ce compte s’affiche. Cela ne les range pas tout seul. Revoir la liste ouvre Ce qui va changer. Le bouton à côté est inactif tant qu’une destination n’est pas choisie, qu’une carte n’est pas choisie, et qu’aucun fichier n’attend. Son titre est le verbe et le dossier. Le clic ouvre Changer ces fichiers ? et répète ce titre. Confirmer lance l’action. Annuler ne change rien.\n\nOu ne placer que les fichiers sélectionnés a Photos, Videos et Gather. Elles restent grisées tant qu’il manque une destination, une carte, ou une sélection dans la bibliothèque. Chaque zone demande avant de déplacer ou copier seulement cette sélection, dans un dossier de ce nom à l’intérieur de la destination. Trouver d’autres fichiers revient à Découvrir et ne déplace rien.",
                ["move", "copy", "destination"]),
        article("review", ["review"], "Review AI", "Revue",
                "The title is Review AI. The line under it says tag photos on device, scan for duplicates, then name and accept face groups. Accepted people appear under Library → Named people. Three counts sit under the title: Indexed is how many files are in the catalog, Analyzed is how many have been read, Pending is how many still wait for tagging.\n\nDuplicates compares on-device feature prints. While it runs, a line says photos stay where they are. A group shows how many files, and the outlined one is the file that stays. The header can say N groups and up to a size reclaimable. That size is an estimate. Trash extras opens Move extras to Trash. The message says the extra files go to the Trash and the suggested file stays where it is. Confirm is Move extras to Trash. Cancel trashes nothing.\n\nSuggested groups appear after tagging. The line under the heading says Accept adds the person to the library sidebar, Dismiss only hides the card, and neither deletes photos. Save name writes the name you typed. Clear removes it. The number on a card is how many photos are in the group.\n\nRun AI tagging opens Enable content search? if Sift still asks. The sheet says how many items remain and that searches such as cat or beach can then use the content, not only the filename. Media stays on this Mac. Don’t ask again hides the sheet next time. Use filename search for now closes it and does not analyze. Analyze for content search starts. If indexing has not finished, a line says to run AI tagging after indexing to cluster faces, trips, and screenshots.",
                "Le titre est Revue. La ligne sous le titre dit de marquer les photos sur l’appareil, chercher les doublons, puis nommer et accepter les groupes de visages. Les personnes acceptées apparaissent dans Bibliothèque → Personnes nommées. Trois comptes sont sous le titre : Indexés est le nombre de fichiers au catalogue, Analysés est le nombre déjà lus, En attente est le nombre qui attend encore le marquage.\n\nDoublons compare des empreintes calculées sur l’appareil. Pendant le calcul, une ligne dit que les photos restent où elles sont. Un groupe montre combien de fichiers, et celui entouré est celui qui reste. L’en-tête peut dire N groupes et jusqu’à une taille récupérable. Cette taille est une estimation. Corbeille des extras ouvre Move extras to Trash. Le message dit que les fichiers en trop vont à la Corbeille et que le fichier suggéré reste où il est. Confirmer est Move extras to Trash. Annuler ne met rien à la corbeille.\n\nLes groupes suggérés apparaissent après le marquage. La ligne sous le titre dit qu’Accepter ajoute la personne à la barre de la bibliothèque, qu’Écarter ne fait que cacher la carte, et qu’aucun des deux ne supprime de photos. Enregistrer le nom écrit le nom tapé. Effacer le retire. Le nombre sur une carte est le nombre de photos du groupe.\n\nLancer le marquage ouvre Activer la recherche de contenu ? si Sift demande encore. La feuille dit combien d’éléments restent et que des recherches comme cat ou beach pourront utiliser le contenu, pas seulement le nom. Les médias restent sur ce Mac. Ne plus demander cache la feuille la prochaine fois. Recherche par nom pour l’instant ferme sans analyser. Analyser pour la recherche de contenu démarre. Si l’indexation n’est pas finie, une ligne dit de lancer le marquage après l’indexation pour regrouper visages, voyages et captures.",
                ["duplicates", "people", "trash"]),
        article("notch", [], "Notch", "Notch",
                "The side rail sits on the screen edge. When the Sift window covers it, including fullscreen, the rail tucks away and an orange tab stays above the window. Click the tab, or drag it along the edge, to open the rail or tuck it again. That wish is remembered: leave it to follow the window, or keep it open, or keep it closed.\n\nWhile a scan runs, the rail can show how many files were found and how many trees were skipped, plus Pause and Resume. It can show how many files are still in source folders, how many are safe to file, and how many are held. Open review queue jumps to Review AI when there are suggestions. Search in the rail uses the same catalog. Clear empties the notch search. No matches means the phrase found nothing.",
                "Le rail est sur le bord de l’écran. Quand la fenêtre de Sift le recouvre, y compris en plein écran, le rail se range et un onglet orange reste au-dessus de la fenêtre. Cliquez l’onglet, ou glissez-le le long du bord, pour ouvrir le rail ou le ranger. Ce souhait est mémorisé : le laisser suivre la fenêtre, le garder ouvert, ou le garder fermé.\n\nPendant un scan, le rail peut montrer combien de fichiers ont été trouvés et combien d’arbres ont été ignorés, plus Pause et Reprendre. Il peut montrer combien de fichiers sont encore dans les dossiers sources, combien peuvent être rangés, et combien sont retenus. Ouvrir la file de revue va à Revue quand il y a des suggestions. La recherche du rail utilise le même catalogue. Effacer vide la recherche du notch. Aucun résultat veut dire que la phrase n’a rien trouvé.",
                ["notch", "fullscreen", "tab"]),
        article("settings", ["settings"], "Settings", "Réglages",
                "The gear, or Settings… in the menu bar, opens Settings. The ? in the header opens this help on the Settings articles. The subtitle says sources, destinations, and how files are organized.\n\nSource folders lists the places Sift scans. No source folders yet means the list is empty. Add folder… opens the system picker. Change… replaces a folder and rebuilds that part of the catalog. Remove asks first. The folder is forgotten, the files stay on the Mac, and they leave the catalog.\n\nIf no destination is saved, a note says to open Organize and add a folder. When one is saved, Active destination names it.\n\nTypeSafe System One is optional. The line under the title says Jev makes bounded choices and does not upload media or replace CLIP. Why? opens How Jev is used: with a key, indexing a document asks once which labels fit, from the opening lines, headings, sheet names, and column headers. Return in search can ask which screen to open, or which of a short list fits. The file itself stays on this Mac. No key, or a failed answer, keeps the labels taken from the file. Paste the key, then Save to Keychain. The field clears after a successful save. Remove asks, then deletes the key. The status is Configured, with jev-latest in the Keychain, or Not configured, and local catalog and Vision search still work.\n\nVisual content search shows Local CLIP model. Ready means the model files are on this Mac and visual search can run locally. Unavailable means the model downloads the first time Sift opens, and until then searches such as cat use Vision labels and filenames. The footer says the search window still works without CLIP: exact files, OCR, people, and on-device Vision labels.\n\nAutomation is Watch source folders. On, a change inside a saved folder indexes those files. It does not walk the whole folder. The footer says new files in source folders are indexed automatically.\n\nOrganizing files is the same three choices as Organize step 2: Move (remove from source), Copy (keep originals), Copy, then remove originals. Picking a card here is the choice. It does not move files by itself.\n\nRecent transfers lists what was moved or copied. No transfers yet means the list is empty. Undo asks first and only works while the file still exists at the destination. After it succeeds the row says Undone.\n\nMaintenance is Rescan all source folders, Start AI tagging, and Reset library & settings…. Each of the first two asks before it starts. Reset opens a dialog and erases nothing until you confirm.\n\nPrivacy lists All processing is on-device and No network required. The footer says the library and Vision models never leave this Mac. The exception is the short document outline described under Why?, and only while a Jev key is saved.",
                "L’engrenage, ou Réglages… dans la barre des menus, ouvre les Réglages. Le ? de l’en-tête ouvre cette aide sur les articles Réglages. Le sous-titre dit sources, destinations, et comment les fichiers sont organisés.\n\nDossiers sources liste les endroits que Sift scanne. Aucun dossier source veut dire que la liste est vide. Ajouter un dossier… ouvre le sélecteur du système. Changer… remplace un dossier et reconstruit cette partie du catalogue. Retirer demande d’abord. Le dossier est oublié, les fichiers restent sur le Mac, et ils quittent le catalogue.\n\nSi aucune destination n’est enregistrée, une note dit d’ouvrir Organiser et d’ajouter un dossier. Quand une est enregistrée, Destination active la nomme.\n\nTypeSafe System One est optionnel. La ligne sous le titre dit que Jev fait des choix bornés et n’envoie pas les médias ni ne remplace CLIP. Pourquoi ? ouvre Comment Jev est utilisé : avec une clé, l’indexation d’un document demande une fois quels labels conviennent, à partir des premières lignes, des titres, des noms de feuilles et des en-têtes de colonnes. Entrée dans la recherche peut demander quel écran ouvrir, ou lequel d’une courte liste convient. Le fichier lui-même reste sur ce Mac. Sans clé, ou si la réponse échoue, les labels pris dans le fichier restent. Collez la clé, puis Enregistrer dans le Trousseau. Le champ se vide après un enregistrement réussi. Retirer demande, puis supprime la clé. Le statut est Configuré, avec jev-latest dans le Trousseau, ou Non configuré, et le catalogue local et la recherche Vision marchent encore.\n\nRecherche de contenu visuel montre le modèle CLIP local. Prêt veut dire que les fichiers du modèle sont sur ce Mac et que la recherche visuelle peut tourner en local. Indisponible veut dire que le modèle se télécharge à la première ouverture de Sift, et que jusque-là des recherches comme cat utilisent les labels Vision et les noms de fichiers. Le pied de page dit que la fenêtre de recherche marche sans CLIP : fichiers exacts, OCR, personnes, et labels Vision sur l’appareil.\n\nAutomatisation est Surveiller les dossiers. Actif, un changement dans un dossier enregistré indexe ces fichiers. Cela ne parcourt pas tout le dossier. Le pied de page dit que les nouveaux fichiers des dossiers sources sont indexés automatiquement.\n\nOrganiser les fichiers reprend les trois choix de l’étape 2 d’Organiser : Move (remove from source), Copy (keep originals), Copy, then remove originals. Choisir une carte ici est le choix. Cela ne déplace pas les fichiers tout seul.\n\nTransferts récents liste ce qui a été déplacé ou copié. Aucun transfert veut dire que la liste est vide. Annuler demande d’abord et ne marche que tant que le fichier est encore à destination. Après succès la ligne dit Annulé.\n\nMaintenance est Rescanner tous les dossiers sources, Démarrer le marquage, et Reset library & settings…. Les deux premiers demandent avant de démarrer. Reset ouvre un dialogue et n’efface rien avant confirmation.\n\nConfidentialité liste Tout le traitement est sur l’appareil et Aucun réseau requis. Le pied de page dit que la bibliothèque et les modèles Vision ne quittent jamais ce Mac. L’exception est le court aperçu de document décrit dans Pourquoi ?, et seulement tant qu’une clé Jev est enregistrée.",
                ["keychain", "watch", "undo"]),
        article("discover-scan-dialog", ["sources"], "Dialog: Scan this Mac", "Dialogue : Scanner ce Mac",
                "Scan this Mac does not start immediately. It opens Find files on this Mac. The first line names the kinds you turned on. The next line says this only builds a catalog and files stay in their folders. If folders are already saved, Scan saved folders is the main button and walks those folders again without Finder. If Full Disk Access is on, the window says it will check home folders and mounted disks, and also offers Choose folders and Scan this Mac. If it is off, it says Choose folders works now, and Enable Full Disk Access opens the system setting. Cancel closes the window and scans nothing. A note lists what is always skipped: macOS system trees, apps, caches, .git, node_modules, DerivedData, .build, Pods, and package bundles.",
                "Scanner ce Mac ne démarre pas tout de suite. Il ouvre Trouver des fichiers sur ce Mac. La première ligne nomme les types cochés. La suivante dit que cela ne fait qu’un catalogue et que les fichiers restent dans leurs dossiers. Si l’accès complet au disque est actif, la fenêtre dit qu’elle vérifiera les dossiers de départ et les disques montés, et propose Choisir des dossiers et Scanner ce Mac. Sinon, elle dit que Choisir des dossiers marche déjà, et Activer l’accès complet au disque ouvre le réglage système. Annuler ferme la fenêtre et ne scanne rien. Une note liste ce qui est toujours ignoré : arbres système, apps, caches, .git, node_modules, DerivedData, .build, Pods et paquets.",
                ["scan", "full disk", "cancel", "dialog"]),
        article("discover-folder-dialog", ["sources"], "Dialog: add a folder", "Dialogue : ajouter un dossier",
                "Choose folders opens the system folder picker. After you pick one, Add “name” explains the scan. Look inside subfolders includes nested folders. The window counts photos and videos in the folder itself, and how many subfolders hold media. If the folder itself has none, it says so. Select all checks every subfolder. Root only keeps the folder you picked and clears the subfolder checks. A line then says only files in that folder will be scanned unless you select subfolders. Cancel closes without adding. Back returns to the previous step. The last line says the next step is a destination folder with Photos, Videos, and Gather. That step does not move files.",
                "Choisir des dossiers ouvre le sélecteur du système. Après le choix, Ajouter « nom » explique le scan. Regarder dans les sous-dossiers inclut les dossiers imbriqués. La fenêtre compte les photos et vidéos dans le dossier lui-même, et combien de sous-dossiers contiennent des médias. S’il n’y en a pas dans le dossier lui-même, elle le dit. Tout sélectionner coche chaque sous-dossier. Racine seule garde le dossier choisi et décoche les sous-dossiers. Une ligne dit alors que seuls les fichiers de ce dossier seront scannés, sauf si vous cochez des sous-dossiers. Annuler ferme sans ajouter. Retour revient à l’étape précédente. La dernière ligne dit que l’étape suivante est un dossier de destination avec Photos, Videos et Gather. Cette étape ne déplace pas les fichiers.",
                ["subfolder", "select all", "root"]),
        article("discover-look-again", ["sources"], "Look again", "Look again",
                "Scan saved folders appears in Catalog locations after at least one folder is saved. The button’s help names those folders before you click. Clicking it opens Scan saved folders? The message names the folders and says Sift walks them and updates the catalog, and files stay where they are. Each folder keeps its Include subfolders setting. Confirm is Scan saved folders. Cancel walks nothing. Scan again on a row does the same for that folder only. A later change inside a saved folder, when Watch source folders is on, checks only the files that changed. It does not walk the whole folder.",
                "Look again n’apparaît qu’après au moins un dossier enregistré. L’aide du bouton nomme ces dossiers avant le clic. Le clic ouvre Look again ? Le message nomme les dossiers et dit que Sift les parcourt et met le catalogue à jour, et que les fichiers restent où ils sont. Confirmer est Look again. Annuler ne parcourt rien. Un changement plus tard dans un dossier enregistré, si Surveiller les dossiers est actif, ne vérifie que les fichiers changés. Il ne parcourt pas tout le dossier.",
                ["look again", "update", "watch"]),
        article("discover-home-dialog", ["sources"], "Dialog: home folder", "Dialogue : dossier d’accueil",
                "Choose a home folder opens Choose a home folder. It asks for the folder files should go inside. Add folder… opens the system picker. Done closes the window. Cancel closes it too. Nothing is moved or copied in this dialog. Move or copy is chosen later, on Organize. Files are written inside the folder you name, not in the folder above it.",
                "Choisir un dossier d’accueil ouvre Choisir un dossier d’accueil. Il demande le dossier dans lequel les fichiers doivent entrer. Ajouter un dossier… ouvre le sélecteur du système. Terminé ferme la fenêtre. Annuler aussi. Rien n’est déplacé ni copié dans ce dialogue. Move ou Copy se choisit plus tard, dans Organiser. Les fichiers sont écrits dans le dossier nommé, pas dans celui du dessus.",
                ["destination", "home", "done"]),
        article("discover-locations", ["sources"], "Catalog locations", "Emplacements du catalogue",
                "Catalog locations lists each saved folder. Scan saved folders walks every saved folder again, without Finder, and asks first. Each row has Scan again, which walks that folder only, and Include subfolders. Off means the next scan of that folder stays in the folder itself and nested files leave the catalog. Files on the Mac are not deleted. Includes subfolders means the scan walks inside. This folder only means it does not. Change… picks a replacement and rebuilds that part of the catalog. Forget folder opens a confirm. The folder is forgotten as a source, files stay on the Mac, and they disappear from the catalog. Cancel leaves the source in place.",
                "Emplacements du catalogue liste chaque dossier enregistré. Inclut les sous-dossiers veut dire que le scan entre dedans. Ce dossier seulement veut dire qu’il n’entre pas. Changer… choisit un remplacement et reconstruit cette partie du catalogue. Retirer ouvre Remove « nom » ? Le message dit que le dossier est oublié comme source, que les fichiers déjà là restent sur le Mac, et qu’ils disparaissent du catalogue. Confirmer est Remove from catalog. Annuler laisse la source en place. La même ligne est dans Réglages → Dossiers sources.",
                ["remove", "change", "source"]),
        article("discover-dock", ["sources"], "Scan dock", "Barre de scan",
                "The bar at the bottom is the scan. Find media opens Discover. When folders are already saved, Update is next to it. Update opens Update the catalog? The message says Sift walks the saved folders again and files stay where they are. Confirm is Update. While a scan runs you get Pause or Resume, Stop, and Cancel. Pause keeps the progress and does not ask. Resume continues it. Stop opens Stop indexing? The message says indexing stops here and files already in the catalog stay. Confirm is Stop. Cancel opens Cancel this phase? The message says this phase stops and files already cataloged remain available. Confirm is Cancel phase. The percent, the file count, and N read are the live scan. The subtitle names the kinds being looked for, unless it is checking a few changed files. After a stop you may see Continue, or Continue AI (N) when items still need tagging, Reset AI tags, and Clear. Reset AI tags opens Clear the tags? The message says saved tags and suggested groups are cleared, the files stay in the catalog, and tagging can run again. Confirm is Clear tags. Clear opens Dismiss this status? The message says the status bar goes away and the catalog is not changed. Confirm is Dismiss.",
                "La barre en bas est le scan. Trouver des médias ouvre Découvrir. Quand des dossiers sont déjà enregistrés, Mettre à jour est à côté. Mettre à jour ouvre Update the catalog ? Le message dit que Sift reparcourt les dossiers enregistrés et que les fichiers restent où ils sont. Confirmer est Update. Pendant un scan : Pause ou Reprendre, Stop, et Annuler. Pause garde l’avancement et ne demande pas. Reprendre le continue. Stop ouvre Stop indexing ? Le message dit que l’indexation s’arrête ici et que les fichiers déjà au catalogue restent. Confirmer est Stop. Annuler ouvre Cancel this phase ? Le message dit que cette phase s’arrête et que les fichiers déjà catalogués restent disponibles. Confirmer est Cancel phase. Le pourcentage, le nombre de fichiers, et N lus sont le scan en cours. Le sous-titre nomme les types cherchés, sauf s’il vérifie quelques fichiers changés. Après un arrêt : Continuer, ou Continue AI (N) s’il reste des éléments à marquer, Effacer les tags IA, et Effacer. Effacer les tags IA ouvre Clear the tags ? Le message dit que les tags enregistrés et les groupes suggérés sont retirés, que les fichiers restent au catalogue, et que le marquage peut recommencer. Confirmer est Clear tags. Effacer ouvre Dismiss this status ? Le message dit que la barre de statut disparaît et que le catalogue n’est pas modifié. Confirmer est Dismiss.",
                ["pause", "stop", "cancel", "dock"]),
        article("discover-empty", ["sources"], "Empty catalog", "Catalogue vide",
                "When nothing is cataloged yet, Find files on this Mac offers Scan this Mac, Choose folders, and Photos Library. Scan this Mac and Choose folders open the dialogs above. Photos Library asks the system for the photo library and adds those items to the catalog. Files still stay where they are.",
                "Quand rien n’est encore catalogué, Trouver des fichiers sur ce Mac propose Scanner ce Mac, Choisir des dossiers, et Photothèque. Scanner ce Mac et Choisir des dossiers ouvrent les dialogues ci-dessus. Photothèque demande au système la photothèque et ajoute ces éléments au catalogue. Les fichiers restent où ils sont.",
                ["photos library", "empty"]),
        article("discover-model", ["sources"], "Dialog: visual search download", "Dialogue : téléchargement de la recherche visuelle",
                "The first launch can open Setting up visual search. Sift downloads a local model once, about 289 MB, so a phrase can match what is in a photo. Your photos and searches stay on this Mac. The download is only the model. Try again repeats the download. Continue without visual search closes the window. Search by file name still works. You can leave the window open while it downloads.",
                "Le premier lancement peut ouvrir Mise en place de la recherche visuelle. Sift télécharge une fois un modèle local, environ 289 Mo, pour qu’une phrase corresponde à ce qu’il y a dans une photo. Vos photos et recherches restent sur ce Mac. Le téléchargement n’est que le modèle. Réessayer relance le téléchargement. Continuer sans recherche visuelle ferme la fenêtre. La recherche par nom de fichier marche encore. Vous pouvez laisser la fenêtre ouverte pendant le téléchargement.",
                ["clip", "download", "model"]),
        article("library-views", ["library"], "Grid, list, and Garden", "Grille, liste et Garden",
                "The same catalog has three views. Grid is the mosaic. List is one row per file, with the filename and up to three labels. Garden is the spatial view, with Orbit, Spiral, Depth, and Drift. A click still opens the viewer. Switching views does not restart a scan. Dates appear on documents and audio only, and that date is the day the file entered the catalog, not the day the camera took it.",
                "Le même catalogue a trois vues. Grille est la mosaïque. Liste est une ligne par fichier, avec le nom et jusqu’à trois labels. Garden est la vue spatiale, avec Orbit, Spiral, Depth et Drift. Un clic ouvre toujours le lecteur. Changer de vue ne relance pas un scan. Les dates n’apparaissent que sur les documents et l’audio, et c’est le jour d’entrée dans le catalogue, pas le jour de la prise de vue.",
                ["grid", "list", "garden"]),
        article("library-cards", ["library"], "Hover card and players", "Carte au survol et lecteurs",
                "Hovering a photo or video opens its card without opening the viewer. A click opens the viewer. Audio tiles show a waveform and the filename, and the card has a player that does not start by itself. Video plays in the card. Documents, including docx, pptx, xlsx, and pdf, open in Quick Look in the card and in the viewer. The card also shows the filename and the source folder. The added date is on the card for documents and audio.",
                "Survoler une photo ou une vidéo ouvre sa carte sans ouvrir le grand lecteur. Un clic ouvre le lecteur. Les tuiles audio montrent une forme d’onde et le nom du fichier, et la carte a un lecteur qui ne démarre pas seul. La vidéo se lit dans la carte. Les documents, y compris docx, pptx, xlsx et pdf, s’ouvrent dans Quick Look dans la carte et dans le lecteur. La carte montre aussi le nom et le dossier source. La date d’ajout est sur la carte pour les documents et l’audio.",
                ["hover", "quick look", "player"]),
        article("library-sidebar", ["library"], "Sidebar", "Barre latérale",
                "The sidebar lists media kinds and a count for each. Choosing one opens Library and filters it, even if another page is showing. Named people lists only people you accepted in Review AI. A row shows the name and how many photos are in the group. Naming and dismissing happen in Review AI, not here.",
                "La barre latérale liste les types de médias et un compte pour chacun. En choisir un ouvre la Bibliothèque et la filtre, même si une autre page est affichée. Personnes nommées ne liste que les personnes acceptées dans Revue. Une ligne montre le nom et combien de photos sont dans le groupe. Nommer et écarter se font dans Revue, pas ici.",
                ["sidebar", "people", "filter"]),
        article("library-scope", ["library"], "What is shown", "Ce qui est affiché",
                "Entire Mac shows the whole catalog. All folders limits the grid to files from saved folders. Inbox (at source) shows files still in the folder where they were found. Each saved folder can be chosen on its own, with its file count. The count shown is how many items match the current filter, not how many exist on the disk.",
                "Mac entier montre tout le catalogue. Tous les dossiers limite la grille aux fichiers des dossiers enregistrés. Inbox (à la source) montre les fichiers encore dans le dossier où ils ont été trouvés. Chaque dossier enregistré peut être choisi seul, avec son nombre de fichiers. Le compte affiché est le nombre d’éléments du filtre en cours, pas le nombre de fichiers sur le disque.",
                ["inbox", "entire mac", "scope"]),
        article("library-viewer", ["library"], "Viewer", "Lecteur",
                "The viewer shows one of N and the media kind. Close, or Esc, leaves it. A strip of thumbnails jumps to another item. Arrow keys do the same. Audio uses the player. Documents use Quick Look. Photos and videos use the image or the video player. A capsule shows the file size and the kind.\n\nInfo opens the side panel. File shows the filename and the path on disk, and says the file is loaded from that path until you move or copy it. Pipeline is how Sift classified the item. Source is the folder or library it came from. Dimensions, when there is a picture, is width × height in pixels. People appears when faces were found: Save name writes the name, Clear removes it. Tags lists up to eight labels. Actions does not open a second dialog: Show in Finder reveals the file, Copy path copies the path, and Move to Photos, Move to Videos, and Move to Gather file this one item with the Move or Copy choice already saved on Organize.",
                "Le lecteur montre un élément sur N et le type. Fermer, ou Échap, le quitte. Une bande de vignettes passe à un autre élément. Les flèches aussi. L’audio utilise le lecteur. Les documents utilisent Quick Look. Les photos et vidéos utilisent l’image ou le lecteur vidéo. Une capsule montre la taille du fichier et le type.\n\nInfo ouvre le panneau. Fichier montre le nom et le chemin sur le disque, et dit que le fichier est lu depuis ce chemin jusqu’à un déplacement ou une copie. Pipeline est la façon dont Sift a classé l’élément. Source est le dossier ou la bibliothèque d’origine. Dimensions, quand il y a une image, est largeur × hauteur en pixels. Personnes apparaît quand des visages ont été trouvés : Enregistrer le nom écrit le nom, Effacer le retire. Tags liste jusqu’à huit labels. Actions n’ouvre pas un second dialogue : Afficher dans le Finder révèle le fichier, Copier le chemin copie le chemin, et Move to Photos, Move to Videos et Move to Gather rangent cet élément avec le choix Move ou Copy déjà enregistré dans Organiser.",
                ["viewer", "esc", "info"]),
        article("documents", ["library", "sources"], "Document labels", "Labels des documents",
                "A document is not labeled from its filename alone. Word and text files contribute the opening lines and the headings. A deck contributes the first line of each slide. A spreadsheet contributes the sheet names and the column headers, not the cell values. PDF text is read from the first pages. Kind words such as spreadsheet, meeting, or budget can be added when those words are actually in the outline. With a Jev key, indexing asks once which of those labels fit. The rest of the file stays on this Mac. Files already cataloged keep their old labels until the file changes or you reset the library and scan again.",
                "Un document n’est pas étiqueté seulement par son nom. Les fichiers Word et texte donnent les premières lignes et les titres. Un diaporama donne la première ligne de chaque diapo. Un tableur donne les noms de feuilles et les en-têtes de colonnes, pas les valeurs des cellules. Le texte des PDF est lu sur les premières pages. Des mots de type comme tableur, meeting ou budget s’ajoutent quand ils sont vraiment dans cet aperçu. Avec une clé Jev, l’indexation demande une fois lesquels conviennent. Le reste du fichier reste sur ce Mac. Les fichiers déjà catalogués gardent leurs anciens labels tant que le fichier ne change pas, ou jusqu’à une remise à zéro de la bibliothèque suivie d’un scan.",
                ["pdf", "column", "heading"]),
        article("organize-where", ["organize"], "Step 1: where", "Étape 1 : où",
                "Add a folder, or pick one already listed. The selected folder is the one files go inside. Sift writes in that folder, not in the parent. Add destination… opens the system picker. Remove opens Forget “name”? The message says Sift will no longer organize into this folder, and files already there stay on disk. Confirm is Forget destination. Cancel keeps the destination. The caption under the list says files are placed inside it, not next to it. Nothing is moved on this step.",
                "Ajoutez un dossier, ou choisissez-en un déjà listé. Le dossier sélectionné est celui dans lequel les fichiers entrent. Sift écrit dedans, pas dans le parent. Ajouter une destination… ouvre le sélecteur du système. Retirer ouvre Forget « nom » ? Le message dit que Sift n’organisera plus dans ce dossier, et que les fichiers déjà là restent sur le disque. Confirmer est Forget destination. Annuler garde la destination. La légende sous la liste dit que les fichiers sont placés dedans, pas à côté. Rien n’est déplacé à cette étape.",
                ["destination", "remove", "parent"]),
        article("organize-how", ["organize"], "Step 2: originals", "Étape 2 : originaux",
                "Three cards, and none is assumed. Move: originals leave their current folder and exist only inside the destination. Copy: originals stay, and you get a second copy inside the destination. Copy, then ask: a copy is made first, then Delete originals? lists the paths. Keep originals leaves both copies. Delete originals removes the files from the old place. You must pick a card before the final button or the drop zones will work. The same three cards are in Settings under Organizing files.",
                "Trois cartes, et aucune n’est supposée. Move : les originaux quittent leur dossier et n’existent plus que dans la destination. Copy : les originaux restent, et vous avez une seconde copie dans la destination. Copy, puis demander : une copie est faite d’abord, puis Supprimer les originaux ? liste les chemins. Garder les originaux laisse les deux copies. Supprimer les originaux retire les fichiers de l’ancien endroit. Il faut choisir une carte avant que le bouton final ou les zones de dépôt marchent. Les trois mêmes cartes sont dans Réglages, Organiser les fichiers.",
                ["move", "copy", "delete originals"]),
        article("organize-review-dialog", ["organize"], "Dialog: what will change", "Dialogue : ce qui va changer",
                "Review the list opens What will change. It says nothing happens until you confirm. Each row is a filename and either a folder, or a reason it is left as it is: already inside the destination, already filed beside it, or still in the original folder because a copy is already filed. The count is N waiting and N left as they are. Close returns without changing files. The button at the bottom uses the verb you chose, such as Move 12 files into 80, and asks once more before anything moves. If step 1 or step 2 is not done yet, the list is a preview and the only button is Close and finish that step, which returns you to the Organize page with that step marked Next. The first five files waiting are also listed on the page under step 3.",
                "Revoir la liste ouvre Ce qui va changer. Il dit que rien n’arrive avant confirmation. Chaque ligne est un nom de fichier et soit un dossier, soit une raison de le laisser : déjà dans la destination, déjà déposé à côté, ou encore dans le dossier d’origine parce qu’une copie est déjà rangée. Le compte est N en attente et N laissés. Fermer revient sans changer les fichiers. Le bouton du bas utilise le verbe choisi, comme Move 12 files into 80, et redemande une fois avant qu’un fichier ne bouge.",
                ["review", "blocked", "plan"]),
        article("organize-button", ["organize"], "The final button", "Le bouton final",
                "The button is disabled until a destination is chosen, a move-or-copy card is chosen, and at least one file is waiting. Its title is the verb, the count, and the folder name. Clicking it opens Change these files? The message repeats that title, says nothing else is touched, and says a recent transfer can be undone from Settings while the file is still at the destination. Confirm uses the same title as the button. Cancel changes nothing. Move uses the destructive style. Copy does not.",
                "Le bouton est inactif tant qu’une destination n’est pas choisie, qu’une carte move ou copy n’est pas choisie, et qu’aucun fichier n’attend. Son titre est le verbe, le compte, et le nom du dossier. Le clic ouvre Change these files ? Le message répète ce titre, dit que rien d’autre n’est touché, et dit qu’un transfert récent peut être annulé dans Réglages tant que le fichier est encore à destination. Confirmer reprend le même titre que le bouton. Annuler ne change rien. Move utilise le style destructif. Copy non.",
                ["approve", "confirm", "verb"]),
        article("organize-selection", ["organize"], "Selected files only", "Fichiers sélectionnés seulement",
                "Or place only the files you selected has three zones: Photos, Videos, and Gather. They stay dim until a destination and a move-or-copy card are chosen, and until files are selected in the library. Each zone opens Move the selected files? or Copy the selected files? The message says the selection goes into that folder, inside the destination, and other files stay where they are. Confirm is Move into Photos, Copy into Videos, or the same pattern for Gather. Cancel files nothing. Find more files returns to Discover. It does not move anything.",
                "Ou ne placer que les fichiers sélectionnés a trois zones : Photos, Videos et Gather. Elles restent grisées tant qu’une destination et une carte move ou copy ne sont pas choisies, et tant que des fichiers ne sont pas sélectionnés dans la bibliothèque. Chaque zone ouvre Move the selected files ? ou Copy the selected files ? Le message dit que la sélection va dans ce dossier, à l’intérieur de la destination, et que les autres fichiers restent où ils sont. Confirmer est Move into Photos, Copy into Videos, ou le même schéma pour Gather. Annuler ne range rien. Trouver d’autres fichiers revient à Découvrir. Cela ne déplace rien.",
                ["photos", "videos", "gather", "selection"]),
        article("organize-structure", ["organize"], "Dialog: folders inside the destination", "Dialogue : dossiers dans la destination",
                "Choose a home folder, from Discover, can open Folders inside the destination. The opening line says turn on the folders you want, Sift creates only those empty folders inside the destination, and no file is moved or copied in this step. The tiles are switches. Destination shows the name and path. Change folder… picks another destination. Not now closes without creating anything. Create the selected folders is disabled until a destination exists and at least one tile is on. It opens Create these folders? The message names the empty folders and says no file is moved. If none is selected, the message says no folder is selected. Confirm is Create folders. Cancel creates nothing.",
                "Choisir un dossier d’accueil, depuis Découvrir, peut ouvrir Dossiers dans la destination. La première ligne dit d’activer les dossiers voulus, que Sift ne crée que ces dossiers vides dans la destination, et qu’aucun fichier n’est déplacé ni copié à cette étape. Les tuiles sont des interrupteurs. Destination montre le nom et le chemin. Changer de dossier… en choisit un autre. Pas maintenant ferme sans rien créer. Créer les dossiers sélectionnés est inactif tant qu’il n’y a pas de destination et au moins une tuile allumée. Il ouvre Create these folders ? Le message nomme les dossiers vides et dit qu’aucun fichier n’est déplacé. Si aucun n’est sélectionné, le message dit qu’aucun dossier n’est sélectionné. Confirmer est Create folders. Annuler ne crée rien.",
                ["structure", "tiles", "create"]),
        article("organize-filing", ["organize"], "Already filed or not", "Déjà rangé ou non",
                "The note on Discover, Organize, and the library toolbar separates three cases. Inside the destination: the file is already in the folder you named. Still at the origin: a copy is filed and the original is still in the old folder. Beside the folder: a copy landed next to the destination instead of inside it. Those files are left as they are. They are not copied again.",
                "La note dans Découvrir, Organiser et la barre de la bibliothèque sépare trois cas. Dans la destination : le fichier est déjà dans le dossier nommé. Encore à l’origine : une copie est rangée et l’original est encore dans l’ancien dossier. À côté du dossier : une copie est tombée à côté de la destination au lieu d’entrer dedans. Ces fichiers sont laissés. Ils ne sont pas recopiés.",
                ["filing", "origin", "beside"]),
        article("organize-after", ["organize"], "After a scan finds files", "Après un scan",
                "Files found can open when a scan finishes. It counts what was found. The line under the title says nothing was moved or copied, and you can look through the catalog or choose the folder they should go into later. Look through them opens the library. Choose where they go opens Organize. Done closes the sheet and moves nothing.",
                "Fichiers trouvés peut s’ouvrir à la fin d’un scan. Il compte ce qui a été trouvé. La ligne sous le titre dit que rien n’a été déplacé ni copié, et que vous pouvez parcourir le catalogue ou choisir plus tard le dossier où ils doivent aller. Les parcourir ouvre la bibliothèque. Choisir où ils vont ouvre Organiser. Terminé ferme la feuille et ne déplace rien.",
                ["success", "found"]),
        article("review-duplicates", ["review"], "Duplicates", "Doublons",
                "Duplicates compares on-device feature prints. Photos stay where they are while it runs. A group shows how many files, and the outlined one is the file that stays. The reclaimable size is an estimate of the extras, not a deletion by itself. Trash extras opens a dialog titled Move extras to Trash. The message says the extra files go to the Trash and the suggested file stays where it is. Confirm is Move extras to Trash. Cancel trashes nothing.",
                "Doublons compare des empreintes calculées sur l’appareil. Les photos restent où elles sont pendant le calcul. Un groupe montre combien de fichiers, et celui entouré est celui qui reste. La taille récupérable est une estimation des extras, pas une suppression en soi. Corbeille des extras ouvre un dialogue intitulé Move extras to Trash. Le message dit que les fichiers en trop vont à la Corbeille et que le fichier suggéré reste où il est. Confirmer est Move extras to Trash. Annuler ne met rien à la corbeille.",
                ["trash", "duplicate", "reclaim"]),
        article("review-groups", ["review"], "Suggested groups and names", "Groupes suggérés et noms",
                "Suggested groups appear after tagging. Accept adds the person to Library → Named people. Dismiss only hides the card. Neither deletes photos. Save name writes the name you typed. Clear removes the typed name. The count on a card is how many photos are in the group.",
                "Les groupes suggérés apparaissent après le marquage. Accepter ajoute la personne à Bibliothèque → Personnes nommées. Écarter ne fait que cacher la carte. Aucun des deux ne supprime de photos. Enregistrer le nom écrit le nom tapé. Effacer retire le nom tapé. Le compte sur une carte est le nombre de photos du groupe.",
                ["accept", "dismiss", "name"]),
        article("review-tagging-dialog", ["review"], "Dialog: content search", "Dialogue : recherche de contenu",
                "Run AI tagging, and the sheet Enable content search?, start on-device analysis. The sheet says how many items remain, and that searches such as cat or beach can then use the content, not only the filename. Media stays on this Mac. You can keep browsing while it runs. Don’t ask again hides this sheet next time. Use filename search for now closes it and does not analyze. Analyze for content search starts. Start AI tagging in Settings asks the same kind of question before it starts.",
                "Lancer le marquage, et la feuille Activer la recherche de contenu ?, démarrent l’analyse sur l’appareil. La feuille dit combien d’éléments restent, et que des recherches comme cat ou beach pourront alors utiliser le contenu, pas seulement le nom. Les médias restent sur ce Mac. Vous pouvez continuer à parcourir pendant l’analyse. Ne plus demander cache cette feuille la prochaine fois. Recherche par nom pour l’instant ferme sans analyser. Analyser pour la recherche de contenu démarre. Démarrer le marquage dans Réglages pose le même genre de question avant de démarrer.",
                ["tagging", "dont ask", "analyze"]),
        article("settings-sources", ["settings"], "Source folders", "Dossiers sources",
                "Source folders are the places Sift scans. Add folder… opens the system picker. Each row can be removed, and Remove asks first: the folder is forgotten, the files stay on the Mac, and they leave the catalog. The footer says files stay in place until you Move or Copy into a destination.",
                "Les dossiers sources sont les endroits que Sift scanne. Ajouter un dossier… ouvre le sélecteur du système. Chaque ligne peut être retirée, et Retirer demande d’abord : le dossier est oublié, les fichiers restent sur le Mac, et ils quittent le catalogue. Le pied de page dit que les fichiers restent en place jusqu’à un Move ou un Copy vers une destination.",
                ["add folder", "source"]),
        article("settings-jev", ["settings"], "Jev key", "Clé Jev",
                "The section is Jev intelligence. TypeSafe System One is optional. The placeholder is Paste TYPESAFE_API_KEY…, or Replace stored API key… when one is already saved. Save to Keychain is disabled until the field has text. It stores the key and clears the field. It does not ask again, because saving is the choice. Why? opens How Jev is used. Remove appears only when a key is saved. It opens Remove the Jev key? The message says the key is deleted from the Keychain, routing and document labels then stay on this Mac, and you can paste a key again later. Confirm is Remove key. Cancel keeps the key. The status line says Configured, model jev-latest, credential stored in the macOS Keychain, or Not configured, and local catalog and Vision search still work.",
                "La section est Intelligence Jev. TypeSafe System One est optionnel. Le champ dit Paste TYPESAFE_API_KEY…, ou Replace stored API key… quand une clé est déjà enregistrée. Enregistrer dans le Trousseau est inactif tant que le champ est vide. Il stocke la clé et vide le champ. Il ne redemande pas, parce que l’enregistrement est le choix. Pourquoi ? ouvre Comment Jev est utilisé. Retirer n’apparaît que lorsqu’une clé est enregistrée. Il ouvre Remove the Jev key ? Le message dit que la clé est supprimée du Trousseau, que le routage et les labels de documents restent alors sur ce Mac, et que vous pourrez recoller une clé plus tard. Confirmer est Remove key. Annuler garde la clé. La ligne de statut dit Configuré, modèle jev-latest, identifiant dans le Trousseau macOS, ou Non configuré, et le catalogue local et la recherche Vision marchent encore.",
                ["keychain", "api", "why"]),
        article("settings-watch", ["settings"], "Watch source folders", "Surveiller les dossiers",
                "Watch source folders, when on, notices a change inside a saved folder and checks those files. It does not start a full walk of Downloads or any other folder. A full walk is Look again or Rescan all source folders, and both ask first.",
                "Surveiller les dossiers, quand c’est actif, remarque un changement dans un dossier enregistré et vérifie ces fichiers. Cela ne lance pas un parcours complet de Téléchargements ou d’un autre dossier. Un parcours complet est Look again ou Rescanner tous les dossiers sources, et les deux demandent d’abord.",
                ["watch", "downloads"]),
        article("settings-undo", ["settings"], "Undo a transfer", "Annuler un transfert",
                "Recent transfers lists what was moved or copied. Each row shows the destination name and the original path. No transfers yet means the list is empty. Undo opens Undo this transfer? The message says Sift tries to put the file back, and that only works if the file is still at the destination. Confirm is Undo transfer. Cancel leaves the transfer as it is. After it succeeds the row says Undone and the button disappears. The footer says the same limit.",
                "Transferts récents liste ce qui a été déplacé ou copié. Chaque ligne montre le nom de la destination et le chemin d’origine. Aucun transfert veut dire que la liste est vide. Annuler ouvre Undo this transfer ? Le message dit que Sift essaie de remettre le fichier, et que cela ne marche que si le fichier est encore à destination. Confirmer est Undo transfer. Annuler laisse le transfert tel quel. Après succès la ligne dit Annulé et le bouton disparaît. Le pied de page dit la même limite.",
                ["undo", "transfer"]),
        article("settings-reset", ["settings"], "Dialog: Reset", "Dialogue : Reset",
                "Reset library & settings… does not erase anything by itself. It opens Reset. Two switches start off. Library erases the catalog, thumbnails, and transfer history. Photos, audio, video, and documents stay in their folders. Discover is empty until you scan again. Settings forgets source folders, destinations, what to look for, and the move-or-copy choice. The Jev key stays in the Keychain. Reset what I chose is disabled until at least one switch is on. It clears only the switches you turned on. Cancel clears nothing.",
                "Reset library & settings… n’efface rien tout seul. Il ouvre Reset. Deux interrupteurs partent éteints. Bibliothèque efface le catalogue, les vignettes et l’historique des transferts. Photos, audio, vidéo et documents restent dans leurs dossiers. Découvrir est vide jusqu’au prochain scan. Réglages oublie les dossiers sources, les destinations, quoi chercher, et le choix move ou copy. La clé Jev reste dans le Trousseau. Reset what I chose est inactif tant qu’aucun interrupteur n’est allumé. Il n’efface que les interrupteurs allumés. Annuler n’efface rien.",
                ["reset", "library", "settings"]),
        article("settings-maintenance", ["settings"], "Rescan and tagging", "Rescan et marquage",
                "Rescan all source folders opens Rescan the saved folders? The message says Sift walks the folders you already saved and updates the catalog, and files stay where they are. Confirm is Rescan. Start AI tagging opens Start tagging? The message says Sift reads photos on this Mac, and for documents it reads the opening, the headings, and the column names. With a Jev key, that short outline is sent once per file. The files stay where they are. Confirm is Start tagging. Cancel starts neither. Reset library & settings… is the separate Reset dialog.",
                "Rescanner tous les dossiers sources ouvre Rescan the saved folders ? Le message dit que Sift parcourt les dossiers déjà enregistrés et met le catalogue à jour, et que les fichiers restent où ils sont. Confirmer est Rescan. Démarrer le marquage ouvre Start tagging ? Le message dit que Sift lit les photos sur ce Mac, et que pour les documents il lit l’ouverture, les titres et les noms de colonnes. Avec une clé Jev, ce court aperçu part une fois par fichier. Les fichiers restent où ils sont. Confirmer est Start tagging. Annuler ne démarre ni l’un ni l’autre. Reset library & settings… est le dialogue Reset à part.",
                ["rescan", "tagging"]),
        article("library-toolbar", ["library"], "Toolbar", "Barre d’outils",
                "Add folder starts the same intake as Choose folders on Discover: the system picker, then Add “name”, with Look inside subfolders, Select all, Root only, Cancel, and Back. Sources (N) opens Discover, where N is how many folders are saved. Search content opens the command search. The count beside them is how many items are in the catalog.",
                "Ajouter un dossier lance le même ajout que Choisir des dossiers dans Découvrir : le sélecteur du système, puis Ajouter « nom », avec Regarder dans les sous-dossiers, Tout sélectionner, Racine seule, Annuler et Retour. Sources (N) ouvre Découvrir, où N est le nombre de dossiers enregistrés. Rechercher le contenu ouvre la recherche. Le compte à côté est le nombre d’éléments dans le catalogue.",
                ["toolbar", "search", "add folder"]),
        article("settings-clip", ["settings"], "Local CLIP model", "Modèle CLIP local",
                "Visual content search shows Local CLIP model. Ready, with a check, means the model files are on this Mac and a phrase can match what a photo shows. Unavailable means the model is not on this Mac yet. It downloads the first time Sift opens, about 289 MB, in Setting up visual search. Until then, searches such as cat use Vision labels and filenames. The footer says the search window is always available, and exact files, OCR, people, and on-device Vision labels work without CLIP. Continue without visual search in that download dialog leaves this row unavailable and keeps filename search.",
                "Recherche de contenu visuel montre le modèle CLIP local. Prêt, avec une coche, veut dire que les fichiers du modèle sont sur ce Mac et qu’une phrase peut correspondre à ce qu’une photo montre. Indisponible veut dire que le modèle n’est pas encore sur ce Mac. Il se télécharge à la première ouverture de Sift, environ 289 Mo, dans Mise en place de la recherche visuelle. Jusque-là, des recherches comme cat utilisent les labels Vision et les noms de fichiers. Le pied de page dit que la fenêtre de recherche est toujours là, et que les fichiers exacts, l’OCR, les personnes et les labels Vision sur l’appareil marchent sans CLIP. Continuer sans recherche visuelle dans ce dialogue laisse cette ligne indisponible et garde la recherche par nom.",
                ["clip", "model", "ready"]),
        article("settings-organize-mode", ["settings"], "Organizing files", "Organiser les fichiers",
                "When organizing files is the same choice as Organize step 2. Move (remove from source): files leave their original location. Copy (keep originals): originals stay untouched, and the copy uses disk space. Copy, then remove originals: Sift copies first, then asks when to delete the originals. Picking a row here saves the choice. It does not move or copy anything. Organize still asks Change these files? before a batch runs, and each drop zone still asks before it files a selection.",
                "Quand on organise les fichiers est le même choix que l’étape 2 d’Organiser. Move (remove from source) : les fichiers quittent leur emplacement d’origine. Copy (keep originals) : les originaux restent, et la copie prend de l’espace. Copy, then remove originals : Sift copie d’abord, puis demande quand supprimer les originaux. Choisir une ligne ici enregistre le choix. Cela ne déplace ni ne copie rien. Organiser demande encore Changer ces fichiers ? avant un lot, et chaque zone de dépôt demande encore avant de ranger une sélection.",
                ["move", "copy", "transfer"]),
        article("settings-updates", ["settings"], "Updates", "Mises à jour",
                "Updates is the first section in Settings. It shows the installed version, such as Sift 0.1.0. Sift asks GitHub once a day, on launch and when Settings opens, whether Cyberesia/sift has a newer release. If it does, an alert says Update available, names the version, and says to download the latest DMG. Download update opens that DMG. Later remembers that version and does not show the alert again until a newer one exists. The Settings row still shows the newer version, and Download update stays there. Check for updates asks GitHub immediately and shows the alert again even if you chose Later. You’re on the latest release means the published version is not newer. No release published yet means GitHub has no release. Nothing in the catalog is changed by the check.",
                "Mises à jour est la première section des Réglages. Elle montre la version installée, comme Sift 0.1.0. Sift demande à GitHub une fois par jour, au lancement et à l’ouverture des Réglages, si Cyberesia/sift a une version plus récente. Si oui, une alerte dit Mise à jour disponible, nomme la version, et dit de télécharger le dernier DMG. Télécharger la mise à jour ouvre ce DMG. Plus tard mémorise cette version et ne montre plus l’alerte jusqu’à une version encore plus récente. La ligne des Réglages montre toujours la version plus récente, et Télécharger la mise à jour reste là. Rechercher des mises à jour interroge GitHub tout de suite et montre l’alerte même si vous aviez choisi Plus tard. Vous utilisez la dernière version veut dire que la version publiée n’est pas plus récente. Aucune version publiée pour l’instant veut dire que GitHub n’a pas de release. Le contrôle ne change rien au catalogue.",
                ["update", "dmg", "github"]),
        article("settings-privacy", ["settings"], "Privacy", "Confidentialité",
                "Privacy has two rows: All processing is on-device, and No network required. Photos, video, and audio are not uploaded. With a saved Jev key, the assistant can send the command, allowed actions, and short catalog facts: filenames, extensions, kinds, source folders, sizes, dates, dimensions, durations, scored labels, and up to three short OCR lines. Document labeling can send opening lines, headings, sheet names, and column headers. The file itself stays on this Mac. With no key, the on-device classifier is used.",
                "Confidentialité a deux lignes : Tout le traitement est sur l’appareil, et Aucun réseau requis. Photos, vidéo et audio ne sont pas envoyés. Avec une clé Jev, l’assistant peut envoyer la commande, les actions permises et des faits courts du catalogue : noms, extensions, types, dossiers sources, tailles, dates, dimensions, durées, labels scorés et jusqu’à trois courtes lignes OCR. Le marquage des documents peut envoyer les premières lignes, les titres, les noms de feuilles et les en-têtes. Le fichier reste sur ce Mac. Sans clé, le classifieur local est utilisé.",
                ["privacy", "network", "on-device"]),
        article("command", [], "Command Orb", "Command Orb",
                "Search content in the library, and the field in the notch, open the same search. The empty state says Search your visual library. With the local model ready, CLIP searches what the picture shows, and the line says to turn on Filenames to also match names and text inside the image. Without the model, search uses filenames, OCR, Vision labels, and people.\n\n↩ Search is Return. Return can open a screen when the phrase is a command, such as open organize. A picture search stays a search. With a Jev key, a confident answer can open a screen or move one result to the front. No key, or a low-confidence answer, keeps the local result. Jev is not called on every keystroke.\n\nFilenames is a checkbox. On, names and text read inside the picture are included. Off, the search stays on what the picture shows. The label beside it says Visual CLIP + filenames, Visual content only, Filenames, OCR & labels, or OCR, labels & people, depending on the model and the checkbox.\n\nThe result line is N matches, or No pictures found. No visual matches suggests a filename, visible text, a person, a place, or a broader description. Up to 50 matches are shown. Clicking one opens it.\n\nIf content recognition is not finished, a note says it is ready for N of N items, and unmatched items can only be found by filename or metadata until analysis finishes. Analyze remaining starts that pass. It is the same on-device tagging as Review AI.\n\nSaved searches lists phrases you kept. Save stores the current phrase. Picking a saved search runs it again.",
                "Rechercher le contenu dans la bibliothèque, et le champ du notch, ouvrent la même recherche. L’état vide dit Rechercher votre bibliothèque visuelle. Avec le modèle local prêt, CLIP cherche ce que l’image montre, et la ligne dit d’activer Noms de fichiers pour aussi chercher les noms et le texte dans l’image. Sans le modèle, la recherche utilise les noms, l’OCR, les labels Vision et les personnes.\n\n↩ Search est Entrée. Entrée peut ouvrir un écran quand la phrase est une commande, comme ouvrir organiser. Une recherche d’image reste une recherche. Avec une clé Jev, une réponse sûre peut ouvrir un écran ou mettre un résultat devant. Sans clé, ou si la réponse est peu sûre, le résultat local reste. Jev n’est pas appelé à chaque frappe.\n\nNoms de fichiers est une case. Cochée, les noms et le texte lu dans l’image sont inclus. Décochée, la recherche reste sur ce que l’image montre. L’étiquette à côté dit Visual CLIP + filenames, Visual content only, Filenames, OCR & labels, ou OCR, labels & people, selon le modèle et la case.\n\nLa ligne de résultats est N correspondances, ou Aucune image trouvée. Aucune correspondance visuelle propose un nom, du texte visible, une personne, un lieu, ou une description plus large. Jusqu’à 50 résultats sont montrés. Un clic en ouvre un.\n\nSi la reconnaissance de contenu n’est pas finie, une note dit qu’elle est prête pour N éléments sur N, et que les éléments non analysés ne se trouvent que par nom ou métadonnées tant que l’analyse n’est pas finie. Analyser le reste lance cette passe. C’est le même marquage sur l’appareil que Revue.\n\nRecherches enregistrées liste les phrases gardées. Enregistrer stocke la phrase en cours. Choisir une recherche enregistrée la relance.",
                ["search", "return", "jev", "filenames"]),
    ]

    private static func article(
        _ id: String,
        _ modes: [String],
        _ enTitle: String,
        _ frTitle: String,
        _ enBody: String,
        _ frBody: String,
        _ keywords: [String]
    ) -> SiftHelpArticle {
        SiftHelpArticle(
            id: id,
            modes: modes,
            title: ["en": enTitle, "fr": frTitle],
            body: ["en": enBody, "fr": frBody],
            keywords: keywords
        )
    }
}

public struct SiftHelpView: View {
    let mode: String
    let onClose: () -> Void
    @State private var query = ""
    @State private var selectedID: String?

    public init(mode: String, onClose: @escaping () -> Void) {
        self.mode = mode
        self.onClose = onClose
        _selectedID = State(initialValue: SiftHelpCatalog.primaryID(for: mode))
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 280)
            Divider().opacity(0.35)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(PrismTheme.dominantGradient)
    }

    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchHits: [SiftHelpArticle] {
        SiftHelpCatalog.all.filter { $0.matches(query) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(Locale.current.language.languageCode?.identifier == "fr" ? "Aide" : "Help")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .prismClickable()
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PrismTheme.textTertiary)
                TextField("Search help", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(PrismTheme.surfaceMuted.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if searching {
                        ForEach(searchHits) { article in
                            row(article)
                        }
                    } else {
                        sectionLabel(SiftHelpCatalog.pageName(for: mode))
                        ForEach(SiftHelpCatalog.forPage(mode)) { article in
                            row(article)
                        }
                        sectionLabel(Locale.current.language.languageCode?.identifier == "fr" ? "Autres pages" : "Other pages")
                            .padding(.top, 10)
                        ForEach(SiftHelpCatalog.otherPages(mode)) { article in
                            row(article)
                        }
                    }
                }
            }
        }
        .padding(14)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PrismTheme.textTertiary)
            .padding(.horizontal, 10)
            .padding(.top, 4)
    }

    private func row(_ article: SiftHelpArticle) -> some View {
        Button {
            selectedID = article.id
        } label: {
            Text(article.resolvedTitle())
                .font(.subheadline.weight(selectedID == article.id ? .semibold : .regular))
                .foregroundStyle(PrismTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selectedID == article.id ? PrismTheme.accentSoft : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .prismClickable()
    }

    private var detail: some View {
        Group {
            if let article = SiftHelpCatalog.all.first(where: { $0.id == selectedID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(article.resolvedTitle())
                            .font(.title2.weight(.bold))
                            .foregroundStyle(PrismTheme.textPrimary)
                        Text(article.resolvedBody())
                            .font(.body)
                            .foregroundStyle(PrismTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
