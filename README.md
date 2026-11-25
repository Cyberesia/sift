<div id="readme-top"></div>

# Sift

Sift catalogs the photos, video, music, and documents already on your Mac.

**Discover** finds them. **Library** lets you look. **Organize** waits until you approve a plan.

Files stay where they are until you say otherwise.

> [!WARNING]
> **Early release (0.2).** Sift has not been tested on every Mac or folder setup yet, and it will have bugs. Before relying on folder rules, keep them on **Ask me before filing**, try them on a test folder first, and keep a backup. Problems and surprises are welcome as [issues][github-issues-link].

**English** · [Français](./README.fr.md) · [Changelog][changelog-link] · [Release guide][release-link] · [Attributions][attributions-link] · [Feedback][github-issues-link]

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

**Share Sift**

[![][share-x-shield]][share-x-link]
[![][share-telegram-shield]][share-telegram-link]
[![][share-reddit-shield]][share-reddit-link]
[![][share-linkedin-shield]][share-linkedin-link]
[![][share-mastodon-shield]][share-mastodon-link]

**Your media, in place. A catalog you can trust.**

<br/>

<details>
<summary><kbd>Table of contents</kbd></summary>

<br/>

- [Getting started](#-getting-started)
- [Features](#-features)
- [Install](#-install-sift)
- [Privacy](#-privacy)
- [Development](#️-local-development)
- [Contributing](#-contributing)
- [Sponsor](#️-sponsor)
- [Related projects](#-related-projects)

<br/>

</details>

<p align="center">
  <a href="https://assets.aisance.cloud/sift/sift-demo.mp4?v=2"><img src="https://assets.aisance.cloud/sift/sift-demo-poster.jpg?v=2" alt="Sift demo video" width="820"></a>
  <br/>
  <sub>▶ <a href="https://assets.aisance.cloud/sift/sift-demo.mp4?v=2">Watch the 1:46 tour: setup, scanning, the library, a folder rule, and settings.</a></sub>
</p>

| First run | Reading files | Library |
| :--: | :--: | :--: |
| <img src="https://assets.aisance.cloud/sift/screens/setup-welcome.jpg?v=2" width="270" alt="First run"> | <img src="https://assets.aisance.cloud/sift/screens/setup-reading.jpg?v=2" width="270" alt="Reading files"> | <img src="https://assets.aisance.cloud/sift/screens/library-photos.jpg?v=2" width="270" alt="Library"> |
| **Folder rules** | **Settings** | |
| <img src="https://assets.aisance.cloud/sift/screens/rules.jpg?v=2" width="270" alt="Folder rules"> | <img src="https://assets.aisance.cloud/sift/screens/settings.jpg?v=2" width="270" alt="Settings"> | |

<sub>Demo photos from Unsplash, credited in [docs/demo-credits.md](./docs/demo-credits.md). No real files appear in the video.</sub>

## 👋🏻 Getting started

Sift is a macOS app for people who want a searchable catalog without a silent rearrange of their disk. Photos, video, music, and selected documents are indexed where they already live. An organization plan is a preview. Nothing is copied or moved until you approve it.

Understanding runs on device: Apple Vision, and a bundled CLIP model for visual search. Jev is optional. With a key, Return can route a command or choose among a short list of filenames and tags. Pixels and document text stay on the Mac.

| | |
| :-- | :-- |
| [![][github-stars-shield]][github-stars-link] | **Star the repo** — follow releases on GitHub. |
| [![][github-issues-shield]][github-issues-link] | **Open an issue** — bugs, feature requests, and feedback. |

> [!IMPORTANT]
>
> **Star us** on GitHub to get notified on every release.

<br/>

## ✨ Features

### First run

A six-step setup opens on first launch: language and look, the folders to catalog (Pictures, Downloads, Desktop… one click each), the one folder tidied files go into, who reads files for rules, ready-made rules for Downloads, then a start page. Every step can be skipped; run it again from Settings.

### Appearance and language

Six skins (Citadel, Ocean, Forest, Dune, Orchid, Graphite), light, dark or same as the Mac, and four interface sizes. The interface speaks English and French; screens not yet translated stay in English, and [translations are welcome](./CONTRIBUTING.md#translations). Settings open over the window with a sidebar and a Back button.

### Discover

Choose what to look for — photos, videos, audio, documents — then scan this Mac or pick folders. Look again tells you which saved folders it will search before it starts. The progress line names the kinds you turned on. A later change inside a saved folder checks those files only. A full walk of Downloads, or any other folder, happens when you ask for it.

Document types are docx, xlsx, pptx, pdf, csv, md, mdx, txt, and rtf. Files already in the catalog stay if you narrow the next scan. Development trees, dependency folders, app bundles, caches, and system folders are skipped.

### Library

Grid, list, and Garden. Hovering an item opens its card without opening the full viewer. A click opens the viewer.

Audio tiles show a waveform and the filename, with a player in the card. Video plays in the card. Documents open through Quick Look, including Office files and PDF. Photos keep their image. Documents and audio show the date they entered the catalog.

Garden is a spatial view of the same catalog, in four layouts: Orbit, Spiral, Depth, and Drift. Scroll or drag to move, and click a photo to inspect. Sift remembers the last layout. The sidebar stays quiet: media kinds and people you have accepted.

### Review

People suggestions and duplicate groups. Accept adds a person to the sidebar. Dismiss hides a card. Neither deletes a file. Trashing duplicate extras asks first, then moves those files to the Trash and drops only those catalog rows.

### Organize

Three steps, and nothing happens until the last button.

1. **Where** — pick the folder files should go inside. Sift writes in that folder, not in the one above it.
2. **Originals** — choose Move, Copy, or Copy then ask. Copy is not assumed. The button says the verb and the folder name.
3. **Review** — waiting files, files already inside the folder, and originals that still have a copy are counted separately.

You can turn on the empty folders to create (Photos, Videos, Music & Audio, and the others) before any file moves. Recent transfers can be undone from Settings when the original path is still available.

### Rules

A rule reads as a short block, one coloured line per part: *when a new file arrives in **Downloads** and **it’s a PDF***; ***Sift** reads it to check it’s **an invoice or receipt** and notes **vendor**, **date**, **amount***; *rename it to **{vendor} {date}***; *put it in **Sorted › Invoices › {year}***. Click a coloured value to change it. Add a condition or a step for more, including Finder tags and freeing up space once a file is in iCloud Drive.

Starting points cover invoices, contracts, payslips, bank statements, screenshots, installers and large videos; every rule can be edited, reordered or deleted, and you can describe your own. Rules are checked top to bottom and only the first that fits a file acts on it. Before you switch a rule on, Sift lists the files already in the folder and what would happen to each. New matches wait in **To review**, or are filed on their own; **History** lists every change with Undo. Rules run while Sift is open, including from the menu bar with the window closed.

Who reads the files is your choice, in Settings › Who reads files for rules:

| Reader | Where the text goes |
| :-- | :-- |
| Sift on this Mac (default) | Nowhere. Keywords, dates and amounts found by Sift itself |
| Apple Intelligence | Nowhere. Apple’s on-device model, macOS 26 |
| Local model: Ollama, LM Studio, MLX (`mlx_lm.server`), llama.cpp | Your server. On `localhost`, nowhere |
| Claude, with your Anthropic API key | Anthropic: the file name and up to 6,000 characters of its opening text |
| Jev | Jev: the yes/no check only |

The rule sentence always names the reader, with a lock when nothing leaves the Mac. If the chosen reader is not set up, or fails, Sift reads the file itself and says so; a rule set to file right away then waits for you instead.

### Large libraries and iCloud

Sift never downloads a file from iCloud Drive to look at it. Placeholders (iCloud Drive, Optimize Mac Storage, other cloud folders) are cataloged from their name, size and dates only, and marked as in iCloud. Previews, Vision, CLIP, documents and rules wait until the file is on the Mac. A process-wide switch backs this up: a read that would download a placeholder fails instead.

Scans stream: files are written to the catalog 500 at a time, so a 2 TB disk never sits in memory as one list. A batch holds metadata only, about 1 KB per file, whatever the file’s size. Readers that load contents are held to a memory budget: 5 % of RAM, at most half of what is free, between 64 MB and 1 GB per file. Videos and audio are read in small pieces and are never costed at their full size.

With the window in front, Sift works at full speed. With only the menu bar, it moves to the efficiency cores, paces itself between files, and pauses while the Mac is warm, on Low Power Mode, or short on memory. Folder changes that arrive during a scan are queued, not dropped.

### Notch

The side rail tucks to the right when the Sift window covers it, including fullscreen. An orange tab stays on the screen edge, above the window. Click it or drag it to open the rail or tuck it away. That choice is remembered.

### Documents

Office files, PDF, and text files are read locally. In the library they open in Quick Look. Each file keeps labels taken from its content: the opening lines, the headings, the sheet names, and the column headers, plus a type such as spreadsheet or meeting. Search uses those labels. With a Jev key, indexing asks once which of them fit. The rest of the file stays on this Mac.

[![][back-to-top]](#readme-top)

<br/>

## 📥 Install Sift

> [!TIP]
>
> Maintainer signing and notarization are documented in [RELEASE.md][release-link].

### `A` Download the latest release

1. Open **[Releases][github-release-link]** and download the latest `Sift.dmg`.
2. Open the disk image and drag **Sift** to Applications.
3. Launch it. The first scan is something you start. Sift does not rearrange files on its own.

| Step | Action |
| :--: | :-- |
| 1 | Download `Sift.dmg` from Releases |
| 2 | Drag Sift to Applications |
| 3 | Open Discover and choose what to scan |

> [!NOTE]
>
> **Requirements:** macOS 15 or later. Apple Silicon recommended. The iOS target in `Sources/SiftIOS` is not a shipped app yet.

<br/>

### `B` Build from source

```bash
git clone https://github.com/cyberesia/sift.git
cd sift
./Scripts/fetch-clip-weights.sh
swift build --product Sift
swift run Sift
```

The CLIP weight files are about 168MB and 121MB. GitHub rejects files over 100MB, so they are not in the repository. The first time you open Sift, it downloads them into Application Support and keeps them there. `fetch-clip-weights.sh` is optional: it fetches the same files before you build, from the Hugging Face repo named in [ATTRIBUTIONS.md][attributions-link]. The app builds without them.

A bundled app is more reliable for window focus and folder permissions:

```bash
./Scripts/package-direct.sh
open .build/distribution/Sift.dmg
```

#### Requirements

| Requirement | Notes |
|-------------|--------|
| macOS 15+ | Swift package platforms |
| Apple Silicon | Recommended |
| Swift 6 / Xcode 16+ | `swift build` and `swift test` |

<br/>

## 🔒 Privacy

Indexing, Vision, CLIP, and document reading run on this Mac.

| Data | Leaves the Mac? |
| :-- | :-- |
| Photos, video, audio | No |
| Document files | No |
| Opening lines, headings, sheet names, and column headers | Only while indexing, if a Jev key is saved |
| Document tags, filenames, and a search query | Only if you saved a Jev key and press Return |
| CLIP / Vision labels | Used locally. A short label list may be included in that same Return question |
| Opening text of a file a rule reads | Only if you picked Claude, Jev, or a model on another machine as the rules reader |
| Files in iCloud only | Never downloaded by Sift. Cataloged from metadata |

No key, or a low-confidence answer, keeps the local result. Settings explains the same boundary.

Reset the catalog without touching your originals: **Settings → Maintenance → Reset library & settings…**

[![][back-to-top]](#readme-top)

<br/>

## ⌨️ Local development

```bash
git clone https://github.com/cyberesia/sift.git
cd sift
swift test
swift run Sift
```

**Layout:**

```
Sources/
├── SiftCore/     # Scan, Vision, CLIP, documents, catalog
├── SiftDesign/   # Prism UI, Garden, notch
├── SiftApp/      # macOS app
└── SiftIOS/      # iOS shell, not a release target yet

Scripts/package-direct.sh
Tests/SiftCoreTests/
```

`__inspire/` is gitignored. It is a local reading shelf, not part of the product. Credits for ideas that shaped Sift are in [ATTRIBUTIONS.md][attributions-link].

[![][back-to-top]](#readme-top)

<br/>

## 🤝 Contributing

- **[Contributing guide](./CONTRIBUTING.md)** — setup, PR expectations, license
- **[Security](./SECURITY.md)** — report vulnerabilities privately
- **[Issues][github-issues-link]** — bugs and feature requests

[![][pr-welcome-shield]][pr-welcome-link]

[![][back-to-top]](#readme-top)

<br/>

## ❤️ Sponsor

Sift is open source. The useful way to support the same team is to use the cloud products that sit next to it.

**Catalog on the Mac. Go further in the cloud when you want to.**

| Platform | What it is |
| :-- | :-- |
| **[Aisance Cloud][aisance-cloud-link]** | Everyday life and learning: campus, tutors, finance, chat, images |
| **[Cyclones Cloud][cyclones-cloud-link]** | Cyberesia’s business showcase on [cyclones.cloud][cyclones-cloud-link] |

[![Try Aisance Cloud](https://img.shields.io/badge/Try_Aisance_Cloud-→-369eff?labelColor=151515&style=for-the-badge)][aisance-cloud-link]
[![Try Cyclones Cloud](https://img.shields.io/badge/Try_Cyclones_Cloud-→-8ae8ff?labelColor=151515&style=for-the-badge)][cyclones-cloud-link]

Star the repo too. It helps other people find Sift.

[![][back-to-top]](#readme-top)

<br/>

## 🔗 Related projects

- **[Citadel][citadel-link]** — Cyberesia’s macOS firewall and local agents. Prism in Citadel took patterns from this design system.
- **[Codenotch](https://github.com/vinzdg/codenotch)** — notch inspiration (MIT). Not bundled.
- **[Refgarden](https://github.com/AlbionaHoti/refgarden)** — spatial gallery inspiration (MIT). Not bundled.
- **[DocJev](https://github.com/jerryjliu/docjev)** — document labeling inspiration (Apache-2.0). Not bundled.
- **[OpenCLIP](https://github.com/mlfoundations/open_clip)** — the model family behind the bundled CLIP weights.

[![][back-to-top]](#readme-top)

<br/>

---

<div align="center">

#### License

Copyright © 2026 [Cyclones AI][github-repo-link].

Licensed under the **[MIT License](./LICENSE)**.

Third-party notices and inspiration credits: [NOTICES.md](./NOTICES.md) · [ATTRIBUTIONS.md](./ATTRIBUTIONS.md)

</div>

<br/>

[aisance-cloud-link]: https://aisance.cloud
[attributions-link]: ./ATTRIBUTIONS.md
[back-to-top]: https://img.shields.io/badge/-BACK_TO_TOP-151515?style=flat-square
[changelog-link]: ./CHANGELOG.md
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
[macos-requirements-link]: #requirements
[macos-shield]: https://img.shields.io/badge/macOS-15%2B-000000?labelColor=151515&logo=apple&logoColor=white&style=flat-square
[platform-link]: https://github.com/cyberesia/sift
[platform-shield]: https://img.shields.io/badge/platform-macOS%20arm64-007ACC?labelColor=151515&style=flat-square
[pr-welcome-link]: https://github.com/cyberesia/sift/pulls
[pr-welcome-shield]: https://img.shields.io/badge/PR_welcome-→-ffcb47?labelColor=151515&style=for-the-badge
[release-link]: ./RELEASE.md
[share-linkedin-link]: https://www.linkedin.com/sharing/share-offsite/?url=https%3A%2F%2Fgithub.com%2Fcyberesia%2Fsift
[share-linkedin-shield]: https://img.shields.io/badge/-share%20on%20linkedin-151515?labelColor=151515&logo=linkedin&logoColor=white&style=flat-square
[share-mastodon-link]: https://mastodon.social/share?text=Sift%20%E2%80%94%20catalog%20photos%2C%20video%2C%20music%2C%20and%20documents%20where%20they%20already%20are.%20https%3A%2F%2Fgithub.com%2Fcyberesia%2Fsift
[share-mastodon-shield]: https://img.shields.io/badge/-share%20on%20mastodon-151515?labelColor=151515&logo=mastodon&logoColor=white&style=flat-square
[share-reddit-link]: https://www.reddit.com/submit?title=Sift%20%E2%80%94%20on-device%20media%20catalog%20for%20macOS&url=https%3A%2F%2Fgithub.com%2Fcyberesia%2Fsift
[share-reddit-shield]: https://img.shields.io/badge/-share%20on%20reddit-151515?labelColor=151515&logo=reddit&logoColor=white&style=flat-square
[share-telegram-link]: https://t.me/share/url?text=Sift%20%E2%80%94%20on-device%20media%20catalog%20for%20macOS&url=https%3A%2F%2Fgithub.com%2Fcyberesia%2Fsift
[share-telegram-shield]: https://img.shields.io/badge/-share%20on%20telegram-151515?labelColor=151515&logo=telegram&logoColor=white&style=flat-square
[share-x-link]: https://x.com/intent/tweet?text=Sift%20%E2%80%94%20catalog%20photos%2C%20video%2C%20music%2C%20and%20documents%20in%20place&url=https%3A%2F%2Fgithub.com%2Fcyberesia%2Fsift
[share-x-shield]: https://img.shields.io/badge/-share%20on%20x-151515?labelColor=151515&logo=x&logoColor=white&style=flat-square
[swift-link]: https://www.swift.org
[swift-shield]: https://img.shields.io/badge/Swift-6-F05138?labelColor=151515&logo=swift&logoColor=white&style=flat-square
