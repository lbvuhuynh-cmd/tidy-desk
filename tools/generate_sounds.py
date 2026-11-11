"""Writes the starter sound effects to TidyDesk/Resources/Sounds/*.wav.

Same recipes as ToneSynth.swift (16-bit mono PCM, 44.1 kHz), so the bundled files and the in-memory fallback
sound alike. These are placeholders: drop real recordings with the same names (pickup.wav, snap.wav, ...)
into TidyDesk/Resources/Sounds/ (or .mp3 / .caf / .m4a) and SoundManager picks them up automatically.

Usage:  python tools/generate_sounds.py
"""
import math
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "TidyDesk" / "Resources" / "Sounds"
RATE = 44_100


class LCG:
    """Matches ToneSynth.LCG (UInt32 wrap-around)."""

    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 1_664_525 + 1_013_904_223) & 0xFFFFFFFF
        return (self.state >> 8) / float(1 << 24) * 2 - 1


def render(duration, gen):
    count = int(duration * RATE)
    fade = max(1, count // 20)
    out = []
    for i in range(count):
        t = i / RATE
        tail = (count - i) / fade if i > count - fade else 1.0
        out.append(gen(t) * tail)
    return out


def sweep(f0, f1, duration, decay, gain):
    phase = 0.0

    def gen(t):
        nonlocal phase
        freq = f0 + (f1 - f0) * (t / duration)
        phase += 2 * math.pi * freq / RATE
        attack = min(1.0, t * 600)
        return math.sin(phase) * attack * math.exp(-t * decay) * gain

    return render(duration, gen)


def snap():
    noise = LCG(7)

    def gen(t):
        n = noise.next() * math.exp(-t * 140) * 0.45
        hi = math.sin(2 * math.pi * 2350 * t) * math.exp(-t * 110) * 0.45
        lo = math.sin(2 * math.pi * 820 * t) * math.exp(-t * 55) * 0.5
        return n + hi + lo

    return render(0.07, gen)


def rotate():
    noise = LCG(11)
    return render(0.03, lambda t: noise.next() * math.exp(-t * 260) * 0.35
                  + math.sin(2 * math.pi * 3400 * t) * math.exp(-t * 200) * 0.4)


def complete():
    notes = [(1046.5, 0.0), (1318.5, 0.09), (1568.0, 0.18), (2093.0, 0.27)]

    def gen(t):
        v = 0.0
        for freq, start in notes:
            if t >= start:
                lt = t - start
                env = (1 - math.exp(-lt * 400)) * math.exp(-lt * 6)
                v += (math.sin(2 * math.pi * freq * lt) + 0.3 * math.sin(2 * math.pi * freq * 2 * lt)) * env * 0.22
        return v

    return render(0.85, gen)


SOUNDS = {
    "pickup": lambda: sweep(340, 680, 0.07, 35, 0.45),
    "snap": snap,
    "error": lambda: sweep(520, 260, 0.14, 22, 0.6),
    "complete": complete,
    "drop": lambda: sweep(320, 170, 0.09, 38, 0.7),
    "rotate": rotate,
}


def write_wav(path, samples):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
        w.writeframes(frames)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        samples = make()
        path = OUT / f"{name}.wav"
        write_wav(path, samples)
        peak = max(abs(s) for s in samples)
        print(f"{path.name:<13} {len(samples) / RATE * 1000:5.0f} ms  peak {peak:.2f}")


if __name__ == "__main__":
    main()
