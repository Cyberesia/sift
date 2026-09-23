# Third-party notices

## License

Sift is licensed under the **MIT License** ([LICENSE](./LICENSE)). Copyright © 2026 Cyclones AI.

Keep this file, [ATTRIBUTIONS.md](./ATTRIBUTIONS.md), and [CHANGELOG.md](./CHANGELOG.md) with source distributions so upstream credit stays attached to the tree.

## Swift Package Manager dependencies

Declared in `Package.swift`:

| Package | Repository | License |
| :-- | :-- | :-- |
| Sparkle | https://github.com/sparkle-project/Sparkle | MIT (2-clause) |
| swift-transformers | https://github.com/huggingface/swift-transformers | Apache-2.0 |

Transitive packages (swift-collections, swift-crypto, yyjson, and others) are resolved by SwiftPM. Their licenses live in the package checkouts and are not copied into this repository.

## Bundled model

| Component | Location | License |
| :-- | :-- | :-- |
| CLIP ViT-B/32 DataComp Core ML | `Sources/SiftCore/Resources/CLIP/` | MIT — structure and tokenizer are in git. `weight.bin` files download on first launch; see `MODEL-NOTICE.md` |

## Inspiration that is not bundled

| Project | License | How Sift relates |
| :-- | :-- | :-- |
| [Codenotch](https://github.com/vinzdg/codenotch) | MIT | Notch / island interaction ideas. Code rewritten. |
| [Refgarden](https://github.com/AlbionaHoti/refgarden) | MIT | Spatial gallery ideas. Layout rewritten. |
| [DocJev](https://github.com/jerryjliu/docjev) | Apache-2.0 | Document labeling ideas. Reader and tag list are local. |

Details: [ATTRIBUTIONS.md](./ATTRIBUTIONS.md).

## Apple frameworks

Vision, SwiftUI, AppKit, and PhotoKit are used under Apple's SDK license. They are not redistributed.
