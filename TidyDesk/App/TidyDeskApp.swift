import SwiftUI
import SwiftData

@main
struct TidyDeskApp: App {
    /// Scans and validates every bundled `level_<n>.json` once at launch; shared through the environment.
    @State private var levelManager: LevelManager = {
        let manager = LevelManager()
        manager.unlockAll = BetaConfig.unlockAllLevels
        return manager
    }()

    var body: some Scene {
        WindowGroup {
            LevelSelectView()
                .environment(levelManager)
                // Decode every SFX and wake the audio hardware while the player is still on the level list,
                // so the very first pick-up / snap plays instantly.
                .task { SoundManager.shared.preload() }
        }
        .modelContainer(for: [LevelProgress.self, BabyProfile.self])
    }
}
