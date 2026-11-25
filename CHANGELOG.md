# Changelog

All notable changes to Sift are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **Rules, second version.** Rules read as a short block, one coloured line per part (when, read, rename, put in, tag), all in one type size. Rules are checked top to bottom and only the first that fits a file acts on it (reorder from the ⋯ menu). New steps: Finder tags, and freeing up space once a file is in iCloud Drive. New starting points: contracts, payslips, bank statements and large videos, next to invoices, screenshots and installers. To review and History replace Waiting and Activity.
- **First-run setup**: language and look, folders to catalog with one-click suggestions, a destination, who reads files (Sift, Apple Intelligence, a local or company model, Claude), ready-made Downloads rules, and a start page linking the main tasks. Reopen it from Settings or Sift › Run Setup….
- **Skins and appearance**: Citadel, Ocean, Forest, Dune, Orchid and Graphite; light, dark or same as the Mac; four interface sizes.
- **Language setting**: same as the Mac, English or French. Setup, Settings, Rules, mode names and help are translated.
- **Demo mode** (`-siftDemo YES` or `SIFT_DEMO=1`): its own settings, catalog, thumbnails and rules, so recordings never show real files.
- Debug builds accept `-siftSetup YES`, `-siftSetupStep N`, `-siftSettings <page>` and `-siftMode <mode>` for screenshots.

- **Rules.** Folder automations written as a sentence: watch a folder, check name, type or size, read the file to confirm what it is and note values, then rename it from a template and move it into a destination subfolder such as `Invoices/{year}`. Templates, or describe a rule and the chosen reader drafts it. A preview shows where every file would go before the rule is on. Rules start off, can wait for you (Waiting) or file right away, and every move is in Activity with Undo. Partial downloads are left alone until their size settles.
- **Who reads files for rules**, in Settings: Sift’s own on-device reading (default), Apple Intelligence (macOS 26), a local model through Ollama, LM Studio, `mlx_lm.server` or llama.cpp, Claude with your Anthropic API key (structured output, refusal fallbacks), or Jev. Keys live in the keychain. The rule sentence and the menu bar name the reader and whether text leaves the Mac.
- Menu bar shows rules that are on, and files waiting, with File and Review.

### Changed

- Settings open over the main window with a sidebar (General, Folders, Reading files, Organizing, Search, Updates, Maintenance) and a Back button, instead of a small separate window.
- Scans stream into the catalog in batches of 500 instead of holding every file in memory, with one catalog fetch per batch. The exclusion check runs once per folder instead of walking up from every file.
- Background work follows the window: user priority while Sift is in front; efficiency cores, pacing, and pauses for heat, Low Power Mode and memory pressure when only the menu bar is open. Vision no longer runs at user priority.
- Readers that load contents are held to a per-file memory budget (5 % of RAM, at most half of free memory, 64 MB to 1 GB).
- Folder events arriving during a scan are queued instead of dropped, and a burst of more than 400 changes is processed in chunks instead of truncated. FSEvents are handled off the main thread.

### Fixed

- Mode names no longer wrap (Bibliothèque in French).
- The notch rail is readable in light mode and follows Sift's light or dark choice.
- Indexing could download every iCloud Drive file to make previews, run Vision and CLIP, or read documents. Cloud-only files are now cataloged from metadata, marked, and left in iCloud, and the app refuses to materialize placeholders by reading them.

## [0.1.4] - 2026-09-25

### Added

- **Command field** — at the top of Discover. Type what you want: find files already in the catalog, add a folder or this Mac, or prepare a filing plan. Each folder opens the same field, limited to that folder, with an “Only …” pill. Nothing moves until the final confirmation.
- **Find in the catalog** — “find pictures with dogs”, “photos de chiens”. Sift searches what is already cataloged and always answers: the files that match, the closest-looking ones when nothing is labeled that way, or why nothing came back. The next button opens Library, or offers to scan more folders. “dogs” also finds labels stored as “dog”.
- **What a folder holds** — Discover shows each folder’s extensions and counts, so only part of it can be acted on.

### Changed

- **Organize** — Continue opens the Organize page with the plan already loaded. “What will change” opens only from Review the list. If the destination folder or the Move or Copy choice is still missing, the button returns to that step instead of staying disabled. The three steps match everywhere: destination, Move or Copy, review and file. Typing “move” or “copy” does not make the choice.

### Fixed

- The filing card follows the sentence. “Organize by date” replaces “Organize by type” as soon as that is clear.

## [0.1.3] - 2026-09-24

### Added

- Saved folders can be scanned again from Discover, without Finder. Each folder has Scan again, for new files or a scan that was stopped.

### Changed

- Include subfolders can be turned off. The next scan of that folder stays in the folder itself.
- Choosing a Library sidebar row opens Library, even from another page.

### Fixed

- The packaged app quit on launch because CLIP resources were not found.

## [0.1.2] - 2026-09-24

### Added

- **Garden layouts** — Orbit, Spiral, Depth, and Drift. Spiral is a funnel: photos rise and grow, and the one in focus zooms downward while staying fully on screen. Depth is a stack you drag, scroll, or step. Drift is moving columns. Sift remembers the last Library view and the last Garden layout.
- **Floating card** — the detail card floats over the gallery and follows the photo under the pointer, in Grid, List, and Garden.

### Changed

- Dates stay on documents and audio. Photos and videos no longer show the date they entered the catalog.
- The viewer fades from one photo to the next. The filmstrip scrolls with the vertical wheel, and the stage keeps one height. Buttons show the hand cursor.

### Fixed

- Forgetting a source only drops it from the catalog. Thumbnail cleanup cannot delete anything outside the cache, and removing originals after a copy sends them to the Trash.

## [0.1.1] - 2026-09-23

First downloadable release. Version 0.1.0 was the source snapshot on `main`. It was never published as a GitHub Release, and it had no DMG.

### Added

- **Updates** — on launch, and in Settings, Sift asks GitHub once a day if [Cyberesia/sift](https://github.com/Cyberesia/sift) has a newer release. An available update offers the latest DMG. Later remembers that version.
- **Help** — the ? opens on the page you are looking at and explains each control and each dialog, in English and French.

### Changed

- Document labels now come from the file: the opening, the headings, sheet names, and column headers. PDF text is read. With a Jev key, that short outline is judged once while the file is indexed.
- Reset asks you to choose Library, Settings, or both, and explains each one before anything is cleared. Other buttons that change the catalog, the files, or saved choices ask first.

## [0.1.0] - 2026-09-23

Source snapshot. Not a GitHub Release.

Sift catalogs photos, video, audio, and documents where they already are. Nothing is copied or moved until you choose that, in words, on the Organize screen.

### Added

- **Discover** — choose what to look for (photos, videos, audio, documents), then scan this Mac or pick folders. Look again names the saved folders it will search. The progress line names the kinds you turned on.
- **Library** — grid, list, and Garden. Hovering an item opens its card. Audio shows a waveform, the filename, and a player. Video plays in the card. Documents open in Quick Look (docx, xlsx, pptx, pdf, and the other text types). Each item shows the date it entered the catalog.
- **Organize** — three steps: where the files go, what happens to the originals (Move, Copy, or Copy then ask — nothing is assumed), then a review. Files are written inside the folder you named. The catalog separates files already in that folder, originals that still have a copy, and files that landed beside the folder.
- **Notch** — the side rail tucks to the screen edge when the Sift window covers it, including fullscreen. An orange tab stays above the window: click or drag to open or tuck it. That choice is remembered.
- **On-device understanding** — Apple Vision, plus CLIP for visual search. The first launch downloads the weight files, because each is over GitHub's 100MB limit.
- **Documents** — local reading of docx, xlsx, pptx, pdf, csv, md, mdx, txt, and rtf. Search and Jev see typed tags, not an excerpt of the file.
- **Quiet updates** — a change inside a saved folder checks those files. A full walk of a folder such as Downloads happens when you choose Look again.
- **Jev (optional)** — with a key saved, Return can route a command or pick among a short list. No key, or a low-confidence answer, keeps the local result. Pixels and document text stay on this Mac.

[Unreleased]: https://github.com/Cyberesia/sift/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/Cyberesia/sift/releases/tag/v0.1.4
[0.1.3]: https://github.com/Cyberesia/sift/releases/tag/v0.1.3
[0.1.2]: https://github.com/Cyberesia/sift/releases/tag/v0.1.2
[0.1.1]: https://github.com/Cyberesia/sift/releases/tag/v0.1.1
[0.1.0]: https://github.com/Cyberesia/sift/releases/tag/v0.1.0
