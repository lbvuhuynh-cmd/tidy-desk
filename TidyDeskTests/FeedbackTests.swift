import XCTest
import AVFoundation
@testable import TidyDesk

final class ToneSynthTests: XCTestCase {
    func testWavHeaderAndLength() {
        let samples: [Float] = [0, 0.5, -0.5, 1]
        let data = ToneSynth.wav(from: samples)
        XCTAssertEqual(data.count, 44 + samples.count * 2)
        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")
    }

    @MainActor
    func testEveryFallbackSoundIsAudible() {
        for sound in SoundManager.Sound.allCases {
            let samples = ToneSynth.samples(for: sound)
            XCTAssertFalse(samples.isEmpty, "\(sound)")
            XCTAssertGreaterThan(samples.map(abs).max() ?? 0, 0.05, "\(sound) is silent")
            XCTAssertLessThanOrEqual(samples.map(abs).max() ?? 0, 1.5, "\(sound) clips badly")
        }
    }
}

@MainActor
final class SoundManagerTests: XCTestCase {
    private var appBundle: Bundle { Bundle(for: DeskDragViewModel.self) }

    /// Every sound (pickup, snap, material snaps, power_on, lights_on, ...) ships as a .wav and decodes with AVAudioPlayer.
    func testEverySoundShipsAsABundledFile() throws {
        for sound in SoundManager.Sound.allCases {
            let (data, source) = SoundManager.loadData(for: sound, in: appBundle)
            XCTAssertEqual(source, .bundleFile("\(sound.rawValue).wav"), "\(sound) fell back to \(source)")
            let player = try AVAudioPlayer(data: data)
            XCTAssertGreaterThan(player.duration, 0.01, "\(sound)")
            XCTAssertLessThan(player.duration, 1.5, "\(sound) is too long for an SFX")
        }
    }

    func testMissingFileFallsBackToSynth() {
        // The test bundle has no sound files, so every sound must still load (synthesized).
        let (data, source) = SoundManager.loadData(for: .snap, in: Bundle(for: SoundManagerTests.self))
        XCTAssertEqual(source, .synthesized)
        XCTAssertNoThrow(try AVAudioPlayer(data: data))
    }

    func testPreloadPreparesEverySoundOnce() {
        let manager = SoundManager(defaults: UserDefaults(suiteName: "SoundManagerTests")!, bundle: appBundle)
        XCTAssertFalse(manager.isPreloaded)
        manager.preload()
        XCTAssertTrue(manager.isPreloaded)
        XCTAssertEqual(Set(manager.sources.keys), Set(SoundManager.Sound.allCases))
        manager.preload() // idempotent
        XCTAssertEqual(manager.sources.count, SoundManager.Sound.allCases.count)
    }

    func testSoundToggleIsRespected() {
        let defaults = UserDefaults(suiteName: "SoundToggleTests")!
        defaults.removePersistentDomain(forName: "SoundToggleTests")
        let manager = SoundManager(defaults: defaults, bundle: appBundle)
        XCTAssertTrue(manager.isEnabled, "sound is on by default")
        defaults.set(false, forKey: SettingsKeys.soundEnabled)
        XCTAssertFalse(manager.isEnabled)
        manager.play(sound: .snap) // must not crash or preload while muted
        XCTAssertFalse(manager.isPreloaded)
    }

    func testHapticToggleIsRespected() {
        let defaults = UserDefaults(suiteName: "HapticToggleTests")!
        defaults.removePersistentDomain(forName: "HapticToggleTests")
        let haptics = HapticManager(defaults: defaults)
        XCTAssertTrue(haptics.isEnabled, "haptics are on by default")
        defaults.set(false, forKey: SettingsKeys.hapticsEnabled)
        XCTAssertFalse(haptics.isEnabled)
    }
}
