# Changelog

All notable changes to Sift are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0] - 2026-09-23

First public release. Sift catalogs photos, video, audio, and documents where they already are. Nothing is copied or moved until you choose that, in words, on the Organize screen.

### Added

- **Discover** — choose what to look for (photos, videos, audio, documents), then scan this Mac or pick folders. Look again names the saved folders it will search. The progress line names the kinds you turned on.
- **Library** — grid, list, and Garden. Hovering an item opens its card. Audio shows a waveform, the filename, and a player. Video plays in the card. Documents open in Quick Look (docx, xlsx, pptx, pdf, and the other text types). Each item shows the date it entered the catalog.
- **Organize** — three steps: where the files go, what happens to the originals (Move, Copy, or Copy then ask — nothing is assumed), then a review. Files are written inside the folder you named. The catalog separates files already in that folder, originals that still have a copy, and files that landed beside the folder.
- **Notch** — the side rail tucks to the screen edge when the Sift window covers it, including fullscreen. An orange tab stays above the window: click or drag to open or tuck it. That choice is remembered.
- **On-device understanding** — Apple Vision, plus CLIP for visual search. The first launch downloads the weight files, because each is over GitHub's 100MB limit.
- **Documents** — local reading of docx, xlsx, pptx, pdf, csv, md, mdx, txt, and rtf. Search and Jev see typed tags, not an excerpt of the file.
- **Quiet updates** — a change inside a saved folder checks those files. A full walk of a folder such as Downloads happens when you choose Look again.
- **Jev (optional)** — with a key saved, Return can route a command or pick among a short list. No key, or a low-confidence answer, keeps the local result. Pixels and document text stay on this Mac.

[Unreleased]: https://github.com/Cyberesia/sift/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Cyberesia/sift/releases/tag/v0.1.0
