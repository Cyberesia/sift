# Guide de release Sift

La compilation de tous les jours est un paquet Swift. Une version à partager est `Sift.app` dans `Sift.dmg`, produit par `Scripts/package-direct.sh`.

**La notarisation est obligatoire** avant d’envoyer cette app sur le Mac de quelqu’un d’autre. Signer ne suffit pas pour Gatekeeper. Un DMG construit sur cette machine sans `SIGN_IDENTITY` sert à l’installation locale et à joindre une release que vous contrôlez.

Le détail anglais est dans [RELEASE.md](./RELEASE.md).

## Version

| | |
| :-- | :-- |
| Actuelle | **0.1.2** (`CFBundleShortVersionString` dans `Sources/SiftApp/Info.plist`, build `3`) |
| Première release GitHub | 0.1.1, fichier `Sift.dmg`. Le tag `v0.1.1` reste en place. |
| 0.1.0 | Instantané des sources sur `main`. Pas de release GitHub, pas de tag sur le dépôt distant, pas de DMG. |

## Construire l’app et le DMG

```bash
./Scripts/package-direct.sh
open .build/distribution/Sift.dmg
```

Le script compile le binaire de release, l’enveloppe dans `Sift.app`, copie `Info.plist`, et écrit `.build/distribution/Sift.dmg`. L’image disque s’appelle `Sift` plus la version de `Info.plist` (`Sift 0.1.2`) et contient l’app plus un raccourci vers Applications. L’identifiant du bundle est `ai.cyclones.sift` par défaut.

## Signer (optionnel, en local)

```bash
export SIGN_IDENTITY="Developer ID Application: Your Org (YOUR_TEAM_ID)"
./Scripts/package-direct.sh
```

Trouver une identité :

```bash
security find-identity -v -p codesigning
```

Le script signe l’app avec le hardened runtime et `Packaging/Entitlements/Sift.entitlements` quand `SIGN_IDENTITY` est défini, puis signe le DMG. Il ne notarise pas.

## Notariser

Après une signature Developer ID :

```bash
xcrun notarytool submit .build/distribution/Sift.dmg --keychain-profile sift-notary --wait
xcrun stapler staple .build/distribution/Sift.dmg
```

Créer le profil du Trousseau une fois :

```bash
xcrun notarytool store-credentials sift-notary
```

`sift-notary` n’est qu’une étiquette locale du Trousseau. Apple ne voit pas ce nom.

## Release GitHub

Le dépôt public est [github.com/Cyberesia/sift](https://github.com/Cyberesia/sift).

La 0.1.0 n’y a jamais été publiée comme release. La 0.1.1 est la première version téléchargeable. La recherche de mise à jour dans l’app lit `https://api.github.com/repos/Cyberesia/sift/releases/latest` et télécharge le fichier `.dmg`.

Depuis la copie `sift`, une fois le commit 0.1.2 sur `main` :

```bash
git tag -a v0.1.2 -m "Sift v0.1.2"
git push origin main
git push origin v0.1.2
gh release create v0.1.2 .build/distribution/Sift.dmg \
  --repo Cyberesia/sift \
  --title "Sift v0.1.2" \
  --notes-file CHANGELOG.md
```

Ne déplacez pas le tag `v0.1.1`. Collez la section `0.1.2` de [CHANGELOG.fr.md](./CHANGELOG.fr.md) si vous préférez les notes en français. L’anglais est dans [CHANGELOG.md](./CHANGELOG.md).

Ne joignez pas de `.env`, de clés privées Sparkle, ni quoi que ce soit de `__inspire/`. Ne commitez pas le DMG dans git.
