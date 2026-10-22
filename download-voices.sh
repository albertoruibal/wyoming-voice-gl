#!/bin/bash
# Prefetch the Galician voice models so containers never download at runtime.
#
# What gets downloaded (and where it lands):
#   proxectonos/celtia  (~150 MB onnx)  -> phoonnx-data  (phoonnx HF cache)
#   phoonnx also keeps a synthesis cache under phoonnx-data/mycroft/
#
# Usage:
#   ./download-voices.sh
#   VOICE=proxectonos/brais ./download-voices.sh
#   EXTRA_VOICES="hitz/gl_sabela-vits omnivoice/gl" ./download-voices.sh
#
# If the phoonnx service is running, the script uses docker compose exec.
# Otherwise it starts a one-off container (building the image if needed).
#
# Voice files are NOT in git (.gitignore keeps them out): only this script is,
# so a fresh clone can rebuild the same cache with one command.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

VOICE="${VOICE:-proxectonos/celtia}"
EXTRA_VOICES="${EXTRA_VOICES:-}"

if docker compose ps --status running --services 2>/dev/null | grep -qx phoonnx; then
  run_phoonnx() { docker compose exec -T phoonnx "$@"; }
else
  echo ">> phoonnx is not running; using a one-off container (builds if needed) ..."
  run_phoonnx() {
    local entrypoint="$1"
    shift
    docker compose run --rm --no-deps --build --entrypoint "$entrypoint" phoonnx "$@"
  }
fi

echo ">> prefetching $VOICE (+$EXTRA_VOICES) into phoonnx-data (HF cache) ..."
run_phoonnx python3 -m phoonnx.cli download "$VOICE"
for v in $EXTRA_VOICES; do
  run_phoonnx python3 -m phoonnx.cli download "$v"
done

echo ">> done. Voice cache:"
run_phoonnx sh -c "du -sh /home/ovos/.cache/huggingface 2>/dev/null || true"
