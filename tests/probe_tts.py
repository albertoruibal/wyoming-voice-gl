"""Probe a wyoming TTS server: Describe -> Info, then synthesize text to out.wav.
Defaults to the phoonnx bridge (:10400)."""
import asyncio
import os
import sys
import wave

from wyoming.audio import AudioChunk, AudioStart, AudioStop
from wyoming.client import AsyncTcpClient
from wyoming.info import Describe, Info
from wyoming.tts import Synthesize, SynthesizeVoice

import argparse
_p = argparse.ArgumentParser()
_p.add_argument("--host", default=os.environ.get("WYOMING_HOST", "localhost"))
_p.add_argument("--port", type=int, default=10400)
_p.add_argument("--text", default="Ola, son a voz de Piper en galego. Proba de s\u00edntese.")
_p.add_argument("--lang", default="gl-ES")
_p.add_argument("--out", default="/tmp/piper_gl_test.wav")
ARGS = _p.parse_args()
HOST, PORT, TEXT = ARGS.host, ARGS.port, ARGS.text


async def main() -> int:
    async with AsyncTcpClient(ARGS.host, ARGS.port) as client:
        await client.write_event(Describe().event())
        info = None
        for _ in range(50):
            event = await asyncio.wait_for(client.read_event(), timeout=5)
            if event is None:
                break
            if Info.is_type(event.type):
                info = Info.from_event(event)
                break
        if info is None:
            print("FAIL: no Info event")
            return 1
        for prog in info.tts:
            langs = set()
            voices = []
            for v in prog.voices or []:
                for l in v.languages:
                    langs.add(l)
                    if l.startswith("gl"):
                        voices.append(f"{v.name} [{l}]")
            print("tts program:", prog.name)
            print("gl voices:", voices or "NONE")
            print("all langs:", sorted(langs))

        await client.write_event(
            Synthesize(text=TEXT, voice=SynthesizeVoice(language=ARGS.lang)).event()
        )
        rate = width = channels = None
        pcm = bytearray()
        while True:
            event = await asyncio.wait_for(client.read_event(), timeout=20)
            if event is None:
                print("FAIL: connection closed mid-stream")
                return 1
            if AudioStart.is_type(event.type):
                a = AudioStart.from_event(event)
                rate, width, channels = a.rate, a.width, a.channels
            elif AudioChunk.is_type(event.type):
                pcm += AudioChunk.from_event(event).audio
            elif AudioStop.is_type(event.type):
                break
        out = ARGS.out
        with wave.open(out, "wb") as w:
            w.setnchannels(channels)
            w.setsampwidth(width)
            w.setframerate(rate)
            w.writeframes(bytes(pcm))
        secs = len(pcm) / (rate * width * channels)
        print(f"OK: {len(pcm)} bytes -> {secs:.1f}s audio, {rate}Hz/{width}B/{channels}ch -> {out}")
        return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))