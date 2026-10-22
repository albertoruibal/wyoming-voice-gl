#!/bin/bash
# TTS -> STT round trip: synth a sentence with phoonnx, transcribe it
# with whisper, print both.
# Usage: [HOST=host] [VOICE=name] ./run_roundtrip.sh [10400] "texto"
set -euo pipefail
PORT="${1:-10400}"
TEXT="${2:-Ola, son a voz de celtia, proba de síntese en galego.}"
HOST="${HOST:-localhost}"
VOICE="${VOICE:-}"
PY="${PY:-python3}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WAV="$(mktemp /tmp/gl_tts_XXXX.wav)"
trap 'rm -f "$WAV"' EXIT
ARGS=(--host "$HOST" --port "$PORT" --text "$TEXT" --out "$WAV")
if [ -n "$VOICE" ]; then
  ARGS+=(--voice "$VOICE")
fi
"$PY" "$HERE/probe_tts.py" "${ARGS[@]}"
echo "---- STT hears: ----"
"$PY" "$HERE/probe_stt.py" --host "$HOST" "$WAV"
