#!/bin/bash

set -u

lang=gl
model=large-v3-turbo

cleanup() {
  kill "${whisper_pid:-}" "${wyoming_pid:-}" 2>/dev/null || true
  wait 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' TERM INT

while getopts "l:m:h" opt; do
  case ${opt} in
    l) lang=${OPTARG} ;;
    m) model=${OPTARG} ;;
    h) echo "Usage: $0 [-l lang] [-m model]"; exit 0 ;;
    *) echo "Usage: $0 [-l lang] [-m model]"; exit 1 ;;
  esac
done

echo "whisper-server: model=${model} lang=${lang} (vulkan)"
whisper-server -fa -l "${lang}" -m "/opt/whisper.cpp/models/ggml-${model}.bin" --host 127.0.0.1 --port 8910 &
whisper_pid=$!
/opt/wyoming-whisper-api-client/.venv/bin/python3 -m wyoming_whisper_api_client --api http://127.0.0.1:8910/inference --uri tcp://0.0.0.0:10300 &
wyoming_pid=$!

wait -n "${whisper_pid}" "${wyoming_pid}"
status=$?
exit "${status}"
