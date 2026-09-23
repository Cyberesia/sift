# Attributions

Sift is original Cyberesia software. Some interaction ideas were studied from other open-source projects and then written again here. Those projects are **not** included in this repository. 

## Codenotch (inspiration)

The edge-anchored notch — progress, hover cards, and quick actions — was informed by [Codenotch](https://github.com/vinzdg/codenotch) by Vinz.

- **License:** MIT
- **Repository:** https://github.com/vinzdg/codenotch

Sift's notch and island live in `Sources/SiftDesign/Prism/` and `Sources/SiftApp/`. They are not a copy of Codenotch.

## Refgarden (inspiration)

The spatial Garden was informed by [Refgarden](https://github.com/AlbionaHoti/refgarden) by Albiona Hoti.

- **License:** MIT
- **Repository:** https://github.com/AlbionaHoti/refgarden

`OrbitGardenView` and `OrbitLayout` are Sift's own layout. Refgarden is not bundled.

## DocJev (inspiration)

Document discovery — reading office and text files locally, then labeling them without sending the file body — was informed by [DocJev](https://github.com/jerryjliu/docjev) by Jerry Liu.

- **License:** Apache-2.0
- **Repository:** https://github.com/jerryjliu/docjev

Sift's reader is `Sources/SiftCore/Discovery/DocumentReader.swift`. It does not vendor DocJev, LibreOffice, or LiteParse. Tags are a closed list chosen on this Mac. See [NOTICES.md](./NOTICES.md).

## CLIP weights

The visual search model under `Sources/SiftCore/Resources/CLIP/` is a Core ML conversion of CLIP ViT-B/32 trained on DataComp-1B. The model structure and tokenizer are in git. The two `weight.bin` files are not: each is larger than GitHub's 100MB limit. The app downloads them on first launch. `Scripts/fetch-clip-weights.sh` can fetch them earlier.

- **Declared license:** MIT
- **Weights:** https://huggingface.co/InspiratioNULL/CLIP-VIT-B-32-DataComp.XL-CoreML
- **Training:** [OpenCLIP](https://github.com/mlfoundations/open_clip) and [DataComp](https://github.com/mlfoundations/datacomp)
- **Notice in-tree:** `Sources/SiftCore/Resources/CLIP/MODEL-NOTICE.md`

Inference stays on device. Sift does not upload photos or search text to Hugging Face.

## Jev / TypeSafe (optional service)

When a key is saved, Sift can ask [Jev](https://docs.typesafe.ai) a bounded choice question. The client is Cyberesia's. No TypeSafe SDK is bundled. Document text and pixels are not part of that request.
