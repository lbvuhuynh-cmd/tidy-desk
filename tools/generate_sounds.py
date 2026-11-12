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


def snap_keys():
    noise = LCG(21)
    ticks = [(0.0, 0.5), (0.016, 0.32), (0.029, 0.4), (0.047, 0.22)]

    def gen(t):
        n = noise.next()
        v = math.sin(2 * math.pi * 210 * t) * math.exp(-t * 45) * 0.45
        for start, gain in ticks:
            if t >= start:
                lt = t - start
                v += (n * 0.6 + math.sin(2 * math.pi * 3600 * lt)) * math.exp(-lt * 420) * gain
        return v

    return render(0.12, gen)


def snap_ceramic():
    noise = LCG(33)

    def gen(t):
        ring = (math.sin(2 * math.pi * 2830 * t) * 0.32 + math.sin(2 * math.pi * 4170 * t) * 0.2
                + math.sin(2 * math.pi * 5890 * t) * 0.12)
        return (ring * math.exp(-t * 16) + noise.next() * math.exp(-t * 300) * 0.3
                + math.sin(2 * math.pi * 340 * t) * math.exp(-t * 40) * 0.25)

    return render(0.35, gen)


def snap_soft():
    noise = LCG(45)
    state = {"low": 0.0, "phase": 0.0}

    def gen(t):
        state["low"] += 0.08 * (noise.next() - state["low"])
        state["phase"] += 2 * math.pi * (260 - 400 * t) / RATE
        attack = min(1.0, t * 300)
        return (math.sin(state["phase"]) * 0.7 + state["low"] * 2.2) * attack * math.exp(-t * 32)

    return render(0.13, gen)


def snap_cable():
    noise = LCG(57)
    state = {"low": 0.0}

    def gen(t):
        state["low"] += 0.25 * (noise.next() - state["low"])
        swell = math.exp(-((t - 0.03) / 0.02) ** 2) + 0.7 * math.exp(-((t - 0.08) / 0.025) ** 2)
        tick = math.sin(2 * math.pi * 2600 * (t - 0.12)) * math.exp(-(t - 0.12) * 220) * 0.45 if t >= 0.12 else 0.0
        return state["low"] * swell * 1.4 + tick

    return render(0.17, gen)


def power_on():
    def gen(t):
        freq = 1318.5 if t < 0.08 else 1975.5
        lt = t if t < 0.08 else t - 0.08
        env = min(1.0, lt * 160) * math.exp(-lt * 18)
        return math.sin(2 * math.pi * freq * t) * env * 0.4

    return render(0.26, gen)


def lights_on():
    noise = LCG(69)
    state = {"air": 0.0}
    chord = [261.6, 329.6, 392.0, 523.3]

    def gen(t):
        state["air"] += (0.02 + 0.1 * min(1.0, t / 0.6)) * (noise.next() - state["air"])
        env = min(1.0, t / 0.35) * math.exp(-max(0.0, t - 0.35) * 3.2)
        pad = sum(math.sin(2 * math.pi * f * t) + 0.25 * math.sin(2 * math.pi * f * 2 * t) for f in chord)
        return pad * env * 0.11 + state["air"] * env * 0.5

    return render(1.1, gen)


def coin():
    notes = [(1975.5, 0.0), (2637.0, 0.07)]

    def gen(t):
        v = 0.0
        for freq, start in notes:
            if t >= start:
                lt = t - start
                env = min(1.0, lt * 500) * math.exp(-lt * 9)
                v += (math.sin(2 * math.pi * freq * lt) + 0.25 * math.sin(2 * math.pi * freq * 2.76 * lt)) * env * 0.3
        return v

    return render(0.4, gen)


def feed():
    starts = [0.0, 0.13, 0.26]

    def gen(t):
        v = 0.0
        for start in starts:
            if start <= t < start + 0.09:
                lt = t - start
                phase = 2 * math.pi * (300 * lt + 1300 * lt * lt)
                v += math.sin(phase) * math.sin(math.pi * lt / 0.09) * 0.5
        return v

    return render(0.38, gen)


def squeak():
    state = {"phase": 0.0}

    def gen(t):
        freq = 900 + 700 * math.sin(math.pi * t / 0.22) + 30 * math.sin(2 * math.pi * 30 * t)
        state["phase"] += 2 * math.pi * freq / RATE
        env = min(1.0, t * 200) * math.exp(-t * 6)
        p = state["phase"]
        return (math.sin(p) + 0.3 * math.sin(2 * p)) * env * 0.35

    return render(0.22, gen)


def coo():
    state = {"phase": 0.0}

    def gen(t):
        freq = 520 + 140 * t / 0.4 + 25 * math.sin(2 * math.pi * 7 * t)
        state["phase"] += 2 * math.pi * freq / RATE
        env = min(1.0, t / 0.04) * math.exp(-max(0.0, t - 0.08) * 7)
        p = state["phase"]
        return (math.sin(p) + 0.4 * math.sin(2 * p) + 0.15 * math.sin(3 * p)) * env * 0.3

    return render(0.4, gen)


SOUNDS = {
    "pickup": lambda: sweep(340, 680, 0.07, 35, 0.45),
    "snap": snap,
    "error": lambda: sweep(520, 260, 0.14, 22, 0.6),
    "complete": complete,
    "drop": lambda: sweep(320, 170, 0.09, 38, 0.7),
    "rotate": rotate,
    "snap_keys": snap_keys,
    "snap_ceramic": snap_ceramic,
    "snap_soft": snap_soft,
    "snap_cable": snap_cable,
    "power_on": power_on,
    "lights_on": lights_on,
    "coin": coin,
    "feed": feed,
    "squeak": squeak,
    "coo": coo,
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
