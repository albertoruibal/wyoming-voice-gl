#!/bin/bash
# Prefetch the Galician voice models so containers never download at runtime,
# and point the phoonnx bridge at the selected voice.
#
# What gets downloaded (and where it lands):
#   <voice>  (~150 MB onnx)     -> phoonnx-data  (phoonnx HF cache)
#   ggml-<model>.bin (32 MB-3 GB) -> whisper-data  (bind-mounted at /models)
#   phoonnx also keeps a synthesis cache under phoonnx-data/mycroft/
#
# Which voice gets used is stored in tts/phoonnx-wyoming/mycroft.conf (the
# tracked file bind-mounted read-only into the container). This script rewrites
# its "voice" field, so the selection survives restarts.
#
# Usage:
#   ./setup.sh                     # menus: pick whisper model and voice
#   ./setup.sh proxectonos/brais   # pick the whisper model only
#   VOICE=proxectonos/brais ./setup.sh
#   EXTRA_VOICES="hitz/gl_sabela-vits omnivoice/gl" ./setup.sh
#   WHISPER_MODEL=large-v3 ./setup.sh   # skip the model prompt
#
# The whisper model is cached in whisper-data/ and mounted into the container,
# so it is not baked into the image and does not require a rebuild.
#
# When stdin is not a TTY, the defaults are large-v3-turbo and proxectonos/celtia.
#
# If the phoonnx service is running, the script uses docker compose exec.
# Otherwise it starts a one-off container (building the image if needed).
#
# Voices already present in the phoonnx/Hugging Face cache are skipped, so
# re-running the script does not download them again.
#
# Finally it starts the services (building any missing images) and restarts
# phoonnx, so a fresh clone goes from nothing to a running STT+TTS stack in one
# command. Editing mycroft.conf never needs a rebuild: it is a bind mount, and a
# phoonnx restart is enough.
#
# Voice files are NOT in git (.gitignore keeps them out): only this script is,
# so a fresh clone can rebuild the same cache with one command.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

require_docker_compose() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "!! docker not found; install Docker Engine first" >&2
    exit 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    echo "!! 'docker compose' (Compose v2 plugin) is not available" >&2
    echo "!! install the docker-compose-plugin (or enable it) and re-run ./setup.sh" >&2
    exit 1
  fi
}

require_docker_compose

WHISPER_MODEL="${WHISPER_MODEL:-}"
WHISPER_DEFAULT_MODEL=large-v3-turbo
WHISPER_MODEL_BASE_URL="${WHISPER_MODEL_BASE_URL:-https://huggingface.co/ggerganov/whisper.cpp/resolve/main}"
WHISPER_DATA="$HERE/whisper-data"
WHISPER_MODELS=(
  large-v3-turbo
  large-v3-turbo-q8_0
  large-v3-turbo-q5_0
  large-v3
  large-v3-q5_0
  large-v2
  large-v2-q8_0
  large-v2-q5_0
  large-v1
  medium
  medium-q8_0
  medium-q5_0
  small
  small-q8_0
  small-q5_1
  base
  base-q8_0
  base-q5_1
  tiny
  tiny-q8_0
  tiny-q5_1
)

whisper_model_cached() {
  [[ -s "$WHISPER_DATA/ggml-$1.bin" ]]
}

print_whisper_menu() {
  local i=1 model note
  echo "Available whisper.cpp models (multilingual; English-only .en variants also exist):"
  for model in "${WHISPER_MODELS[@]}"; do
    note=""
    [[ "$model" == "$WHISPER_DEFAULT_MODEL" ]] && note="default"
    if whisper_model_cached "$model"; then
      note="${note:+$note, }cached"
    fi
    if [[ -n "$note" ]]; then
      printf '   %2d) %s (%s)\n' "$i" "$model" "$note"
    else
      printf '   %2d) %s\n' "$i" "$model"
    fi
    i=$((i + 1))
  done
}

choose_whisper_model() {
  local choice model
  print_whisper_menu
  while true; do
    if ! read -r -p "Whisper model to download [1-${#WHISPER_MODELS[@]}, default 1]: " choice; then
      echo ">> no input; using ${WHISPER_DEFAULT_MODEL}" >&2
      choice=1
    fi
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#WHISPER_MODELS[@]})); then
      WHISPER_MODEL="${WHISPER_MODELS[choice - 1]}"
      return
    fi
    for model in "${WHISPER_MODELS[@]}"; do
      if [[ "$choice" == "$model" ]]; then
        WHISPER_MODEL="$model"
        return
      fi
    done
    echo "!! invalid selection: $choice" >&2
  done
}

fetch_whisper_model() {
  local dest="$WHISPER_DATA/ggml-${WHISPER_MODEL}.bin"
  local url="${WHISPER_MODEL_BASE_URL}/ggml-${WHISPER_MODEL}.bin"
  local tmp="${dest}.part"
  if whisper_model_cached "$WHISPER_MODEL"; then
    echo ">> whisper model ${WHISPER_MODEL} is already downloaded; skipping download"
    return 0
  fi
  mkdir -p "$WHISPER_DATA"
  echo ">> downloading whisper model ${WHISPER_MODEL} into whisper-data ..."
  if command -v curl >/dev/null 2>&1; then
    if ! curl -fL --retry 3 --retry-delay 2 -o "$tmp" "$url"; then
      rm -f "$tmp"
      echo "!! failed to download $url" >&2
      exit 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -O "$tmp" "$url"; then
      rm -f "$tmp"
      echo "!! failed to download $url" >&2
      exit 1
    fi
  else
    echo "!! need curl or wget on the host to download the whisper model" >&2
    exit 1
  fi
  mv "$tmp" "$dest"
  chmod 0644 "$dest" 2>/dev/null || true
  echo ">> saved ${WHISPER_MODEL} ($(du -h "$dest" | cut -f1)) to ${dest#"$HERE"/}"
}

PROXECTONOS_VOICES=(
  proxectonos/celtia
  proxectonos/brais
  proxectonos/celtia-cotovia
  proxectonos/brais-cotovia
  proxectonos/sabela-cotovia
  proxectonos/icia-cotovia
  proxectonos/icia-extended-cotovia
  proxectonos/paulo-cotovia
  proxectonos/iago-cotovia
  proxectonos/celtia-matcha-graphemes
  proxectonos/brais-matcha-graphemes
  proxectonos/icia-matcha-phonemes
  proxectonos/icia-extended-matcha-phonemes
  proxectonos/icia-matcha-phonemes-ljspeech
  proxectonos/icia-extended-matcha-phonemes-ljspeech
  proxectonos/celtia-styletts2
  proxectonos/brais-styletts2
)
AHOTTS_VOICES=(
  hitz/gl_celtia-vits
  hitz/gl_brais-vits
  hitz/gl_sabela-vits
  hitz/gl_icia-vits
  hitz/gl_iago-vits
  hitz/gl_paulo-vits
)
OTHER_VOICES=(
  OpenVoiceOS/phoonnx_gl-ES_miro_unicode
  omnivoice/gl
)
VOICE_IDS=("${PROXECTONOS_VOICES[@]}" "${AHOTTS_VOICES[@]}" "${OTHER_VOICES[@]}")

print_voice_menu() {
  local i=1 v
  echo "Available Galician voices:"
  echo "  Proxecto Nós (proxectonos/):"
  for v in "${PROXECTONOS_VOICES[@]}"; do
    printf '   %2d) %s\n' "$i" "$v"
    i=$((i + 1))
  done
  echo "  aHoTTS (hitz/):"
  for v in "${AHOTTS_VOICES[@]}"; do
    printf '   %2d) %s\n' "$i" "$v"
    i=$((i + 1))
  done
  echo "  Other:"
  for v in "${OTHER_VOICES[@]}"; do
    printf '   %2d) %s\n' "$i" "$v"
    i=$((i + 1))
  done
}

choose_voice() {
  local choice v
  print_voice_menu
  while true; do
    if ! read -r -p "Voice to download [1-${#VOICE_IDS[@]}, default 1]: " choice; then
      echo ">> no input; using ${VOICE_IDS[0]}" >&2
      choice=1
    fi
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#VOICE_IDS[@]})); then
      VOICE="${VOICE_IDS[choice - 1]}"
      return
    fi
    for v in "${VOICE_IDS[@]}"; do
      if [[ "$choice" == "$v" ]]; then
        VOICE="$v"
        return
      fi
    done
    echo "!! invalid selection: $choice" >&2
  done
}

update_voice_config() {
  local voice="$1"
  local conf="$HERE/tts/phoonnx-wyoming/mycroft.conf"
  if [[ ! -f "$conf" ]]; then
    echo "!! $conf not found; set its voice to '$voice' manually" >&2
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$conf" "$voice" <<'PY'
import json
import sys

path, voice = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as handle:
    config = json.load(handle)
plugin = config.setdefault("tts", {}).setdefault("ovos-tts-plugin-phoonnx", {})
plugin["voice"] = voice
with open(path, "w", encoding="utf-8") as handle:
    json.dump(config, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
PY
  else
    local escaped="${voice//&/\\&}"
    escaped="${escaped//|/\\|}"
    sed -i -E "s|(\"voice\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")|\1${escaped}\2|" "$conf"
  fi
  echo ">> set voice '$voice' in ${conf#"$HERE"/}"
}

if [[ -z "$WHISPER_MODEL" ]]; then
  if [[ -t 0 ]]; then
    choose_whisper_model
  else
    WHISPER_MODEL="$WHISPER_DEFAULT_MODEL"
  fi
fi

VOICE="${VOICE:-}"
if [[ $# -ge 1 ]]; then
  VOICE="$1"
fi
if [[ -z "$VOICE" ]]; then
  if [[ -t 0 ]]; then
    choose_voice
  else
    VOICE="${VOICE_IDS[0]}"
  fi
fi

EXTRA_VOICES="${EXTRA_VOICES:-}"

if docker compose ps --status running --services 2>/dev/null | grep -qx phoonnx; then
  run_phoonnx() { docker compose exec -T phoonnx "$@"; }
else
  echo ">> phoonnx is not running; using a one-off container (builds if needed) ..."
  run_phoonnx() {
    local entrypoint="$1"
    shift
    docker compose run --rm --no-deps --entrypoint "$entrypoint" phoonnx "$@"
  }
fi

voice_list=("$VOICE")
for v in $EXTRA_VOICES; do
  voice_list+=("$v")
done

check_voices() {
  run_phoonnx python3 - "$@" <<'PY'
import json
import sys

from phoonnx.model_manager import TTSModelManager, TTSModelInfo, _cached_path

manager = TTSModelManager()
manager.load()
catalog = None


def lookup(voice_id):
    global catalog
    info = manager.get_voice(voice_id)
    if info is not None:
        return info
    if catalog is None:
        catalog = {}
        for path in manager.voice_index_files():
            with open(path, encoding="utf-8") as handle:
                for key, entry in json.load(handle).items():
                    catalog.setdefault(key, entry)
    entry = catalog.get(voice_id)
    return TTSModelInfo(**entry) if entry is not None else None


for voice_id in sys.argv[1:]:
    info = lookup(voice_id)
    if info is None:
        print(f"unknown {voice_id}")
        continue
    urls = [info.model_url]
    if info.config_url:
        urls.append(info.config_url)
    urls.extend(url for url in info.artifact_urls() if url)
    if all(_cached_path(url) for url in urls):
        print(f"cached {voice_id}")
    else:
        print(f"missing {voice_id}")
PY
}

to_download=()
if ! check_output="$(check_voices "${voice_list[@]}")"; then
  echo ">> could not inspect the voice cache; downloading ${voice_list[*]} ..."
  to_download=("${voice_list[@]}")
else
  while IFS= read -r line; do
    case "$line" in
      "cached "*) echo ">> ${line#cached } is already downloaded; skipping" ;;
      "missing "*|"unknown "*) to_download+=("${line#* }") ;;
    esac
  done <<< "$check_output"
fi

if (( ${#to_download[@]} > 0 )); then
  echo ">> prefetching ${to_download[*]} into phoonnx-data (HF cache) ..."
  for v in "${to_download[@]}"; do
    run_phoonnx python3 -m phoonnx.cli download "$v"
  done
else
  echo ">> all selected voices are already downloaded"
fi

update_voice_config "$VOICE"

echo ">> done. Voice cache:"
run_phoonnx sh -c "du -sh /home/ovos/.cache/huggingface 2>/dev/null || true"

fetch_whisper_model

echo ">> starting services (missing images are built automatically) ..."
docker compose up -d

echo ">> restarting services to load '$VOICE' and '$WHISPER_MODEL' ..."
docker compose restart whisper phoonnx
docker compose ps
