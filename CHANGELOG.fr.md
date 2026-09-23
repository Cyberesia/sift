# Journal des modifications

Les changements notables de Sift sont documentés ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Le détail anglais est dans [CHANGELOG.md](./CHANGELOG.md).

## [Non publié]

## [0.1.0] - 2026-09-23

Première version publique. Sift catalogue les photos, vidéos, audios et documents là où ils sont déjà. Rien n’est copié ni déplacé tant que vous ne l’avez pas choisi, en toutes lettres, dans Organiser.

### Ajouté

- **Découvrir** — choisir quoi chercher (photos, vidéos, audio, documents), puis scanner ce Mac ou des dossiers. « Look again » nomme les dossiers enregistrés qu’il va parcourir. La ligne de progression nomme les types cochés.
- **Bibliothèque** — grille, liste et Garden. Survoler un élément ouvre sa carte. L’audio montre une forme d’onde, le nom du fichier et un lecteur. La vidéo se lit dans la carte. Les documents s’ouvrent dans Quick Look (docx, xlsx, pptx, pdf, et les autres textes). Chaque élément affiche la date d’entrée dans le catalogue.
- **Organiser** — trois étapes : où vont les fichiers, ce qui arrive aux originaux (Move, Copy, ou Copy puis demander — rien n’est supposé), puis une relecture. Les fichiers sont écrits dans le dossier nommé. Le catalogue distingue ce qui est déjà dans ce dossier, les originaux qui ont encore une copie, et les fichiers déposés à côté du dossier.
- **Notch** — le rail se range sur le bord de l’écran quand la fenêtre de Sift le recouvre, y compris en plein écran. Un onglet orange reste au-dessus de la fenêtre : clic ou glisser pour l’ouvrir ou le ranger. Ce choix est mémorisé.
- **Compréhension sur l’appareil** — Apple Vision, plus CLIP pour la recherche visuelle. Le premier lancement télécharge les poids, parce que chacun dépasse la limite GitHub de 100 Mo.
- **Documents** — lecture locale des docx, xlsx, pptx, pdf, csv, md, mdx, txt et rtf. La recherche et Jev voient des tags typés, pas un extrait du fichier.
- **Mises à jour discrètes** — un changement dans un dossier enregistré ne vérifie que ces fichiers. Un parcours complet, par exemple de Téléchargements, n’a lieu que si vous choisissez Look again.
- **Jev (optionnel)** — avec une clé enregistrée, Entrée peut ouvrir un écran ou choisir dans une courte liste. Sans clé, ou si la réponse est peu sûre, le résultat local reste. Les pixels et le texte des documents restent sur ce Mac.

[Non publié]: https://github.com/Cyberesia/sift/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Cyberesia/sift/releases/tag/v0.1.0
