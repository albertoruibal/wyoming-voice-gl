# Probes

Two wyoming clients for smoke-testing the pipelines from another machine
(need `pip install wyoming`). Hosts default to `localhost`; override with
`--host` or the `WYOMING_HOST` environment variable.

    python3 probe_tts.py [--host HOST] [--port 10400] [--text "..."] [--out out.wav]
    python3 probe_stt.py [--host HOST] /path/to/file.wav   # streams a wav to whisper

Round-trip (quality check = intelligibility):

    ./run_roundtrip.sh 10400 "Ola, son a voz de celtia."

phoonnx bridge = 10400 (celtia), whisper STT = 10300.
