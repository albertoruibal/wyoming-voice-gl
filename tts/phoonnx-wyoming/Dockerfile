# phoonnx + wyoming bridge for Home Assistant (Galician celtia voice).
# Base: https://github.com/TigreGotico/phoonnx (batteries-included OVOS TTS server image,
# 4.96 GB, espeak-ng + pre-filled voice index). Adds the wyoming-ovos-tts bridge so HA's
# wyoming integration can use phoonnx voices directly (same protocol as piper/whisper).
FROM ghcr.io/tigregotico/phoonnx@sha256:0a870a3a4471b612da963043374496fbdf4c4a6603f22e719f04f721c3b72286

# PyPI wyoming-ovos-tts 0.2.0 is broken with this image's wyoming 1.10.2 (TtsVoice
# call misses the required 'version' arg -> TypeError at startup). Git master passes
# version=None and keeps the image's wyoming untouched; it speaks plain Synthesize
# (HA falls back from streaming automatically when not advertised).
RUN pip install --no-cache-dir "git+https://github.com/TigreGotico/wyoming-ovos-tts@2de247878a772a82cd9c57ef190548f09bfea704"

# The bridge script installs to /home/ovos/.local/bin (ovos user), not /usr/local/bin.
ENV PATH="/home/ovos/.local/bin:${PATH}"

# Voice for Galician pinned here so the container works without mycroft.conf.
# (Override with compose env if needed.)
ENV PHOONNX_DEFAULT_VOICE_GL=proxectonos/celtia