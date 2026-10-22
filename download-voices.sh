#!/bin/bash
# Prefetch the Galician voice models so containers never download at runtime.
#
# What gets downloaded (and where it lands):
#   proxectonos/celtia  (~150 MB onnx)  -> $DATA_ROOT/phoonnx-data  (phoonnx HF cache)
#   phoonnx also keeps a synthesis cache under phoonnx-data/mycroft/
#
# Usage:
#   ./download-voices.sh              # run inside the phoonnx container
#   ./download-voices.sh --host HOST  # or run it remotely via docker exec over ssh
#
# Voice files are NOT in git (.gitignore keeps them out): only this script is,
# so a fresh clone can rebuild the same cache with one command.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

VOICE="${VOICE:-proxectonos/celtia}"
EXTRA_VOICES="${EXTRA_VOICES:-}"

if ! docker compose exec -T phoonnx true 2>/dev/null; then
  echo "error: phoonnx container not running (docker compose up -d phoonnx first)" >&2
  exit 1
fi

echo ">> prefetching $VOICE (+$EXTRA_VOICES) into phoonnx-data (HF cache) ..."
docker compose exec -T phoonnx python3 -m phoonnx.cli download "$VOICE"
for v in $EXTRA_VOICES; do
  docker compose exec -T phoonnx python3 -m phoonnx.cli download "$v"
done

echo ">> done. Voice cache:"
docker compose exec -T phoonnx sh -c "du -sh /home/ovos/.cache/huggingface 2>/dev/null || true"
