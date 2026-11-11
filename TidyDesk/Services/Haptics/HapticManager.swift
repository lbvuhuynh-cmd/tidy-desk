import UIKit

/// Haptics for every interaction, honouring the in-game "Haptics" toggle.
///
/// Generators are created once and `prepare()`-d ahead of the moment they are needed
/// (e.g. on pick-up we warm up the selection + rigid engines), so the Taptic Engine is already spun up
/// when the tick or the snap happens: no 10–20 ms wake-up lag.
@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [SettingsKeys.hapticsEnabled: true])
    }

    var isEnabled: Bool { defaults.bool(forKey: SettingsKeys.hapticsEnabled) }

    /// Touch / start of a drag. Also warms up what usually follows (cell ticks, then the snap).
    func playLightImpact() {
        guard isEnabled else { return }
        light.impactOccurred()
        selection.prepare()
        rigid.prepare()
    }

    /// The dragged item crossed a grid-cell boundary on the desk.
    func playSelectionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
        selection.prepare()
    }

    /// Item snapped into the grid. `intensity` < 1 gives a lighter click (used for tap-to-rotate).
    func playRigidImpact(intensity: CGFloat = 1.0) {
        guard isEnabled else { return }
        rigid.impactOccurred(intensity: intensity)
        rigid.prepare()
    }

    /// Item set down softly (back into the drawer).
    func playSoftImpact(intensity: CGFloat = 0.6) {
        guard isEnabled else { return }
        soft.impactOccurred(intensity: intensity)
    }

    /// Invalid drop.
    func playWarning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    /// Level cleared.
    func playSuccess() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    /// Call when the player is likely to interact soon (e.g. a level appears).
    func prepare() {
        guard isEnabled else { return }
        light.prepare()
        notification.prepare()
    }
}
