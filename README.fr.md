<div id="readme-top"></div>

# Sift

Sift catalogue les photos, vidéos, musiques et documents déjà sur votre Mac.

**Découvrir** les trouve. **Bibliothèque** permet de les voir. **Organiser** attend que vous approuviez un plan.

Les fichiers restent où ils sont tant que vous ne décidez pas le contraire.

[English](./README.md) · **Français** · [Journal][changelog-link] · [Guide release][release-link] · [Attributions][attributions-link] · [Retours][github-issues-link]

<br/>

[![][github-release-shield]][github-release-link]
[![][macos-shield]][macos-requirements-link]
[![][swift-shield]][swift-link]
[![][platform-shield]][platform-link]
[![][github-action-test-shield]][github-action-test-link]
[![][github-contributors-shield]][github-contributors-link]
[![][github-forks-shield]][github-forks-link]
[![][github-stars-shield]][github-stars-link]
[![][github-issues-shield]][github-issues-link]
[![][github-license-shield]][github-license-link]

**Partager Sift**

[![][share-x-shield]][share-x-link]
[![][share-telegram-shield]][share-telegram-link]
[![][share-reddit-shield]][share-reddit-link]
[![][share-linkedin-shield]][share-linkedin-link]
[![][share-mastodon-shield]][share-mastodon-link]

**Vos médias, sur place. Un catalogue auquel vous pouvez faire confiance.**

<br/>

<details>
<summary><kbd>Sommaire</kbd></summary>

<br/>

- [Pour commencer](#-pour-commencer)
- [Fonctions](#-fonctions)
- [Installer](#-installer-sift)
- [Confidentialité](#-confidentialité)
- [Développement](#️-développement-local)
- [Contribuer](#-contribuer)
- [Soutenir](#️-soutenir)
- [Projets liés](#-projets-liés)

<br/>

</details>

<p align="center">
  <a href="https://assets.aisance.cloud/sift/sift-demo.mp4?v=2"><img src="https://assets.aisance.cloud/sift/sift-demo-poster.jpg?v=2" alt="Vidéo de démonstration de Sift" width="820"></a>
  <br/>
  <sub>▶ <a href="https://assets.aisance.cloud/sift/sift-demo.mp4?v=2">Voir la visite de 1 min 46 : configuration, scan, bibliothèque, règle de dossier et réglages.</a></sub>
</p>

| Premier lancement | Lecture des fichiers | Bibliothèque |
| :--: | :--: | :--: |
| <img src="https://assets.aisance.cloud/sift/screens/setup-welcome.jpg?v=2" width="270" alt="Premier lancement"> | <img src="https://assets.aisance.cloud/sift/screens/setup-reading.jpg?v=2" width="270" alt="Lecture des fichiers"> | <img src="https://assets.aisance.cloud/sift/screens/library-photos.jpg?v=2" width="270" alt="Bibliothèque"> |
| **Règles de dossier** | **Réglages** | |
| <img src="https://assets.aisance.cloud/sift/screens/rules.jpg?v=2" width="270" alt="Règles de dossier"> | <img src="https://assets.aisance.cloud/sift/screens/settings.jpg?v=2" width="270" alt="Réglages"> | |

<sub>Photos de démonstration Unsplash, créditées dans [docs/demo-credits.md](./docs/demo-credits.md). Aucun vrai fichier n’apparaît dans la vidéo.</sub>

## 👋🏻 Pour commencer

Sift est une app macOS pour qui veut un catalogue cherchable sans réorganisation silencieuse du disque. Photos, vidéos, musiques et certains documents sont indexés là où ils vivent déjà. Un plan d’organisation est un aperçu. Rien n’est copié ni déplacé tant que vous ne l’approuvez pas.

La compréhension tourne sur l’appareil : Apple Vision, et un modèle CLIP inclus pour la recherche visuelle. Jev est optionnel. Avec une clé, Entrée peut ouvrir un écran ou choisir dans une courte liste de noms de fichiers et de tags. Les pixels et le texte des documents restent sur le Mac.

| | |
| :-- | :-- |
| [![][github-stars-shield]][github-stars-link] | **Étoile** — suivre les versions sur GitHub. |
| [![][github-issues-shield]][github-issues-link] | **Ouvrir une issue** — bugs, idées, retours. |

<br/>

## ✨ Fonctions

### Premier lancement

Une configuration en six étapes s’ouvre au premier lancement : langue et apparence, dossiers à cataloguer (Images, Téléchargements, Bureau… un clic chacun), le dossier où ranger, qui lit les fichiers pour les règles, des règles prêtes pour Téléchargements, puis une page de démarrage. Chaque étape peut être passée ; relancez-la depuis les Réglages.

### Apparence et langue

Six skins (Citadel, Ocean, Forest, Dune, Orchid, Graphite), clair, sombre ou comme le Mac, et quatre tailles d’interface. L’interface parle anglais et français ; les écrans pas encore traduits restent en anglais, et [les traductions sont bienvenues](./CONTRIBUTING.md#translations). Les Réglages s’ouvrent par-dessus la fenêtre, avec une barre latérale et un bouton Retour.

### Découvrir

Choisissez quoi chercher — photos, vidéos, audio, documents — puis scannez ce Mac ou des dossiers. « Look again » nomme les dossiers enregistrés avant de démarrer. La ligne de progression nomme les types cochés. Un changement plus tard dans un dossier enregistré ne vérifie que ces fichiers. Un parcours complet de Téléchargements, ou d’un autre dossier, n’a lieu que si vous le demandez.

Les types de documents sont docx, xlsx, pptx, pdf, csv, md, mdx, txt et rtf. Les fichiers déjà au catalogue restent si vous rétrécissez le scan suivant. Les arbres de développement, dépendances, apps, caches et dossiers système sont ignorés.

### Bibliothèque

Grille, liste et Garden. Survoler un élément ouvre sa carte sans ouvrir le grand lecteur. Un clic ouvre le lecteur.

Les tuiles audio montrent une forme d’onde et le nom du fichier, avec un lecteur dans la carte. La vidéo se lit dans la carte. Les documents s’ouvrent dans Quick Look, y compris les fichiers Office et les PDF. Les photos gardent leur image. Les documents et l’audio affichent la date d’entrée dans le catalogue.

Garden est une vue spatiale du même catalogue, en quatre dispositions : Orbit, Spiral, Depth et Drift. Défilez ou glissez pour avancer, cliquez une photo pour l’inspecter. Sift retient la dernière disposition. La barre latérale reste calme : types de médias et personnes que vous avez acceptées.

### Revue

Suggestions de personnes et groupes de doublons. Accepter ajoute une personne à la barre latérale. Ignorer masque une carte. Ni l’un ni l’autre ne supprime un fichier. Mettre les extras d’un doublon à la corbeille demande une confirmation, puis ne retire que ces lignes du catalogue.

### Organiser

Trois étapes, et rien ne part avant le dernier bouton.

1. **Où** — choisissez le dossier dans lequel les fichiers doivent entrer. Sift écrit dedans, pas dans le dossier au-dessus.
2. **Originaux** — choisissez Move, Copy, ou Copy puis demander. Copy n’est pas supposé. Le bouton dit le verbe et le nom du dossier.
3. **Relecture** — les fichiers en attente, ceux déjà dans le dossier, et les originaux qui ont encore une copie sont comptés à part.

Vous pouvez activer les dossiers vides à créer (Photos, Videos, Music & Audio, et les autres) avant qu’un fichier ne bouge. Les transferts récents peuvent être annulés dans Réglages quand le chemin d’origine existe encore.

### Règles

Une règle se lit comme un court bloc, une ligne colorée par partie : *quand un nouveau fichier arrive dans **Downloads** et **c’est un PDF*** ; ***Sift** le lit pour vérifier que c’est **une facture ou un reçu** et note **vendor**, **date**, **amount*** ; *le renommer en **{vendor} {date}*** ; *le ranger dans **Sorted › Factures › {year}***. Cliquez une valeur colorée pour la changer. Ajoutez une condition ou une étape pour aller plus loin, y compris des étiquettes Finder et libérer l’espace une fois le fichier dans iCloud Drive.

Des modèles couvrent factures, contrats, fiches de paie, relevés bancaires, captures, installeurs et grosses vidéos ; chaque règle se modifie, se réordonne ou se supprime, et vous pouvez décrire les vôtres. Les règles sont vérifiées de haut en bas et seule la première qui convient agit sur un fichier. Avant d’activer une règle, Sift liste les fichiers déjà présents et ce qui arriverait à chacun. Les nouveaux fichiers retenus attendent dans **À valider**, ou sont rangés seuls ; l’**Historique** liste chaque changement avec Annuler. Les règles tournent tant que Sift est ouvert, y compris depuis la barre de menus fenêtre fermée.

Qui lit les fichiers, c’est vous qui choisissez, dans Réglages › Who reads files for rules :

| Lecteur | Où va le texte |
| :-- | :-- |
| Sift sur ce Mac (par défaut) | Nulle part. Mots-clés, dates et montants trouvés par Sift |
| Apple Intelligence | Nulle part. Modèle Apple sur l’appareil, macOS 26 |
| Modèle local : Ollama, LM Studio, MLX (`mlx_lm.server`), llama.cpp | Votre serveur. Sur `localhost`, nulle part |
| Claude, avec votre clé API Anthropic | Anthropic : le nom du fichier et jusqu’à 6 000 caractères du début du texte |
| Jev | Jev : seulement la question oui/non |

La phrase de la règle nomme toujours le lecteur, avec un cadenas quand rien ne quitte le Mac. Si le lecteur choisi n’est pas configuré ou échoue, Sift lit le fichier lui-même et le dit ; une règle réglée pour ranger tout de suite attend alors votre accord.

### Grandes bibliothèques et iCloud

Sift ne télécharge jamais un fichier d’iCloud Drive pour le regarder. Les fichiers restés dans le cloud (iCloud Drive, Optimiser le stockage, autres dossiers cloud) sont catalogués d’après leur nom, leur taille et leurs dates, et marqués comme dans iCloud. Aperçus, Vision, CLIP, documents et règles attendent que le fichier soit sur le Mac. Un réglage au niveau du processus le garantit : une lecture qui téléchargerait un fichier échoue à la place.

Les scans se font en flux : les fichiers entrent au catalogue par lots de 500, donc un disque de 2 To ne tient jamais en mémoire sous forme d’une seule liste. Un lot ne contient que des métadonnées, environ 1 Ko par fichier, quelle que soit sa taille. Les lecteurs qui chargent un contenu respectent un budget mémoire : 5 % de la RAM, au plus la moitié de la mémoire libre, entre 64 Mo et 1 Go par fichier. Vidéos et audio sont lus par petits morceaux et ne comptent jamais pour leur taille entière.

Fenêtre au premier plan, Sift travaille à pleine vitesse. Dans la seule barre de menus, il passe sur les cœurs efficacité, espace les fichiers, et se met en pause quand le Mac chauffe, en mode Économie d’énergie, ou quand la mémoire manque. Les changements de dossier qui arrivent pendant un scan sont mis en file, pas perdus.

### Notch

Le rail se range à droite quand la fenêtre de Sift le recouvre, y compris en plein écran. Un onglet orange reste sur le bord de l’écran, au-dessus de la fenêtre. Cliquez-le ou glissez-le pour ouvrir le rail ou le ranger. Ce choix est mémorisé.

### Documents

Les fichiers bureautique, PDF et texte sont lus localement. Dans la bibliothèque ils s’ouvrent dans Quick Look. Chaque fichier garde des labels tirés de son contenu : les premières lignes, les titres, les noms de feuilles et les en-têtes de colonnes, plus un type comme tableur ou meeting. La recherche utilise ces labels. Avec une clé Jev, l’indexation demande une fois lesquels conviennent. Le reste du fichier reste sur ce Mac.

[![][back-to-top]](#readme-top)

<br/>

## 📥 Installer Sift

> [!TIP]
>
> Signature et notarisation : [RELEASE.fr.md](./RELEASE.fr.md).

### `A` Télécharger la dernière version

1. Ouvrez **[Releases][github-release-link]** et téléchargez le dernier `Sift.dmg`.
2. Ouvrez l’image disque et glissez **Sift** dans Applications.
3. Lancez-le. Le premier scan est une action à vous. Sift ne réorganise pas les fichiers tout seul.

| Étape | Action |
| :--: | :-- |
| 1 | Télécharger `Sift.dmg` depuis Releases |
| 2 | Glisser Sift dans Applications |
| 3 | Ouvrir Découvrir et choisir quoi scanner |

> [!NOTE]
>
> **Prérequis :** macOS 15 ou plus récent. Apple Silicon recommandé. La cible iOS dans `Sources/SiftIOS` n’est pas encore une app livrée.

<br/>

### `B` Compiler les sources

```bash
git clone https://github.com/cyberesia/sift.git
cd sift
./Scripts/fetch-clip-weights.sh
swift build --product Sift
swift run Sift
```

Les poids CLIP font environ 168 Mo et 121 Mo. GitHub refuse les fichiers de plus de 100 Mo, donc ils ne sont pas dans le dépôt. Au premier lancement, Sift les télécharge dans Application Support et les garde. `fetch-clip-weights.sh` est optionnel : il récupère les mêmes fichiers avant la compilation, depuis le dépôt Hugging Face cité dans [ATTRIBUTIONS.md][attributions-link]. L’app compile sans eux.

Une app empaquetée est plus fiable pour le focus de la fenêtre et les permissions de dossiers :

```bash
./Scripts/package-direct.sh
open .build/distribution/Sift.dmg
```

#### Prérequis

| Prérequis | Notes |
|-------------|--------|
| macOS 15+ | Plateformes du paquet Swift |
| Apple Silicon | Recommandé |
| Swift 6 / Xcode 16+ | `swift build` et `swift test` |

<br/>

## 🔒 Confidentialité

L’indexation, Vision, CLIP et la lecture des documents tournent sur ce Mac.

| Donnée | Quitte le Mac ? |
| :-- | :-- |
| Photos, vidéo, audio | Non |
| Fichiers documents | Non |
| Premières lignes, titres, noms de feuilles et en-têtes de colonnes | Seulement pendant l’indexation, si une clé Jev est enregistrée |
| Tags de documents, noms de fichiers, et une requête | Seulement si une clé Jev est enregistrée et que vous appuyez sur Entrée |
| Labels CLIP / Vision | Utilisés localement. Une courte liste peut accompagner cette même question Entrée |
| Début du texte d’un fichier lu par une règle | Seulement si vous avez choisi Claude, Jev ou un modèle sur une autre machine comme lecteur |
| Fichiers seulement dans iCloud | Jamais téléchargés par Sift. Catalogués d’après leurs métadonnées |

Sans clé, ou si la réponse est peu sûre, le résultat local reste. Les réglages décrivent la même limite.

Réinitialiser le catalogue sans toucher aux originaux : **Réglages → Maintenance → Reset library & settings…**

[![][back-to-top]](#readme-top)

<br/>

## ⌨️ Développement local

```bash
git clone https://github.com/cyberesia/sift.git
cd sift
swift test
swift run Sift
```

**Arborescence :**

```
Sources/
├── SiftCore/     # Scan, Vision, CLIP, documents, catalogue
├── SiftDesign/   # Interface Prism, Garden, notch
├── SiftApp/      # App macOS
└── SiftIOS/      # Coque iOS, pas encore une release

Scripts/package-direct.sh
Tests/SiftCoreTests/
```

`__inspire/` est ignoré par git. C’est une étagère de lecture locale, pas le produit. Les crédits sont dans [ATTRIBUTIONS.md][attributions-link].

[![][back-to-top]](#readme-top)

<br/>

## 🤝 Contribuer

- **[Guide de contribution](./CONTRIBUTING.md)**
- **[Sécurité](./SECURITY.md)** — signaler une vulnérabilité en privé
- **[Issues][github-issues-link]**

[![][pr-welcome-shield]][pr-welcome-link]

[![][back-to-top]](#readme-top)

<br/>

## ❤️ Soutenir

Sift est open source. La façon utile de soutenir la même équipe est d’utiliser les produits cloud qui vont avec.

**Cataloguer sur le Mac. Aller plus loin dans le cloud quand vous le voulez.**

| Plateforme | Rôle |
| :-- | :-- |
| **[Aisance Cloud][aisance-cloud-link]** | Vie quotidienne et apprentissage |
| **[Cyclones Cloud][cyclones-cloud-link]** | Vitrine métier sur [cyclones.cloud][cyclones-cloud-link] |

[![Essayer Aisance Cloud](https://img.shields.io/badge/Essayer_Aisance_Cloud-→-369eff?labelColor=151515&style=for-the-badge)][aisance-cloud-link]
[![Essayer Cyclones Cloud](https://img.shields.io/badge/Essayer_Cyclones_Cloud-→-8ae8ff?labelColor=151515&style=for-the-badge)][cyclones-cloud-link]

[![][back-to-top]](#readme-top)

<br/>

## 🔗 Projets liés

- **[Citadel][citadel-link]** — pare-feu macOS et agents locaux de Cyberesia.
- **[Codenotch](https://github.com/vinzdg/codenotch)** — inspiration du notch (MIT). Non inclus.
- **[Refgarden](https://github.com/AlbionaHoti/refgarden)** — inspiration de la galerie spatiale (MIT). Non inclus.
- **[DocJev](https://github.com/jerryjliu/docjev)** — inspiration du classement de documents (Apache-2.0). Non inclus.
- **[OpenCLIP](https://github.com/mlfoundations/open_clip)** — famille du modèle CLIP inclus.

[![][back-to-top]](#readme-top)

<br/>

---

<div align="center">

#### Licence

Copyright © 2026 [Cyclones AI][github-repo-link].

Licence **[MIT](./LICENSE)**.

Notices et crédits : [NOTICES.md](./NOTICES.md) · [ATTRIBUTIONS.md](./ATTRIBUTIONS.md)

</div>

<br/>

[aisance-cloud-link]: https://aisance.cloud
[attributions-link]: ./ATTRIBUTIONS.md
[back-to-top]: https://img.shields.io/badge/-BACK_TO_TOP-151515?style=flat-square
[changelog-link]: ./CHANGELOG.fr.md
[citadel-link]: https://github.com/cyberesia/citadel
[cyclones-cloud-link]: https://cyclones.cloud
[github-action-test-link]: https://github.com/cyberesia/sift/actions
[github-action-test-shield]: https://img.shields.io/github/actions/workflow/status/cyberesia/sift/test.yml?label=test&labelColor=151515&logo=githubactions&logoColor=white&style=flat-square
[github-contributors-link]: https://github.com/cyberesia/sift/graphs/contributors
[github-contributors-shield]: https://img.shields.io/github/contributors/cyberesia/sift?color=c4f042&labelColor=151515&style=flat-square
[github-forks-link]: https://github.com/cyberesia/sift/network/members
[github-forks-shield]: https://img.shields.io/github/forks/cyberesia/sift?color=8ae8ff&labelColor=151515&style=flat-square
[github-issues-link]: https://github.com/cyberesia/sift/issues
[github-issues-shield]: https://img.shields.io/github/issues/cyberesia/sift?color=ff80eb&labelColor=151515&style=flat-square
[github-license-link]: ./LICENSE
[github-license-shield]: https://img.shields.io/badge/license-MIT-blue?labelColor=151515&style=flat-square
[github-release-link]: https://github.com/cyberesia/sift/releases
[github-release-shield]: https://img.shields.io/github/v/release/cyberesia/sift?color=369eff&labelColor=151515&logo=github&style=flat-square
[github-repo-link]: https://github.com/cyberesia/sift
[github-stars-link]: https://github.com/cyberesia/sift/stargazers
[github-stars-shield]: https://img.shields.io/github/stars/cyberesia/sift?color=ffcb47&labelColor=151515&style=flat-square
[macos-requirements-link]: #prérequis
[macos-shield]: https://img.shields.io/badge/macOS-15%2B-000000?labelColor=151515&logo=apple&logoColor=white&style=flat-square
[platform-link]: https://github.com/cyberesia/sift
[platform-shield]: https://img.shields.io/badge/platform-macOS%20arm64-007ACC?labelColor=151515&style=flat-square
[pr-welcome-link]: https://github.com/cyberesia/sift/pulls
[pr-welcome-shield]: https://img.shields.io/badge/PR_welcome-→-ffcb47?labelColor=151515&style=for-the-badge
[release-link]: ./RELEASE.fr.md
[share-linkedin-link]: https://www.linkedin.com/sharing/share-offsite/?url=https%3A%2F%2Fgithub.com%2Fcyberesia%2Fsift
[share-linkedin-shield]: https://img.shields.io/badge/-share%20on%20linkedin-151515?labelColor=151515&logo=linkedin&logoColor=white&style=flat-square
[share-mastodon-link]: https://mastodon.social/share?text=Sift%20%E2%80%94%20catalogue%20photos%2C%20vid%C3%A9o%2C%20musique%20et%20documents%20l%C3%A0%20o%C3%B9%20ils%20sont.%20https%3A%2F%2Fgithub.com%2Fcyberesia%2Fsift
[share-mastodon-shield]: https://img.shields.io/badge/-share%20on%20mastodon-151515?labelColor=151515&logo=mastodon&logoColor=white&style=flat-square
[share-reddit-link]: https://www.reddit.com/submit?title=Sift%20%E2%80%94%20catalogue%20m%C3%A9dia%20local%20pour%20macOS&url=https%3A%2F%2Fgithub.com%2Fcyberesia%2Fsift
[share-reddit-shield]: https://img.shields.io/badge/-share%20on%20reddit-151515?labelColor=151515&logo=reddit&logoColor=white&style=flat-square
[share-telegram-link]: https://t.me/share/url?text=Sift%20%E2%80%94%20catalogue%20m%C3%A9dia%20local%20pour%20macOS&url=https%3A%2F%2Fgithub.com%2Fcyberesia%2Fsift
[share-telegram-shield]: https://img.shields.io/badge/-share%20on%20telegram-151515?labelColor=151515&logo=telegram&logoColor=white&style=flat-square
[share-x-link]: https://x.com/intent/tweet?text=Sift%20%E2%80%94%20catalogue%20photos%2C%20vid%C3%A9o%2C%20musique%20et%20documents%20sur%20place&url=https%3A%2F%2Fgithub.com%2Fcyberesia%2Fsift
[share-x-shield]: https://img.shields.io/badge/-share%20on%20x-151515?labelColor=151515&logo=x&logoColor=white&style=flat-square
[swift-link]: https://www.swift.org
[swift-shield]: https://img.shields.io/badge/Swift-6-F05138?labelColor=151515&logo=swift&logoColor=white&style=flat-square
