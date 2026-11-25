# Contributing to Sift

Thank you for your interest in Sift. This project is maintained by [Cyberesia](https://github.com/cyberesia).

## Before you start

- Read [README.md](./README.md) for the product shape and build instructions.
- Check [open issues](https://github.com/cyberesia/sift/issues) before starting large work.
- For security issues, see [SECURITY.md](./SECURITY.md). Do not open public issues for vulnerabilities.

## Development setup

Requirements: macOS 15+, Apple Silicon recommended, Swift 6 toolchain (Xcode 16+).

```bash
git clone https://github.com/cyberesia/sift.git
cd sift
swift build --product Sift
swift test
swift run Sift
```

`__inspire/` is a local reference folder and is gitignored. Do not add those trees to a pull request. Credit upstream projects in [ATTRIBUTIONS.md](./ATTRIBUTIONS.md) instead.

## Good first contributions

Small, well-bounded work that helps right away:

- **Translate a screen.** Discover, Library, Organize, Review AI and the notch are still English only. Pick one file in `Sources/SiftDesign/Prism/` and follow [Translations](#translations).
- **Add a rule template.** `FolderRuleTemplate` in `Sources/SiftCore/Rules/FolderRule.swift`, with a test in `Tests/SiftCoreTests/FolderRuleTests.swift`.
- **Teach Sift's own reading a document type.** Keyword families live in `SiftJudge.keywords(for:)`; date and amount patterns in `LocalExtraction`. Every pattern needs a test.
- **Add a skin.** One case and five colours in `PrismSkin` (`Sources/SiftDesign/Prism/PrismAppearance.swift`). Check it in light and dark.
- **Light mode polish.** A few views still draw white on purpose over photos; others may not. Screenshots of what looks wrong are a useful issue on their own.

## Translations

Copy is written next to the view that shows it, as `tr("English", "Français")` (`Sources/SiftCore/Localization/SiftLanguage.swift`). To translate a screen, wrap each visible string:

```swift
Text("Scan again")                     // before
Text(tr("Scan again", "Rescanner"))    // after
```

Keep the English unchanged, keep sentences short and plain, and use typographic quotes and apostrophes in French (« », ’). Help articles in `SiftHelp.swift` already take both languages. To add a third language, add a case to `SiftLanguage` and an argument to `tr`, then fill it screen by screen.

## Screenshots and recordings

Debug builds open straight on a screen, so you can capture it without clicking:

```bash
swift build
.build/debug/Sift -siftSetup YES -siftSetupStep 3                    # setup, step 4 (reading)
.build/debug/Sift -siftSettings general -sift.appearance.mode light  # settings in light mode
.build/debug/Sift -siftMode rules -sift.appearance.skin ocean        # rules in the Ocean skin
```

Arguments are not saved. Never put your own files or folder names in a screenshot for a pull request: use demo mode.

### Demo mode

Demo mode keeps its own settings, catalog, thumbnails and rules, and never touches yours. Point it at a folder of sample files you are free to show (it must sit outside this repository: Sift skips build folders and git projects on purpose):

```bash
.build/debug/Sift -siftDemo YES -siftDemoHome "/path/to/sample/Home" -siftDemoRules YES -siftMode rules
```

`-siftDemoHome` saves its `Pictures`, `Downloads`, `Desktop` and `Documents` subfolders as sources and creates `Sorted` as the destination. `-siftDemoRules YES` adds the three starter rules on `Downloads`.

## Pull requests

1. Fork the repo and create a feature branch from `main`.
2. Keep changes focused. One concern per PR when possible.
3. Match the Swift style of the surrounding code.
4. Add or update a test when the change has a clear expected result.
5. Update [CHANGELOG.md](./CHANGELOG.md) under `[Unreleased]` for user-visible changes.
6. Do not commit secrets, Sparkle keys, `.cursor/`, or catalogs under `~/Library`.

## License

By contributing, you agree that your contributions will be licensed under the same terms as the project ([MIT License](./LICENSE)).
