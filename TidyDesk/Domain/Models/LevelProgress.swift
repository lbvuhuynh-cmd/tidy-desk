import Foundation
import SwiftData

/// Persisted per-level result (SwiftData, local only). Keyed by the JSON `levelId`.
/// Completion here is also what unlocks the next level (`LevelManager.isUnlocked`).
@Model
final class LevelProgress {
    @Attribute(.unique) var levelId: Int
    var isCompleted: Bool
    var bestMoves: Int?
    var bestStars: Int
    var bestTime: Double?
    var bestScore: Int = 0
    var completedAt: Date?

    init(levelId: Int, isCompleted: Bool = false, bestMoves: Int? = nil, bestStars: Int = 0,
         bestTime: Double? = nil, bestScore: Int = 0, completedAt: Date? = nil) {
        self.levelId = levelId
        self.isCompleted = isCompleted
        self.bestMoves = bestMoves
        self.bestStars = bestStars
        self.bestTime = bestTime
        self.bestScore = bestScore
        self.completedAt = completedAt
    }
}

enum ProgressStore {
    /// Whether this level has been cleared before (read before `recordClear` to tell a first clear from a replay).
    @MainActor
    static func isCompleted(levelId: Int, in context: ModelContext) -> Bool {
        let id = levelId
        let descriptor = FetchDescriptor<LevelProgress>(predicate: #Predicate { $0.levelId == id && $0.isCompleted == true })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    /// Records a clear, keeping the best values seen so far.
    /// Returns true when this run beat the previous best score (false on the very first clear).
    @MainActor
    @discardableResult
    static func recordClear(levelId: Int, moves: Int, stars: Int, seconds: TimeInterval, score: Int,
                            in context: ModelContext, now: Date = .now) -> Bool {
        let id = levelId
        let descriptor = FetchDescriptor<LevelProgress>(predicate: #Predicate { $0.levelId == id })
        let progress: LevelProgress
        let isFirstClear: Bool
        if let existing = try? context.fetch(descriptor).first {
            progress = existing
            isFirstClear = !existing.isCompleted
        } else {
            progress = LevelProgress(levelId: levelId)
            context.insert(progress)
            isFirstClear = true
        }
        let isNewBest = !isFirstClear && score > progress.bestScore
        progress.isCompleted = true
        progress.completedAt = now
        progress.bestMoves = min(progress.bestMoves ?? .max, moves)
        progress.bestStars = max(progress.bestStars, stars)
        progress.bestTime = min(progress.bestTime ?? .greatestFiniteMagnitude, seconds)
        progress.bestScore = max(progress.bestScore, score)
        try? context.save()
        return isNewBest
    }
}
