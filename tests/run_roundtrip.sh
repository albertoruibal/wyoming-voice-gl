#!/bin/bash
# TTS -> STT round trip: synth a sentence with phoonnx, transcribe it
# with whisper, print both. Usage: ./run_roundtrip.sh [10400] "texto"
set -e
PORT="${1:-10400}"
TEXT="${2:-Ola, son a voz de celtia, proba de síntese en galego.}"
HOST="${HOST:-localhost}"
PY="${PY:-python3}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WAV="$(mktemp /tmp/gl_tts_XXXX.wav)"
"$PY" "$HERE/probe_tts.py" --host "$HOST" --port "$PORT" --text "$TEXT" --out "$WAV"
echo "---- STT hears: ----"
"$PY" "$HERE/probe_stt.py" --host "$HOST" "$WAV"
