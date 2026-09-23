# Sift Release Guide

The day-to-day build is a Swift package. A shareable build is a `.app` bundle produced by `Scripts/package-direct.sh`.

**Notarization is required** before you send that app to someone else's Mac. Signing alone is not enough for Gatekeeper.

## Build a local app

```bash
swift build -c release --product Sift
./Scripts/package-direct.sh
open .build/distribution/Sift.app
```

`package-direct.sh` builds the release binary, wraps it as `Sift.app`, and copies `Info.plist`. The bundle identifier defaults to `ai.cyclones.sift`.

## Sign (optional, local)

```bash
export SIGN_IDENTITY="Developer ID Application: Your Org (YOUR_TEAM_ID)"
./Scripts/package-direct.sh
```

Find an identity with:

```bash
security find-identity -v -p codesigning
```

The script signs with hardened runtime and `Packaging/Entitlements/Sift.entitlements` when `SIGN_IDENTITY` is set. It does not notarize or build a DMG.

## Notarize

After a Developer ID signature:

```bash
ditto -c -k --keepParent .build/distribution/Sift.app Sift.zip
xcrun notarytool submit Sift.zip --keychain-profile sift-notary --wait
xcrun stapler staple .build/distribution/Sift.app
```

Create the keychain profile once:

```bash
xcrun notarytool store-credentials sift-notary
```

`sift-notary` is only a local Keychain label. Apple never sees that name.

## GitHub release

The public repo is [github.com/Cyberesia/sift](https://github.com/Cyberesia/sift). Version **0.1.0** is `CFBundleShortVersionString` in `Sources/SiftApp/Info.plist` and the `[0.1.0]` section of [CHANGELOG.md](./CHANGELOG.md).

1. Tag the commit you shipped (`git tag -a v0.1.0 -m "Sift v0.1.0" && git push origin main && git push origin v0.1.0`).
2. Open **Releases** and attach the stapled `Sift.app` inside a zip (or a DMG you built locally).
3. Paste the matching section from [CHANGELOG.md](./CHANGELOG.md) into the release notes.

Do not attach `.env`, Sparkle private keys, or anything from `__inspire/`.
