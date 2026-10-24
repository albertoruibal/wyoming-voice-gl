# Galician voice pipelines for Home Assistant

Wyoming pipelines for a fully local Galician voice assistant: speech-to-text (STT) and text-to-speech (TTS), no cloud,
docker-compose only.

    wake word -> voice satellite -> STT (whisper, GPU) -> HA pipeline (LLM) -> TTS (phoonnx)

## Services

| Service         | Port  | Proto     | Voices / model                                                       |
|-----------------|-------|-----------|----------------------------------------------------------------------|
| `whisper` (STT) | 10300 | wyoming   | whisper.cpp large-v3-turbo, Vulkan (AMD 780M), lang `gl`             |
| `phoonnx` (TTS) | 10400 | wyoming   | **`proxectonos/celtia`** (Proxecto Nós), `brais`, plus aHoTTS voices |

phoonnx ([TigreGótico/OpenVoiceOS](https://github.com/TigreGotico/phoonnx), ILENIA-funded) carries the
[Proxecto Nós](https://proxectonos.gal/) Galician voices (celtia, brais) and is the only TTS here; its plugin also
serves [piper voices](https://huggingface.co/rhasspy/piper-voices) (e.g. `piper/es_ES-davefx-medium`) if you need more.

## Prerequisites

- Linux host (the STT service passes through `/dev/dri`; this is not a Docker Desktop setup).
- Docker Engine with the Compose v2 plugin (`docker compose`, not the legacy `docker-compose`). `./setup.sh` checks both
  at startup and exits with a warning if they are missing.
- A Vulkan-capable GPU exposed at `/dev/dri`, readable by the `video` group, with host Vulkan/Mesa drivers installed
  (`mesa-vulkan-drivers`, plus `vulkaninfo` to verify).
- Outbound network access to build the images (Debian, GitHub, ghcr.io) and to download the models from Hugging Face.
- `curl` or `wget` on the host: `./setup.sh` uses it to fetch the whisper model.
- Writable `phoonnx-data/` and `whisper-data/` directories next to the compose file (voice cache and whisper model).

## Run

On the docker daemon host, from the repo folder:

```bash
cd wyoming-voice-gl && ./setup.sh
```

`./setup.sh` asks which whisper model and voice to use, downloads anything missing, updates `mycroft.conf`, then starts
the services (building only missing images) and restarts whisper and phoonnx. Config and model changes never rebuild
the images. Volumes are **relative to the compose file** (`./phoonnx-data`, `./whisper-data`). Passing `-f` explicitly
resolves them against the compose file's directory, so the data dirs land in the repo regardless of the caller's cwd.
The first build pulls the large phoonnx image, and the first setup downloads the whisper model, so expect it to take a
while. After changing a Dockerfile, run `docker compose build` explicitly.

## Configuration

| Variable        | Default          | Purpose                                                              |
|-----------------|------------------|----------------------------------------------------------------------|
| `WHISPER_MODEL` | `large-v3-turbo` | whisper.cpp model; chosen from the setup menu, or set it to skip      |
| `WHISPER_LANG`  | `gl`             | language passed to whisper                                           |
| `TZ`            | `Europe/Madrid`  | timezone in both containers                                          |
| `VOICE`         | (menu)           | skip the prompt, download this voice and set it in `mycroft.conf`    |
| `EXTRA_VOICES`  | none             | extra voices to prefetch without changing the active voice           |

The setup menu lists the multilingual whisper.cpp models (default `large-v3-turbo`; English-only `.en` variants can be
passed directly via `WHISPER_MODEL`). Set `WHISPER_MODEL` or `VOICE`, or pass a voice argument, to skip that prompt;
non-interactive runs use the defaults.

Change the whisper model with `WHISPER_MODEL=large-v3 ./setup.sh`: it downloads the model into `whisper-data/` and
restarts whisper. No image rebuild is needed. Override the download mirror with `WHISPER_MODEL_BASE_URL`.

### Models on disk

`./setup.sh` fetches both model sets and skips anything already cached; the whisper menu marks cached models:

- `whisper-data/ggml-<model>.bin` — bind-mounted at `/models`; not baked into the image.
- `phoonnx-data/` — phoonnx/Hugging Face voice cache.

Delete a file or directory to force it to be downloaded again.

### Available Galician voices

These are all `gl`/`gl-ES` voices in the phoonnx index shipped with the image. Re-check with:

```bash
docker compose exec phoonnx python3 -m phoonnx.cli list-available
```

Several speakers are packaged with different phonemizers or engines, hence the suffixes.

**Proxecto Nós** ([project](https://proxectonos.gal/), [GitHub](https://github.com/proxectonos),
[Hugging Face](https://huggingface.co/proxectonos)) (`proxectonos/`):

- `proxectonos/celtia` (default, graphemes), `proxectonos/brais` (graphemes)
- `proxectonos/celtia-cotovia`, `proxectonos/brais-cotovia`, `proxectonos/sabela-cotovia`, `proxectonos/icia-cotovia`,
  `proxectonos/icia-extended-cotovia`, `proxectonos/paulo-cotovia`, `proxectonos/iago-cotovia`
- `proxectonos/celtia-matcha-graphemes`, `proxectonos/brais-matcha-graphemes`, `proxectonos/icia-matcha-phonemes`,
  `proxectonos/icia-extended-matcha-phonemes`, `proxectonos/icia-matcha-phonemes-ljspeech`,
  `proxectonos/icia-extended-matcha-phonemes-ljspeech`
- `proxectonos/celtia-styletts2`, `proxectonos/brais-styletts2`

**aHoTTS** ([project](https://github.com/hitz-zentroa/aHoTTS), [models](https://huggingface.co/HiTZ)) (`hitz/`):
`hitz/gl_celtia-vits`, `hitz/gl_brais-vits`, `hitz/gl_sabela-vits`, `hitz/gl_icia-vits`, `hitz/gl_iago-vits`,
`hitz/gl_paulo-vits`.

**Other**: `OpenVoiceOS/phoonnx_gl-ES_miro_unicode` ([OpenVoiceOS](https://github.com/OpenVoiceOS),
[model](https://huggingface.co/OpenVoiceOS/phoonnx_gl-ES_miro_unicode)) and `omnivoice/gl`
([OmniVoice](https://huggingface.co/k2-fsa/OmniVoice)).

## Wire into Home Assistant

Settings → Devices & Services → Add Integration → **Wyoming**:

- STT: host of this machine, port `10300` (shows up as *faster-whisper*-style entity)
- TTS: port `10400` (phoonnx; entity like `tts.ovos_tts_plugin_phoonnx`)

Then **Settings → Assist → Pipelines** → create "Galego": STT = whisper (gl), TTS = phoonnx (gl-ES, voice
`ovos-tts-plugin-phoonnx`), conversation = your LLM agent. Select the pipeline on the assist_satellite device.

## Troubleshooting

- `docker compose ps` should show both services as `healthy`; otherwise inspect
  `docker compose logs -f whisper phoonnx`.
- whisper needs a working `/dev/dri` and Vulkan driver. If the device is missing or not accessible by the `video` group,
  STT will not start.
- `VoiceNotFoundError` usually means the phoonnx cache or `mycroft.conf` is missing; run `./setup.sh` and verify the
  config mount.
- The phoonnx debug HTTP port `9666` is bound to loopback; use it from the docker host, not from another LAN machine.

## Tests

`tests/probe_tts.py` and `tests/probe_stt.py` speak/read back over wyoming; install `tests/requirements.txt` and see
`tests/README.md`. TTS->STT round-trip is the quality check. CI validates the compose file, shell scripts, Dockerfiles
and Python syntax.

## Licenses / credits

- Code: Apache-2.0 (see LICENSE).
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp): MIT; the large-v3-turbo model is Apache-2.0 (OpenAI Whisper).
- [phoonnx](https://github.com/TigreGotico/phoonnx): Apache-2.0 (TigreGótico / OpenVoiceOS); voice `proxectonos/celtia`
  corpus Nos_Celtia-GL: CC-BY-4.0 ([Proxecto Nós](https://proxectonos.gal/) / Universidade de Vigo). The
  [aHoTTS](https://github.com/hitz-zentroa/aHoTTS) voices (HiTZ) are CC-BY-4.0 too, and
  [OmniVoice](https://huggingface.co/k2-fsa/OmniVoice) is CC-BY-NC-4.0.
- [wyoming protocol](https://github.com/OHF-Voice/wyoming): MIT (Open Home Foundation).
