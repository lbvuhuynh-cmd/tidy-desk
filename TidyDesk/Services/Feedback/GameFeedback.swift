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
    /// Finger lifted over a valid spot: the item snaps into the grid.
    func snapped()
    /// Finger lifted over an invalid spot (overlap / over the edge): the item springs back.
    func rejected()
    /// Item let go away from the desk, or dragged from the desk back into the drawer.
    func returnedToDrawer()
    /// Tap-to-rotate in the drawer.
    func rotated()
    /// Every item placed.
    func levelCleared()
}

/// Routes each game moment to `HapticManager` + `SoundManager`:
///
/// | Moment (DragGesture)                     | Haptic                        | Sound        |
/// |------------------------------------------|-------------------------------|--------------|
/// | `onChanged`, first event: lift-off       | `playLightImpact()`           | `.pickup`    |
/// | `onChanged`: crossing a cell boundary    | `playSelectionChanged()`      | –            |
/// | `onEnded` on a valid cell: snap          | `playRigidImpact()`           | `.snap`      |
/// | `onEnded` on an invalid cell: bounce     | `playWarning()`               | `.error`     |
/// | `onEnded` elsewhere / into the drawer    | `playSoftImpact()`            | `.drop`      |
/// | tap in the drawer: rotate                | `playRigidImpact(0.5)`        | `.rotate`    |
/// | level clear                              | `playSuccess()`               | `.complete`  |
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

    func snapped() {
        haptics.playRigidImpact()
        sounds.play(sound: .snap)
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
    func snapped() {}
    func rejected() {}
    func returnedToDrawer() {}
    func rotated() {}
    func levelCleared() {}
}
