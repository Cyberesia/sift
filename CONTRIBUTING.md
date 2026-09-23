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

## Pull requests

1. Fork the repo and create a feature branch from `main`.
2. Keep changes focused. One concern per PR when possible.
3. Match the Swift style of the surrounding code.
4. Add or update a test when the change has a clear expected result.
5. Update [CHANGELOG.md](./CHANGELOG.md) under `[Unreleased]` for user-visible changes.
6. Do not commit secrets, Sparkle keys, `.cursor/`, or catalogs under `~/Library`.

## License

By contributing, you agree that your contributions will be licensed under the same terms as the project ([MIT License](./LICENSE)).
