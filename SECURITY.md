# Security Policy

## Supported versions

| Version | Supported |
| :-- | :--: |
| Latest release | Yes |
| `main` branch | Yes |
| Older releases | Best effort |

## Reporting a vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Report privately to the maintainers:

- **Email:** security@cyberesia.com *(preferred)*
- **GitHub:** use [Private vulnerability reporting](https://github.com/cyberesia/sift/security/advisories/new) if enabled on the repository

Include:

- A clear description of the issue and impact
- Steps to reproduce
- Affected versions or commits
- Any suggested fix, if you have one

We aim to acknowledge reports within **5 business days** and will coordinate disclosure once a fix is available.

## Scope

In scope:

- The Sift macOS app and its on-device catalog, Vision, and CLIP indexing
- Folder bookmarks, file transfer, and organization preview
- What text Sift sends when Jev is enabled (filenames, labels, and document tags — not pixels or document bodies)

Out of scope:

- The TypeSafe / Jev service itself — report those to TypeSafe
- Issues in upstream packages (Sparkle, swift-transformers, the bundled CLIP weights) — report those upstream
- Files the user chooses to catalog

## Safe harbor

We appreciate responsible disclosure and will not pursue legal action against researchers who follow this policy in good faith.
