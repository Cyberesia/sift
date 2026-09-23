# Bundled CLIP model

- Model: CLIP ViT-B/32 DataComp-1B Core ML conversion
- Source: https://huggingface.co/InspiratioNULL/CLIP-VIT-B-32-DataComp.XL-CoreML
- License declared by the model repository: MIT
- Image and text output: normalized 512-dimensional shared embedding space

The model runs locally. Sift does not send media or search text to
Hugging Face.

The two `weight.bin` files are each larger than GitHub's 100MB limit, so they
are not in the git repository. The first launch downloads them into
Application Support. `Scripts/fetch-clip-weights.sh` can fetch the same files
before a build. The app still compiles without them.
