"""Stream a wav to a wyoming STT server (default localhost:10300) and print the transcript."""
import asyncio
import os
import sys
import wave

from wyoming.audio import AudioChunk, AudioStart, AudioStop
from wyoming.client import AsyncTcpClient
from wyoming.info import Describe, Info
from wyoming.asr import Transcript

import argparse

_p = argparse.ArgumentParser(description=__doc__)
_p.add_argument("wav")
_p.add_argument("--host", default=os.environ.get("WYOMING_HOST", "localhost"))
_p.add_argument("--port", type=int, default=10300)
ARGS = _p.parse_args()
WAV = ARGS.wav


async def main() -> int:
    with wave.open(WAV, "rb") as w:
        rate, width, channels = w.getframerate(), w.getsampwidth(), w.getnchannels()
        pcm = w.readframes(w.getnframes())
    async with AsyncTcpClient(ARGS.host, ARGS.port) as client:
        await client.write_event(Describe().event())
        for _ in range(100):
            event = await asyncio.wait_for(client.read_event(), timeout=5)
            if event is None:
                break
            if Info.is_type(event.type):
                info = Info.from_event(event)
                for p in info.asr:
                    langs = set()
                    for vm in p.models or []:
                        for l in vm.languages:
                            langs.add(l)
                    print("stt program:", p.name, "langs:", sorted(langs))
                break
        await client.write_event(AudioStart(rate, width, channels, timestamp=0).event())
        per = 512 * width * channels
        ts = 0
        for i in range(0, len(pcm), per):
            chunk = pcm[i : i + per]
            await client.write_event(AudioChunk(rate, width, channels, chunk, timestamp=ts).event())
            ts += int(1000 / rate * (len(chunk) // (width * channels)))
        await client.write_event(AudioStop(timestamp=ts).event())
        for _ in range(200):
            event = await asyncio.wait_for(client.read_event(), timeout=30)
            if event is None:
                print("FAIL: closed without transcript")
                return 1
            if Transcript.is_type(event.type):
                t = Transcript.from_event(event)
                print("transcript:", t.text)
                return 0
    print("FAIL: no transcript in window")
    return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))