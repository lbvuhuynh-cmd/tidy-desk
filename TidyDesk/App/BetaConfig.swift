import Foundation

/// Switches for the TestFlight phase. **Turn them off before the App Store release** (see PROJECT_NOTES section 4).
enum BetaConfig {
    /// Every level is playable from the start (no "finish the previous desk first"), so testers can jump to
    /// any level. Progress, stars and best scores are still saved as normal.
    static let unlockAllLevels = true

    /// Baby Corner for testers: every food, toy and outfit is available (no age locks, toys and outfits owned),
    /// the Baby Book shows every page (unreached ones marked "Preview"), and the nursery shows a small
    /// test panel to jump the baby's age, add coins and make the baby need care again.
    static let unlockAllBabyContent = true
}
