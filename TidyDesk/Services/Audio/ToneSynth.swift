import Foundation

/// Tiny offline synthesizer -> 16-bit mono PCM WAV in memory.
/// Fallback for `SoundManager` when no audio file is bundled. `tools/generate_sounds.py` uses the same
/// recipes to write the starter `.wav` files, so the fallback and the bundled files sound alike.
enum ToneSynth {
    static let sampleRate = 44_100

    static func wav(for sound: SoundManager.Sound) -> Data {
        wav(from: samples(for: sound))
    }

    static func samples(for sound: SoundManager.Sound) -> [Float] {
        switch sound {
        case .pickup:
            // Soft rising "fwup": the item leaves the surface.
            return sweep(from: 340, to: 680, duration: 0.07, decay: 35, gain: 0.45)
        case .snap:
            // Woody "click": noise transient + two fast-decaying partials.
            var noise = LCG(seed: 7)
            return render(duration: 0.07) { t in
                let n = noise.next() * expf(-t * 140) * 0.45
                let hi = sinf(2 * .pi * 2_350 * t) * expf(-t * 110) * 0.45
                let lo = sinf(2 * .pi * 820 * t) * expf(-t * 55) * 0.5
                return n + hi + lo
            }
        case .error:
            // Gentle descending "boop": nope, try again (not a harsh buzzer: this is a cozy game).
            return sweep(from: 520, to: 260, duration: 0.14, decay: 22, gain: 0.6)
        case .drop:
            // Low thump when an item goes back to the drawer.
            return sweep(from: 320, to: 170, duration: 0.09, decay: 38, gain: 0.7)
        case .rotate:
            // Tiny, high "tk", like a ratchet click.
            var noise = LCG(seed: 11)
            return render(duration: 0.03) { t in
                noise.next() * expf(-t * 260) * 0.35 + sinf(2 * .pi * 3_400 * t) * expf(-t * 200) * 0.4
            }
        case .complete:
            // Bright arpeggio C6-E6-G6-C7.
            let notes: [(freq: Float, start: Float)] = [(1046.5, 0), (1318.5, 0.09), (1568.0, 0.18), (2093.0, 0.27)]
            return render(duration: 0.85) { t in
                var v: Float = 0
                for note in notes where t >= note.start {
                    let lt = t - note.start
                    let env = (1 - expf(-lt * 400)) * expf(-lt * 6)
                    v += (sinf(2 * .pi * note.freq * lt) + 0.3 * sinf(2 * .pi * note.freq * 2 * lt)) * env * 0.22
                }
                return v
            }
        case .snapKeys:
            // Keycap clatter: a few quick plastic ticks over a low "thock".
            var noise = LCG(seed: 21)
            let ticks: [(start: Float, gain: Float)] = [(0, 0.5), (0.016, 0.32), (0.029, 0.4), (0.047, 0.22)]
            return render(duration: 0.12) { t in
                let n = noise.next()
                var v = sinf(2 * .pi * 210 * t) * expf(-t * 45) * 0.45
                for tick in ticks where t >= tick.start {
                    let lt = t - tick.start
                    v += (n * 0.6 + sinf(2 * .pi * 3_600 * lt)) * expf(-lt * 420) * tick.gain
                }
                return v
            }
        case .snapCeramic:
            // Ceramic clink: inharmonic partials ringing a little + a tiny contact transient.
            var noise = LCG(seed: 33)
            return render(duration: 0.35) { t in
                let ring = sinf(2 * .pi * 2_830 * t) * 0.32 + sinf(2 * .pi * 4_170 * t) * 0.2 + sinf(2 * .pi * 5_890 * t) * 0.12
                return ring * expf(-t * 16) + noise.next() * expf(-t * 300) * 0.3
                    + sinf(2 * .pi * 340 * t) * expf(-t * 40) * 0.25
            }
        case .snapSoft:
            // Cushioned thump: low falling sine + low-passed noise, no click.
            var noise = LCG(seed: 45)
            var low: Float = 0
            var phase: Float = 0
            return render(duration: 0.13) { t in
                low += 0.08 * (noise.next() - low)
                phase += 2 * .pi * (260 - 400 * t) / Float(sampleRate)
                let attack = min(1, t * 300)
                return (sinf(phase) * 0.7 + low * 2.2) * attack * expf(-t * 32)
            }
        case .snapCable:
            // Cable rustle: band-limited noise in two little swells, then a plastic tick.
            var noise = LCG(seed: 57)
            var low: Float = 0
            return render(duration: 0.17) { t in
                low += 0.25 * (noise.next() - low)
                let swell = expf(-powf((t - 0.03) / 0.02, 2)) + 0.7 * expf(-powf((t - 0.08) / 0.025, 2))
                let tick = t >= 0.12 ? sinf(2 * .pi * 2_600 * (t - 0.12)) * expf(-(t - 0.12) * 220) * 0.45 : 0
                return low * swell * 1.4 + tick
            }
        case .powerOn:
            // Soft two-note "on" blip (E6 -> B6), gentle attack.
            return render(duration: 0.26) { t in
                let freq: Float = t < 0.08 ? 1_318.5 : 1_975.5
                let lt = t < 0.08 ? t : t - 0.08
                let env = min(1, lt * 160) * expf(-lt * 18)
                return sinf(2 * .pi * freq * t) * env * 0.4
            }
        case .lightsOn:
            // Warm swell: soft major chord fading in with an airy rising whoosh (the room lights up).
            var noise = LCG(seed: 69)
            var air: Float = 0
            let chord: [Float] = [261.6, 329.6, 392.0, 523.3]
            return render(duration: 1.1) { t in
                air += (0.02 + 0.1 * min(1, t / 0.6)) * (noise.next() - air)
                let env = min(1, t / 0.35) * expf(-max(0, t - 0.35) * 3.2)
                var pad: Float = 0
                for f in chord { pad += sinf(2 * .pi * f * t) + 0.25 * sinf(2 * .pi * f * 2 * t) }
                return pad * env * 0.11 + air * env * 0.5
            }
        case .coin:
            // Bright two-note chime (B6 -> E7) with a bell-like inharmonic partial.
            let notes: [(freq: Float, start: Float)] = [(1_975.5, 0), (2_637.0, 0.07)]
            return render(duration: 0.4) { t in
                var v: Float = 0
                for note in notes where t >= note.start {
                    let lt = t - note.start
                    let env = min(1, lt * 500) * expf(-lt * 9)
                    v += (sinf(2 * .pi * note.freq * lt) + 0.25 * sinf(2 * .pi * note.freq * 2.76 * lt)) * env * 0.3
                }
                return v
            }
        case .feed:
            // Three soft rising "gulp" blips.
            let starts: [Float] = [0, 0.13, 0.26]
            return render(duration: 0.38) { t in
                var v: Float = 0
                for start in starts where t >= start && t < start + 0.09 {
                    let lt = t - start
                    let phase = 2 * .pi * (300 * lt + 1_300 * lt * lt)
                    v += sinf(phase) * sinf(.pi * lt / 0.09) * 0.5
                }
                return v
            }
        case .squeak:
            // Rubber-toy squeak: pitch up and back down with a little wobble.
            var phase: Float = 0
            return render(duration: 0.22) { t in
                let freq = 900 + 700 * sinf(.pi * t / 0.22) + 30 * sinf(2 * .pi * 30 * t)
                phase += 2 * .pi * freq / Float(sampleRate)
                let env = min(1, t * 200) * expf(-t * 6)
                return (sinf(phase) + 0.3 * sinf(2 * phase)) * env * 0.35
            }
        case .coo:
            // Soft happy "ooh": gently rising tone with vibrato and a couple of warm harmonics.
            var phase: Float = 0
            return render(duration: 0.4) { t in
                let freq = 520 + 140 * t / 0.4 + 25 * sinf(2 * .pi * 7 * t)
                phase += 2 * .pi * freq / Float(sampleRate)
                let env = min(1, t / 0.04) * expf(-max(0, t - 0.08) * 7)
                return (sinf(phase) + 0.4 * sinf(2 * phase) + 0.15 * sinf(3 * phase)) * env * 0.3
            }
        }
    }

    // MARK: Building blocks

    private static func render(duration: Float, _ generator: (Float) -> Float) -> [Float] {
        let count = Int(duration * Float(sampleRate))
        let fadeOut = max(1, count / 20) // avoid a click at the very end
        return (0..<count).map { i in
            let t = Float(i) / Float(sampleRate)
            let tail = i > count - fadeOut ? Float(count - i) / Float(fadeOut) : 1
            return generator(t) * tail
        }
    }

    private static func sweep(from f0: Float, to f1: Float, duration: Float, decay: Float, gain: Float) -> [Float] {
        var phase: Float = 0
        return render(duration: duration) { t in
            let freq = f0 + (f1 - f0) * (t / duration)
            phase += 2 * .pi * freq / Float(sampleRate)
            let attack = min(1, t * 600)
            return sinf(phase) * attack * expf(-t * decay) * gain
        }
    }

    static func wav(from samples: [Float]) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        let byteCount = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36) + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16))
        append(UInt16(1))                    // PCM
        append(UInt16(1))                    // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))       // byte rate
        append(UInt16(2))                    // block align
        append(UInt16(16))                   // bits per sample
        data.append(contentsOf: Array("data".utf8)); append(byteCount)
        for s in samples {
            let clamped = max(-1, min(1, s))
            append(Int16(clamped * Float(Int16.max)))
        }
        return data
    }

    /// Deterministic noise so the click sounds identical every launch.
    private struct LCG {
        var state: UInt32
        init(seed: UInt32) { state = seed }
        mutating func next() -> Float {
            state = state &* 1_664_525 &+ 1_013_904_223
            return Float(state >> 8) / Float(1 << 24) * 2 - 1
        }
    }
}
