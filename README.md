# Voz en galego para Home Assistant

Wyoming pipelines for a fully local Galician voice assistant:
speech-to-text (STT) and text-to-speech (TTS), no cloud, docker-compose only.

    wake word -> voice satellite -> STT (whisper, GPU) -> HA pipeline (LLM) -> TTS (phoonnx)

## Services

| Service | Port | Proto | Voices / model |
|---|---|---|---|
| `whisper` (STT) | 10300 | wyoming | whisper.cpp large-v3-turbo, Vulkan (AMD 780M), lang `gl` |
| `phoonnx` (TTS) | 10400 (wyoming), 9666 (HTTP, localhost) | wyoming | **`proxectonos/celtia`** (Proxecto Nós), `brais`, plus aHoTTS voices |

phoonnx (TigreGótico/OpenVoiceOS, ILENIA-funded) carries the Proxecto Nós
Galician voices (celtia, brais) and is the only TTS here; its plugin also
serves piper-voices ports (e.g. piper/es_ES-davefx-medium) if you need more

## Requirements

- docker + compose (a host with `/dev/dri` for GPU STT; the CPU-only fallback
  is the commented `whisper` service in `compose.yml`).
- For whisper: Vulkan drivers on the host (`mesa-vulkan-drivers`), GPU access.
- Writable data dir relative to the compose file: `phoonnx-data/` (phoonnx voice
  and synthesis cache). `whisper-data/` is only used by the commented-out CPU
  fallback.

## Voices (not in git)

Voice weights never go into the repo. A fresh clone downloads them with:

    ./download-voices.sh            # prefetch celtia via phoonnx's own CLI

Override with `VOICE=proxectonos/brais ./download-voices.sh`, or add more:
`EXTRA_VOICES="hitz/gl_sabela-vits omnivoice/gl" ./download-voices.sh`.
The script uses the running service, or a one-off container if it is stopped.
The piper-voice ports (piper/<lang>-<name>-<quality>) are in the same index.

## Run

    # on the docker daemon host, from the repo folder:
    cd wyoming-voice-gl && docker compose up -d --build

    # launching from a different cwd (e.g. a container driving the docker socket):
    docker compose -f /path/to/wyoming-voice-gl/compose.yml up -d --build

Volumes are **relative to the compose file** (`./phoonnx-data`). Passing `-f`
explicitly resolves them against the compose file's directory, so the data dirs
land in the repo regardless of the caller's cwd. The first build pulls the
large phoonnx image and the whisper model, so expect it to take a while.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `WHISPER_MODEL` | `large-v3-turbo` | whisper.cpp model, used at build time |
| `WHISPER_LANG` | `gl` | language passed to whisper |
| `TZ` | `Europe/Madrid` | timezone in both containers |
| `VOICE`, `EXTRA_VOICES` | `proxectonos/celtia` | voices prefetched by `download-voices.sh` |

Rebuild whisper after changing the model:
`WHISPER_MODEL=large-v3 docker compose build whisper`.

## Wire into Home Assistant

Settings → Devices & Services → Add Integration → **Wyoming**:

- STT: host of this machine, port `10300` (shows up as *faster-whisper*-style entity)
- TTS: port `10400` (phoonnx; entity like `tts.ovos_tts_plugin_phoonnx`)

Then **Settings → Assist → Pipelines** → create "Galego": STT = whisper (gl),
TTS = phoonnx (gl-ES, voice `ovos-tts-plugin-phoonnx`), conversation = your LLM
agent. Select the pipeline on the assist_satellite device.

### mycroft.conf (phoonnx voice pin)

```json
{
  "lang": "gl-ES",
  "tts": {
    "module": "ovos-tts-plugin-phoonnx",
    "ovos-tts-plugin-phoonnx": {
      "lang": "gl-ES",
      "voice": "proxectonos/celtia"
    }
  }
}
```

It lives at `tts/phoonnx-wyoming/mycroft.conf` and is bind-mounted read-only.
The bridge only reads plugin config from mycroft.conf (its env fallback does
not fill the advertised-language list), so edit the tracked file and
`docker compose restart phoonnx`.

## Troubleshooting

- `docker compose ps` should show both services as `healthy`; otherwise inspect
  `docker compose logs -f whisper phoonnx`.
- whisper needs a working `/dev/dri` and Vulkan driver. If the device is missing
  or not accessible by the `video` group, STT will not start.
- `VoiceNotFoundError` usually means the phoonnx cache or `mycroft.conf` is
  missing; run `./download-voices.sh` and verify the config mount.
- The phoonnx debug HTTP port `9666` is bound to loopback; use it from the docker
  host, not from another LAN machine.

## Tests

`tests/probe_tts.py` and `tests/probe_stt.py` speak/read back over wyoming;
install `tests/requirements.txt` and see `tests/README.md`. TTS->STT round-trip
is the quality check. CI validates the compose file, shell scripts, Dockerfiles
and Python syntax.

## Licenses / credits

- Code: Apache-2.0 (see LICENSE).
- Whisper.cpp: MIT; the large-v3-turbo model is Apache-2.0 (OpenAI Whisper).
- phoonnx: Apache-2.0 (TigreGótico / OpenVoiceOS); voice `proxectonos/celtia`
  corpus Nos_Celtia-GL: CC-BY-4.0 (Proxecto Nós / Universidade de Vigo).
  The aHoTTS voices (HiTZ) are CC-BY-4.0 too.
- wyoming protocol: MIT (Open Home Foundation).

