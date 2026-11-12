import Foundation

/// Switches for the TestFlight phase. **Turn them off before the App Store release** (see PROJECT_NOTES section 4).
enum BetaConfig {
    /// Every level is playable from the start (no "finish the previous desk first"), so testers can jump to
    /// any level. Progress, stars and best scores are still saved as normal.
    static let unlockAllLevels = true
}
