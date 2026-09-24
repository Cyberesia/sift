# Journal des modifications

Les changements notables de Sift sont documentés ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Le détail anglais est dans [CHANGELOG.md](./CHANGELOG.md).

## [Non publié]

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

[Non publié]: https://github.com/Cyberesia/sift/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/Cyberesia/sift/releases/tag/v0.1.2
[0.1.1]: https://github.com/Cyberesia/sift/releases/tag/v0.1.1
[0.1.0]: https://github.com/Cyberesia/sift/releases/tag/v0.1.0
