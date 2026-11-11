import Foundation
import Observation
import SwiftData

/// Finds, decodes and validates the level files, and answers "which levels exist / are unlocked / what's next".
///
/// * **Files**: every `level_<n>.json` in the app bundle (bundle root or a `Levels/` folder).
///   Adding a level = dropping in a new JSON file; no Swift changes.
/// * **Order**: by `levelId` (not by file name). `level_<n>` should match `levelId` (a mismatch is reported).
/// * **Robustness**: a file that fails to decode or validate is skipped and listed in `loadIssues`;
///   the other levels still load. Duplicate `levelId`s keep the first file.
/// * **Unlocking**: level 1 is always open; every other level opens once the previous one
///   (in `levelId` order) is completed. Completion lives in SwiftData (`LevelProgress`).
@Observable
@MainActor
final class LevelManager {
    struct LoadIssue: Identifiable, Hashable {
        let file: String
        let message: String
        var id: String { file + message }
    }

    private(set) var availableLevels: [LevelData] = []
    private(set) var loadIssues: [LoadIssue] = []
    /// The level currently being played (set by `loadLevel(id:)`).
    private(set) var currentLevel: LevelData?

    @ObservationIgnored private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        reload()
    }

    /// Test / preview helper: use an in-memory list instead of bundle files.
    init(levels: [LevelData]) {
        self.bundle = .main
        availableLevels = levels.sorted { $0.levelId < $1.levelId }
    }

    // MARK: Loading

    /// Re-scans the bundle. Cheap: a handful of small JSON files.
    func reload() {
        var levels: [LevelData] = []
        var issues: [LoadIssue] = []
        var seen = Set<Int>()
        let decoder = JSONDecoder()

        for url in Self.levelFileURLs(in: bundle) {
            let file = url.lastPathComponent
            do {
                let level = try decoder.decode(LevelData.self, from: Data(contentsOf: url))
                let problems = LevelValidator.problems(in: level)
                guard problems.isEmpty else {
                    issues += problems.map { LoadIssue(file: file, message: $0) }
                    continue
                }
                guard seen.insert(level.levelId).inserted else {
                    issues.append(LoadIssue(file: file, message: "duplicate levelId \(level.levelId), file skipped"))
                    continue
                }
                if let n = Self.fileNumber(file), n != level.levelId {
                    issues.append(LoadIssue(file: file, message: "file number \(n) != levelId \(level.levelId) (loaded anyway)"))
                }
                levels.append(level)
            } catch {
                issues.append(LoadIssue(file: file, message: "cannot decode: \(Self.describe(error))"))
            }
        }

        availableLevels = levels.sorted { $0.levelId < $1.levelId }
        loadIssues = issues
        #if DEBUG
        for issue in issues { print("⚠️ [LevelManager] \(issue.file): \(issue.message)") }
        #endif
    }

    /// `level_<n>.json` files in the bundle root and in a `Levels/` folder (folder-reference builds).
    static func levelFileURLs(in bundle: Bundle) -> [URL] {
        let candidates = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            + (bundle.urls(forResourcesWithExtension: "json", subdirectory: "Levels") ?? [])
        var unique: [String: URL] = [:]
        for url in candidates where fileNumber(url.lastPathComponent) != nil {
            unique[url.lastPathComponent] = unique[url.lastPathComponent] ?? url
        }
        return unique.values.sorted { (fileNumber($0.lastPathComponent) ?? 0) < (fileNumber($1.lastPathComponent) ?? 0) }
    }

    /// "level_12.json" -> 12; anything else -> nil.
    static func fileNumber(_ fileName: String) -> Int? {
        guard fileName.hasPrefix("level_"), fileName.hasSuffix(".json") else { return nil }
        return Int(fileName.dropFirst("level_".count).dropLast(".json".count))
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case DecodingError.keyNotFound(let key, let context):
            return "missing key '\(key.stringValue)' at \(path(context))"
        case DecodingError.typeMismatch(_, let context), DecodingError.valueNotFound(_, let context):
            return "\(context.debugDescription) at \(path(context))"
        case DecodingError.dataCorrupted(let context):
            return context.debugDescription
        default:
            return error.localizedDescription
        }
    }

    private static func path(_ context: DecodingError.Context) -> String {
        context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
    }

    // MARK: Queries & switching

    func level(id: Int) -> LevelData? { availableLevels.first { $0.levelId == id } }

    /// Selects a level for play. Returns nil (and keeps the current one) if no such level exists.
    @discardableResult
    func loadLevel(id: Int) -> LevelData? {
        guard let level = level(id: id) else { return nil }
        currentLevel = level
        return level
    }

    func nextLevel(after id: Int) -> LevelData? {
        availableLevels.first { $0.levelId > id }
    }

    /// 1-based position in the list (what the UI shows as "Desk 3"), independent of gaps in `levelId`.
    func displayNumber(of id: Int) -> Int {
        (availableLevels.firstIndex { $0.levelId == id } ?? 0) + 1
    }

    // MARK: Card status (what the level-select grid shows)

    enum LevelStatus: Equatable {
        case locked
        /// Open, not cleared yet.
        case unlocked
        /// Cleared at least once; best star count 1...3.
        case completed(stars: Int)

        var isPlayable: Bool { self != .locked }
    }

    func status(of id: Int, completedIds: Set<Int>, bestStars: [Int: Int]) -> LevelStatus {
        if completedIds.contains(id) { return .completed(stars: min(3, max(1, bestStars[id] ?? 1))) }
        return isUnlocked(id, completedIds: completedIds) ? .unlocked : .locked
    }

    func status(of id: Int, progress: [LevelProgress]) -> LevelStatus {
        let done = progress.filter(\.isCompleted)
        return status(of: id, completedIds: Set(done.map(\.levelId)),
                      bestStars: Dictionary(done.map { ($0.levelId, $0.bestStars) }, uniquingKeysWith: max))
    }

    /// Level the "Continue" button opens: the first open level not cleared yet,
    /// or the last level when everything is done.
    func continueLevelId(completedIds: Set<Int>) -> Int? {
        availableLevels.first { !completedIds.contains($0.levelId) && isUnlocked($0.levelId, completedIds: completedIds) }?
            .levelId ?? availableLevels.last?.levelId
    }

    /// The level that must be cleared to open `id` (for the "Finish Level N first" hint).
    func prerequisite(of id: Int) -> LevelData? {
        guard let index = availableLevels.firstIndex(where: { $0.levelId == id }), index > 0 else { return nil }
        return availableLevels[index - 1]
    }

    var maxStars: Int { availableLevels.count * 3 }

    // MARK: Unlocking (backed by SwiftData `LevelProgress`)

    /// Pure rule, given the completed level ids.
    func isUnlocked(_ id: Int, completedIds: Set<Int>) -> Bool {
        guard let index = availableLevels.firstIndex(where: { $0.levelId == id }) else { return false }
        return index == 0 || completedIds.contains(availableLevels[index - 1].levelId)
    }

    /// Convenience for views that already hold `@Query var progress: [LevelProgress]`.
    func isUnlocked(_ id: Int, progress: [LevelProgress]) -> Bool {
        isUnlocked(id, completedIds: Set(progress.filter(\.isCompleted).map(\.levelId)))
    }

    /// Reads completion straight from the store.
    func isUnlocked(_ id: Int, in context: ModelContext) -> Bool {
        let done = (try? context.fetch(FetchDescriptor<LevelProgress>(predicate: #Predicate { $0.isCompleted }))) ?? []
        return isUnlocked(id, progress: done)
    }
}
