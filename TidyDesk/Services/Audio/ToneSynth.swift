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
