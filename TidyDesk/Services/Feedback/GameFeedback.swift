import Foundation

enum SettingsKeys {
    static let soundEnabled = "settings.soundEnabled"
    static let hapticsEnabled = "settings.hapticsEnabled"
}

/// Every "juicy" moment in the game. `DeskDragViewModel` only talks to this protocol, so unit tests can
/// record the exact sequence of feedback events without touching audio or the Taptic Engine.
@MainActor
protocol GameFeedback: AnyObject {
    /// Drag started: the item lifts off (drawer or desk).
    func pickUp()
    /// Dragged item crosses a grid-cell boundary over the desk.
    func cellCrossed()
    /// Finger lifted over a valid spot: the item snaps into the grid. The item's traits pick the landing sound
    /// (keycaps, ceramic, soft, cable, device) and whether it "switches on" afterwards.
    func snapped(_ traits: ItemTraits)
    /// Finger lifted over an invalid spot (overlap / over the edge): the item springs back.
    func rejected()
    /// Item let go away from the desk, or dragged from the desk back into the drawer.
    func returnedToDrawer()
    /// Tap-to-rotate in the drawer.
    func rotated()
    /// Desk complete, the "after" moment: the room lights up (played right away; `levelCleared` follows with the card).
    func lightsOn()
    /// Every item placed.
    func levelCleared()
}

/// Routes each game moment to `HapticManager` + `SoundManager`:
///
/// | Moment (DragGesture)                     | Haptic                        | Sound        |
/// |------------------------------------------|-------------------------------|--------------|
/// | `onChanged`, first event: lift-off       | `playLightImpact()`           | `.pickup`    |
/// | `onChanged`: crossing a cell boundary    | `playSelectionChanged()`      | –            |
/// | `onEnded` on a valid cell: snap          | rigid / soft by material      | `.snap*` by material, then `.powerOn` for electronics |
/// | `onEnded` on an invalid cell: bounce     | `playWarning()`               | `.error`     |
/// | `onEnded` elsewhere / into the drawer    | `playSoftImpact()`            | `.drop`      |
/// | tap in the drawer: rotate                | `playRigidImpact(0.5)`        | `.rotate`    |
/// | desk complete (the "after" moment)       | `playSoftImpact()`            | `.lightsOn`  |
/// | level clear (card appears)               | `playSuccess()`               | `.complete`  |
@MainActor
final class FeedbackEngine: GameFeedback {
    static let shared = FeedbackEngine()

    private let haptics: HapticManager
    private let sounds: SoundManager

    /// `nil` = the shared managers (resolved here, on the main actor; default arguments are nonisolated).
    init(haptics: HapticManager? = nil, sounds: SoundManager? = nil) {
        self.haptics = haptics ?? .shared
        self.sounds = sounds ?? .shared
    }

    func pickUp() {
        haptics.playLightImpact()
        sounds.play(sound: .pickup)
    }

    func cellCrossed() {
        haptics.playSelectionChanged()
    }

    func snapped(_ traits: ItemTraits) {
        switch traits.material {
        case .soft, .cable: haptics.playSoftImpact(intensity: 0.9)
        case .ceramic: haptics.playRigidImpact(intensity: 0.8)
        case .keys, .device: haptics.playRigidImpact()
        }
        sounds.play(sound: .snap(for: traits.material))
        if traits.life.powersOn {
            // Lands first, then switches on, timed with the glow fading in (ItemLifeEffect).
            let sounds = sounds
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                sounds.play(sound: .powerOn)
            }
        }
    }

    func rejected() {
        haptics.playWarning()
        sounds.play(sound: .error)
    }

    func returnedToDrawer() {
        haptics.playSoftImpact()
        sounds.play(sound: .drop)
    }

    func rotated() {
        haptics.playRigidImpact(intensity: 0.5)
        sounds.play(sound: .rotate)
    }

    func lightsOn() {
        haptics.playSoftImpact(intensity: 0.5)
        sounds.play(sound: .lightsOn)
    }

    func levelCleared() {
        haptics.playSuccess()
        sounds.play(sound: .complete)
    }
}

/// Baby Corner moments. Same rule as the desk: views talk to this protocol, never to the managers directly.
///
/// | Moment                                   | Haptic                        | Sound        |
/// |------------------------------------------|-------------------------------|--------------|
/// | coins paid out on the Setup Complete card| `playLightImpact()`           | `.coin`      |
/// | tap the baby                             | `playSoftImpact(0.5)`         | `.coo`       |
/// | feed                                     | `playSoftImpact(0.7)`         | `.feed`      |
/// | play with a toy                          | `playLightImpact()`           | `.squeak`    |
/// | buy a toy / outfit                       | `playRigidImpact(0.6)`        | `.coin`      |
/// | change outfit                            | `playSelectionChanged()`      | `.pickup`    |
/// | baby reaches a new stage                 | `playSuccess()`               | `.complete`  |
/// | not now (full, too few coins, too young) | `playSoftImpact(0.3)`         | `.drop`      |
/// | pop a bath bubble                        | `playSoftImpact(0.4)`         | `.pickup`    |
/// | bath finished                            | `playLightImpact()`           | `.squeak`    |
/// | rocking the cradle (each swing)          | `playSelectionChanged()`      | none         |
/// | baby falls asleep                        | `playSoftImpact(0.6)`         | `.coo`       |
/// | milestone reached (Baby Book page)       | `playSuccess()`               | `.complete`  |
@MainActor
protocol BabyFeedback: AnyObject {
    func bubblePopped()
    func babyBathed()
    func cradleRocked()
    func babyFellAsleep()
    func milestoneReached()
    func coinsEarned()
    func babyTapped()
    func babyFed()
    func babyPlayed()
    func itemBought()
    func outfitChanged()
    func babyGrew()
    func careDeclined()
}

extension FeedbackEngine: BabyFeedback {
    func bubblePopped() {
        haptics.playSoftImpact(intensity: 0.4)
        sounds.play(sound: .pickup)
    }

    func babyBathed() {
        haptics.playLightImpact()
        sounds.play(sound: .squeak)
    }

    func cradleRocked() {
        haptics.playSelectionChanged()
    }

    func babyFellAsleep() {
        haptics.playSoftImpact(intensity: 0.6)
        sounds.play(sound: .coo)
    }

    func milestoneReached() {
        haptics.playSuccess()
        sounds.play(sound: .complete)
    }

    func coinsEarned() {
        haptics.playLightImpact()
        sounds.play(sound: .coin)
    }

    func babyTapped() {
        haptics.playSoftImpact(intensity: 0.5)
        sounds.play(sound: .coo)
    }

    func babyFed() {
        haptics.playSoftImpact(intensity: 0.7)
        sounds.play(sound: .feed)
    }

    func babyPlayed() {
        haptics.playLightImpact()
        sounds.play(sound: .squeak)
    }

    func itemBought() {
        haptics.playRigidImpact(intensity: 0.6)
        sounds.play(sound: .coin)
    }

    func outfitChanged() {
        haptics.playSelectionChanged()
        sounds.play(sound: .pickup)
    }

    func babyGrew() {
        haptics.playSuccess()
        sounds.play(sound: .complete)
    }

    func careDeclined() {
        haptics.playSoftImpact(intensity: 0.3)
        sounds.play(sound: .drop)
    }
}

/// No-op feedback for previews and tests.
@MainActor
final class SilentFeedback: GameFeedback, BabyFeedback {
    func bubblePopped() {}
    func babyBathed() {}
    func cradleRocked() {}
    func babyFellAsleep() {}
    func milestoneReached() {}
    func coinsEarned() {}
    func babyTapped() {}
    func babyFed() {}
    func babyPlayed() {}
    func itemBought() {}
    func outfitChanged() {}
    func babyGrew() {}
    func careDeclined() {}

    func pickUp() {}
    func cellCrossed() {}
    func snapped(_ traits: ItemTraits) {}
    func rejected() {}
    func returnedToDrawer() {}
    func rotated() {}
    func lightsOn() {}
    func levelCleared() {}
}
