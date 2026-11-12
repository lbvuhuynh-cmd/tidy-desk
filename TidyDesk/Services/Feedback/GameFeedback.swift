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

/// No-op feedback for previews and tests.
@MainActor
final class SilentFeedback: GameFeedback {
    func pickUp() {}
    func cellCrossed() {}
    func snapped(_ traits: ItemTraits) {}
    func rejected() {}
    func returnedToDrawer() {}
    func rotated() {}
    func lightsOn() {}
    func levelCleared() {}
}
