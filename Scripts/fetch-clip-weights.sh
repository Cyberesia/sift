#!/usr/bin/env bash
# Downloads the two CLIP weight files GitHub will not accept (each is over 100MB).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Sources/SiftCore/Resources/CLIP"
BASE="https://huggingface.co/InspiratioNULL/CLIP-VIT-B-32-DataComp.XL-CoreML/resolve/main"

files=(
  "CLIP_ImageEncoder.mlmodelc/weights/weight.bin"
  "CLIP_TextEncoder.mlmodelc/weights/weight.bin"
)

for rel in "${files[@]}"; do
  out="$DEST/$rel"
  if [[ -f "$out" ]]; then
    echo "already present: $rel"
    continue
  fi
  mkdir -p "$(dirname "$out")"
  echo "downloading $rel"
  curl -fL --retry 3 --output "$out" "$BASE/$rel"
done

echo "CLIP weights ready."
