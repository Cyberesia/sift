# Sift Release Guide

The day-to-day build is a Swift package. A shareable build is `Sift.app` inside `Sift.dmg`, produced by `Scripts/package-direct.sh`.

**Notarization is required** before you send that app to someone else's Mac. Signing alone is not enough for Gatekeeper. A DMG built on this machine without `SIGN_IDENTITY` is for local install and for attaching to a release you control.

## Version

| | |
| :-- | :-- |
| Current | **0.1.3** (`CFBundleShortVersionString` in `Sources/SiftApp/Info.plist`, build `4`) |
| First GitHub Release | 0.1.1, asset `Sift.dmg`. The `v0.1.1` tag stays where it is. |
| 0.1.0 | Source snapshot on `main`. No GitHub Release, no tag on the remote, no DMG. |

## Build the app and the DMG

```bash
./Scripts/package-direct.sh
open .build/distribution/Sift.dmg
```

The script builds the release binary, wraps it as `Sift.app`, copies `Info.plist`, and writes `.build/distribution/Sift.dmg`. The disk image is named `Sift` plus the version in `Info.plist` (`Sift 0.1.2`) and contains the app plus a shortcut to Applications. The bundle identifier defaults to `ai.cyclones.sift`.

## Sign (optional, local)

```bash
export SIGN_IDENTITY="Developer ID Application: Your Org (YOUR_TEAM_ID)"
./Scripts/package-direct.sh
```

Find an identity with:

```bash
security find-identity -v -p codesigning
```

The script signs the app with hardened runtime and `Packaging/Entitlements/Sift.entitlements` when `SIGN_IDENTITY` is set, then signs the DMG. It does not notarize.

## Notarize

After a Developer ID signature:

```bash
xcrun notarytool submit .build/distribution/Sift.dmg --keychain-profile sift-notary --wait
xcrun stapler staple .build/distribution/Sift.dmg
```

Create the keychain profile once:

```bash
xcrun notarytool store-credentials sift-notary
```

`sift-notary` is only a local Keychain label. Apple never sees that name.

## GitHub release

The public repo is [github.com/Cyberesia/sift](https://github.com/Cyberesia/sift).

0.1.0 was never published there as a Release. 0.1.1 is the first downloadable release. The in-app updater reads `https://api.github.com/repos/Cyberesia/sift/releases/latest` and downloads the `.dmg` asset.

From the `sift` checkout, after the 0.1.2 commit is on `main`:

```bash
git tag -a v0.1.2 -m "Sift v0.1.2"
git push origin main
git push origin v0.1.2
gh release create v0.1.2 .build/distribution/Sift.dmg \
  --repo Cyberesia/sift \
  --title "Sift v0.1.2" \
  --notes-file CHANGELOG.md
```

Do not move the `v0.1.1` tag. Paste the `0.1.2` section from [CHANGELOG.md](./CHANGELOG.md) if you would rather not attach the whole file. The French notes are in [CHANGELOG.fr.md](./CHANGELOG.fr.md).

Do not attach `.env`, Sparkle private keys, or anything from `__inspire/`. Do not commit the DMG into git.
