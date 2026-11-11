import Foundation

/// Moves = successful placements (placing an item, or moving it to a different cell). Rotations are free.
/// Perfect run = each item placed exactly once.
enum StarRating {
    static func stars(moves: Int, itemCount: Int) -> Int {
        if moves <= itemCount { return 3 }
        if moves <= itemCount + max(2, itemCount / 3) { return 2 }
        return 1
    }
}

/// Score shown on the "Setup Complete!" card.
///   100 per item
/// + time bonus: 5 per second under par (par = 6 s per item + 10 s)
/// - 25 per extra move
/// Never below 25 per item, so a slow, messy clear still feels rewarded.
enum ScoreCalculator {
    static func parTime(itemCount: Int) -> TimeInterval { TimeInterval(itemCount * 6 + 10) }

    static func score(itemCount: Int, moves: Int, seconds: TimeInterval) -> Int {
        let base = itemCount * 100
        let timeBonus = Int(max(0, parTime(itemCount: itemCount) - seconds) * 5)
        let movePenalty = max(0, moves - itemCount) * 25
        return max(itemCount * 25, base + timeBonus - movePenalty)
    }

    /// "1:05" style.
    static func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
