# Journal des modifications

Les changements notables de Sift sont documentés ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Le détail anglais est dans [CHANGELOG.md](./CHANGELOG.md).

## [Non publié]

### Ajouté

- **Règles, deuxième version.** Les règles se lisent comme un court bloc, une ligne colorée par partie (quand, lecture, nom, rangement, étiquettes), dans une seule taille de texte. Elles sont vérifiées de haut en bas et seule la première qui convient agit sur un fichier. Nouvelles étapes : étiquettes Finder, et libérer l’espace une fois dans iCloud Drive. Nouveaux modèles : contrats, fiches de paie, relevés bancaires et grosses vidéos. À valider et Historique remplacent En attente et Activité.
- **Configuration au premier lancement** : langue et apparence, dossiers à cataloguer en un clic, une destination, qui lit les fichiers (Sift, Apple Intelligence, modèle local ou d’entreprise, Claude), des règles prêtes pour Téléchargements, et une page de démarrage vers les tâches principales.
- **Skins et apparence** : Citadel, Ocean, Forest, Dune, Orchid et Graphite ; clair, sombre ou comme le Mac ; quatre tailles d’interface.
- **Réglage de langue** : comme le Mac, anglais ou français. Configuration, Réglages, Règles, noms des modes et aide sont traduits.

- **Règles.** Des automatisations de dossier écrites comme une phrase : surveiller un dossier, vérifier nom, type ou taille, lire le fichier pour confirmer ce qu’il est et noter des valeurs, puis le renommer d’après un modèle et le ranger dans un sous-dossier comme `Invoices/{year}`. Modèles prêts, ou décrire la règle pour que le lecteur choisi la rédige. Un aperçu montre où irait chaque fichier avant d’allumer la règle. Les règles démarrent éteintes, peuvent attendre votre accord (Waiting) ou ranger tout de suite, et chaque déplacement est dans Activity avec Annuler. Les téléchargements en cours sont laissés tranquilles jusqu’à ce que leur taille se stabilise.
- **Qui lit les fichiers pour les règles**, dans les Réglages : la lecture de Sift sur l’appareil (par défaut), Apple Intelligence (macOS 26), un modèle local via Ollama, LM Studio, `mlx_lm.server` ou llama.cpp, Claude avec votre clé API Anthropic, ou Jev. Les clés sont dans le trousseau. La phrase de la règle et la barre de menus nomment le lecteur et disent si du texte quitte le Mac.
- **Mode démo** (`-siftDemo YES`) : réglages, catalogue, miniatures et règles séparés, pour que les vidéos ne montrent jamais de vrais fichiers.
- La barre de menus affiche les règles allumées et les fichiers en attente.

### Modifié

- Les Réglages s’ouvrent par-dessus la fenêtre, avec une barre latérale et un bouton Retour, au lieu d’une petite fenêtre séparée.
- Les scans entrent au catalogue par lots de 500 au lieu de garder tous les fichiers en mémoire. Le contrôle d’exclusion se fait une fois par dossier.
- Le travail de fond suit la fenêtre : priorité utilisateur au premier plan ; cœurs efficacité, rythme espacé et pauses (chaleur, Économie d’énergie, mémoire) quand seule la barre de menus est ouverte.
- Les lecteurs de contenu respectent un budget mémoire par fichier (5 % de la RAM, au plus la moitié de la mémoire libre, 64 Mo à 1 Go).
- Les changements de dossier arrivés pendant un scan sont mis en file au lieu d’être perdus, et une rafale de plus de 400 changements est traitée par morceaux.

### Corrigé

- Les noms des modes ne passent plus à la ligne (Bibliothèque).
- Le rail du notch est lisible en mode clair et suit le choix clair ou sombre de Sift.
- L’indexation pouvait télécharger tous les fichiers d’iCloud Drive pour les aperçus, Vision, CLIP ou la lecture des documents. Les fichiers restés dans iCloud sont maintenant catalogués d’après leurs métadonnées et laissés dans le cloud.

## [0.1.4] - 2026-09-25

### Ajouté

- **Champ de commande** — en haut de Découvrir. On écrit ce qu’on veut : trouver des fichiers déjà catalogués, ajouter un dossier ou ce Mac, ou préparer un classement. Chaque dossier ouvre le même champ, limité à ce dossier, avec une pastille « Seulement … ». Rien n’est déplacé tant que la confirmation finale n’est pas donnée.
- **Trouver dans le catalogue** — « photos de chiens », « find pictures with dogs ». Sift cherche dans ce qui est déjà là et répond toujours : les fichiers qui correspondent, les plus proches si aucun n’est étiqueté ainsi, ou pourquoi il n’y a rien. Le bouton suivant ouvre la Bibliothèque, ou propose de scanner d’autres dossiers. « dogs » trouve aussi les labels « dog ».
- **Contenu d’un dossier** — Découvrir montre, pour chaque dossier, les extensions et leur nombre, pour n’en traiter qu’une partie.

### Modifié

- **Organiser** — Continuer ouvre la page Organiser avec le plan déjà chargé. « Ce qui va changer » ne s’ouvre que par Relire la liste. Si le dossier de destination ou le choix Move ou Copy manque encore, le bouton ramène à cette étape au lieu de rester grisé. Les trois étapes sont les mêmes partout : destination, Move ou Copy, relire et classer. Écrire « move » ou « copy » ne choisit pas à votre place.

### Corrigé

- La carte de classement suit la phrase. « Organiser par date » remplace « Organiser par type » dès que c’est clair.

## [0.1.3] - 2026-09-24

### Ajouté

- Les dossiers déjà catalogués se rescannent depuis Découvrir, sans le Finder. Chaque dossier a Scanner à nouveau, pour les nouveaux fichiers ou un scan interrompu.

### Modifié

- Inclure les sous-dossiers peut être désactivé. Le scan suivant de ce dossier reste dans le dossier lui-même.
- Choisir une ligne de la barre Bibliothèque ouvre la Bibliothèque, même depuis une autre page.

### Corrigé

- L’app empaquetée quittait au lancement parce que les ressources CLIP n’étaient pas trouvées.

## [0.1.2] - 2026-09-24

### Ajouté

- **Dispositions Garden** — Orbit, Spiral, Depth et Drift. Spiral est un entonnoir : les photos montent et grandissent, et celle au point net zoome vers le bas en restant entièrement à l’écran. Depth est une pile que l’on glisse, fait défiler ou avance. Drift, ce sont des colonnes en mouvement. Sift retient la dernière vue de la Bibliothèque et la dernière disposition Garden.
- **Carte flottante** — la fiche flotte au-dessus de la galerie et suit la photo sous le pointeur, en Grille, en Liste et dans Garden.

### Modifié

- Les dates restent sur les documents et l’audio. Les photos et les vidéos n’affichent plus la date d’entrée dans le catalogue.
- Le lecteur passe d’une photo à l’autre en fondu. La bande de vignettes défile avec la molette verticale, et la scène garde une hauteur fixe. Les boutons montrent le curseur main.

### Corrigé

- Oublier une source ne la retire que du catalogue. Le nettoyage des vignettes ne peut rien effacer hors du cache, et retirer les originaux après une copie les envoie à la Corbeille.

## [0.1.1] - 2026-09-23

Première version téléchargeable. La 0.1.0 est l’instantané des sources sur `main`. Elle n’a jamais été publiée comme release GitHub, et elle n’avait pas de DMG.

### Ajouté

- **Mises à jour** — au lancement, et dans les Réglages, Sift demande une fois par jour à GitHub si [Cyberesia/sift](https://github.com/Cyberesia/sift) a une version plus récente. Une mise à jour disponible propose le dernier DMG. Plus tard mémorise cette version.
- **Aide** — le ? s’ouvre sur la page affichée et explique chaque commande et chaque dialogue, en anglais et en français.

### Modifié

- Les labels d’un document viennent du fichier : l’ouverture, les titres, les noms de feuilles et les en-têtes de colonnes. Le texte des PDF est lu. Avec une clé Jev, ce court aperçu est jugé une fois pendant l’indexation.
- Reset demande de choisir Bibliothèque, Réglages, ou les deux, et explique chacun avant d’effacer. Les autres boutons qui changent le catalogue, les fichiers ou les choix enregistrés demandent d’abord.

## [0.1.0] - 2026-09-23

Instantané des sources. Pas une release GitHub.

Sift catalogue les photos, vidéos, audios et documents là où ils sont déjà. Rien n’est copié ni déplacé tant que vous ne l’avez pas choisi, en toutes lettres, dans Organiser.

### Ajouté

- **Découvrir** — choisir quoi chercher (photos, vidéos, audio, documents), puis scanner ce Mac ou des dossiers. « Look again » nomme les dossiers enregistrés qu’il va parcourir. La ligne de progression nomme les types cochés.
- **Bibliothèque** — grille, liste et Garden. Survoler un élément ouvre sa carte. L’audio montre une forme d’onde, le nom du fichier et un lecteur. La vidéo se lit dans la carte. Les documents s’ouvrent dans Quick Look (docx, xlsx, pptx, pdf, et les autres textes). Chaque élément affiche la date d’entrée dans le catalogue.
- **Organiser** — trois étapes : où vont les fichiers, ce qui arrive aux originaux (Move, Copy, ou Copy puis demander — rien n’est supposé), puis une relecture. Les fichiers sont écrits dans le dossier nommé. Le catalogue distingue ce qui est déjà dans ce dossier, les originaux qui ont encore une copie, et les fichiers déposés à côté du dossier.
- **Notch** — le rail se range sur le bord de l’écran quand la fenêtre de Sift le recouvre, y compris en plein écran. Un onglet orange reste au-dessus de la fenêtre : clic ou glisser pour l’ouvrir ou le ranger. Ce choix est mémorisé.
- **Compréhension sur l’appareil** — Apple Vision, plus CLIP pour la recherche visuelle. Le premier lancement télécharge les poids, parce que chacun dépasse la limite GitHub de 100 Mo.
- **Documents** — lecture locale des docx, xlsx, pptx, pdf, csv, md, mdx, txt et rtf. La recherche et Jev voient des tags typés, pas un extrait du fichier.
- **Mises à jour discrètes** — un changement dans un dossier enregistré ne vérifie que ces fichiers. Un parcours complet, par exemple de Téléchargements, n’a lieu que si vous choisissez Look again.
- **Jev (optionnel)** — avec une clé enregistrée, Entrée peut ouvrir un écran ou choisir dans une courte liste. Sans clé, ou si la réponse est peu sûre, le résultat local reste. Les pixels et le texte des documents restent sur ce Mac.

[Non publié]: https://github.com/Cyberesia/sift/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/Cyberesia/sift/releases/tag/v0.1.4
[0.1.3]: https://github.com/Cyberesia/sift/releases/tag/v0.1.3
[0.1.2]: https://github.com/Cyberesia/sift/releases/tag/v0.1.2
[0.1.1]: https://github.com/Cyberesia/sift/releases/tag/v0.1.1
[0.1.0]: https://github.com/Cyberesia/sift/releases/tag/v0.1.0
