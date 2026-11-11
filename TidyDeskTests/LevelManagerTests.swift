import XCTest
import UIKit
@testable import TidyDesk

/// The real level files shipped in the app bundle.
@MainActor
final class BundledLevelsTests: XCTestCase {
    private var manager: LevelManager!
    private var levels: [LevelData] { manager.availableLevels }

    override func setUp() async throws {
        manager = LevelManager(bundle: Bundle(for: DeskDragViewModel.self))
    }

    func testAllFilesLoadCleanly() {
        XCTAssertGreaterThanOrEqual(levels.count, 8)
        XCTAssertEqual(manager.loadIssues, [], "\(manager.loadIssues)")
        XCTAssertEqual(levels.map(\.levelId), levels.map(\.levelId).sorted(), "sorted by levelId")
        XCTAssertEqual(Set(levels.map(\.levelId)).count, levels.count)
        XCTAssertTrue(levels.contains { $0.gridRows == 6 && $0.gridCols == 8 }, "an 8x6 desk ships")
        XCTAssertTrue(levels.contains(where: \.hasFixedTargets), "a fixed-target level ships")
    }

    func testEveryLevelIsSolvable() {
        for level in levels {
            let sizes = level.items.map(\.size)
            XCTAssertNotNil(TilingSolver.solvePlacements(rows: level.gridRows, columns: level.gridCols, sizes: sizes,
                                                         allowRotation: true),
                            "level \(level.levelId) has no solution")
        }
    }

    /// Free-fit levels: the messy items must really be in the way, even when drawer items may be rotated.
    func testMessyStartsForceThePlayerToTidy() {
        for level in levels where !level.hasFixedTargets && level.messyItemCount > 0 {
            var fixed: [Int: GridPoint] = [:]
            for (index, item) in level.items.enumerated() {
                if let start = item.initialPosition { fixed[index] = start }
            }
            XCTAssertEqual(level.makeBoard().items.filter(\.isPlaced).count, fixed.count)
            XCTAssertNil(TilingSolver.solvePlacements(rows: level.gridRows, columns: level.gridCols,
                                                      sizes: level.items.map(\.size), fixed: fixed, allowRotation: true),
                         "level \(level.levelId): solvable without moving the messy items")
        }
    }

    /// Fixed-target levels: the targets themselves form a complete, valid desk, and the level doesn't start solved.
    func testFixedTargetsTileTheDesk() {
        for level in levels where level.hasFixedTargets {
            var grid = DeskGrid(rows: level.gridRows, columns: level.gridCols)
            for item in level.items {
                guard let target = item.correctPosition else { continue }
                XCTAssertTrue(grid.place(UUID(), size: item.size, at: target), "level \(level.levelId): '\(item.id)' target")
            }
            if level.items.allSatisfy({ $0.correctPosition != nil }) {
                XCTAssertTrue(grid.isFull, "level \(level.levelId): targets leave holes")
            }
            let board = level.makeBoard()
            XCTAssertFalse(board.items.allSatisfy { $0.isPlaced && $0.isAtTarget }, "level \(level.levelId) starts solved")
        }
    }

    func testSymbolsExist() {
        for level in levels {
            for item in level.items {
                XCTAssertTrue(UIImage(named: item.imageName) != nil || UIImage(systemName: item.imageName) != nil,
                              "level \(level.levelId): no image or SF Symbol named \(item.imageName)")
            }
        }
    }
}

/// Decoding + loader robustness with hand-written files in a temporary folder.
@MainActor
final class LevelManagerTests: XCTestCase {
    private var folder: URL!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("levels-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func write(_ name: String, _ json: String) throws {
        try json.data(using: .utf8)!.write(to: folder.appendingPathComponent(name))
    }

    private static func level(_ id: Int, name: String = "Desk", extra: String = "") -> String {
        """
        { "levelId": \(id), "levelName": "\(name)", "gridRows": 1, "gridCols": 3,
          "items": [
            { "id": "kb", "name": "Keyboard", "gridWidth": 2, "gridHeight": 1,
              "initialPosition": { "row": 0, "col": 1 }, "correctPosition": null, "imageName": "keyboard.fill" },
            { "id": "mug", "name": "Mug", "gridWidth": 1, "gridHeight": 1, "imageName": "cup.and.saucer.fill",
              "category": "cozy"\(extra) }
          ] }
        """
    }

    func testDecodesTheSchema() throws {
        let data = try XCTUnwrap(Self.level(1, name: "Minimalist WFH Setup").data(using: .utf8))
        let level = try JSONDecoder().decode(LevelData.self, from: data)
        XCTAssertEqual(level.levelId, 1)
        XCTAssertEqual(level.levelName, "Minimalist WFH Setup")
        XCTAssertEqual(level.items[0].initialPosition, GridPoint(row: 0, column: 1), "\"col\" maps to column")
        XCTAssertNil(level.items[0].correctPosition, "explicit null")
        XCTAssertNil(level.items[1].initialPosition, "absent = drawer")
        XCTAssertNil(level.items[0].category, "category is optional")
        XCTAssertEqual(level.items[1].category, .cozy)
        XCTAssertEqual(LevelValidator.problems(in: level), [])

        let board = level.makeBoard()
        XCTAssertEqual(board.items.map(\.key), ["kb", "mug"])
        XCTAssertEqual(board.grid.occupant(at: GridPoint(row: 0, column: 2)), board.items[0].id)
    }

    func testLoaderSkipsBadFilesAndKeepsGoodOnes() throws {
        try write("level_1.json", Self.level(1))
        try write("level_2.json", "{ not json")                                                      // broken JSON
        try write("level_3.json", Self.level(3).replacingOccurrences(of: "\"gridCols\": 3", with: "\"gridCols\": 2")) // area / bounds
        try write("level_4.json", Self.level(4).replacingOccurrences(of: "\"levelName\": \"Desk\", ", with: ""))    // missing key
        try write("level_6.json", Self.level(5))                                                     // number != levelId
        try write("level_7.json", Self.level(1))                                                     // duplicate levelId
        try write("notes.json", "{}")                                                               // not a level file

        let bundle = try XCTUnwrap(Bundle(url: folder))
        let manager = LevelManager(bundle: bundle)

        XCTAssertEqual(manager.availableLevels.map(\.levelId), [1, 5])
        let files = Set(manager.loadIssues.map(\.file))
        XCTAssertTrue(files.isSuperset(of: ["level_2.json", "level_3.json", "level_4.json", "level_6.json", "level_7.json"]))
        XCTAssertFalse(files.contains("notes.json"))
        XCTAssertTrue(manager.loadIssues.contains { $0.file == "level_4.json" && $0.message.contains("levelName") },
                      "decoding errors name the missing key")
    }

    func testFileNumberParsing() {
        XCTAssertEqual(LevelManager.fileNumber("level_12.json"), 12)
        XCTAssertNil(LevelManager.fileNumber("level_x.json"))
        XCTAssertNil(LevelManager.fileNumber("levels.json"))
    }

    func testUnlockOrderNextAndLoadLevel() throws {
        let data = { (id: Int) in try JSONDecoder().decode(LevelData.self, from: Self.level(id).data(using: .utf8)!) }
        let manager = LevelManager(levels: [try data(5), try data(1), try data(2)])   // gaps + unsorted on purpose

        XCTAssertEqual(manager.availableLevels.map(\.levelId), [1, 2, 5])
        XCTAssertTrue(manager.isUnlocked(1, completedIds: []))
        XCTAssertFalse(manager.isUnlocked(2, completedIds: []))
        XCTAssertTrue(manager.isUnlocked(2, completedIds: [1]))
        XCTAssertFalse(manager.isUnlocked(5, completedIds: [1]))
        XCTAssertTrue(manager.isUnlocked(5, completedIds: [1, 2]))
        XCTAssertFalse(manager.isUnlocked(99, completedIds: [1, 2, 5]), "unknown level")

        XCTAssertEqual(manager.nextLevel(after: 2)?.levelId, 5)
        XCTAssertNil(manager.nextLevel(after: 5))
        XCTAssertEqual(manager.displayNumber(of: 5), 3)

        // Card states for the level-select grid.
        XCTAssertEqual(manager.status(of: 1, completedIds: [], bestStars: [:]), .unlocked)
        XCTAssertEqual(manager.status(of: 2, completedIds: [], bestStars: [:]), .locked)
        XCTAssertEqual(manager.status(of: 1, completedIds: [1], bestStars: [1: 2]), .completed(stars: 2))
        XCTAssertEqual(manager.status(of: 2, completedIds: [1], bestStars: [1: 2]), .unlocked)
        XCTAssertEqual(manager.status(of: 1, completedIds: [1], bestStars: [1: 7]), .completed(stars: 3), "clamped to 3")
        XCTAssertEqual(manager.prerequisite(of: 5)?.levelId, 2)
        XCTAssertNil(manager.prerequisite(of: 1))
        XCTAssertEqual(manager.maxStars, 9)

        // "Continue": first open, uncleared level; the last level once everything is done.
        XCTAssertEqual(manager.continueLevelId(completedIds: []), 1)
        XCTAssertEqual(manager.continueLevelId(completedIds: [1]), 2)
        XCTAssertEqual(manager.continueLevelId(completedIds: [1, 2, 5]), 5)

        XCTAssertEqual(manager.loadLevel(id: 2)?.levelId, 2)
        XCTAssertEqual(manager.currentLevel?.levelId, 2)
        XCTAssertNil(manager.loadLevel(id: 42))
        XCTAssertEqual(manager.currentLevel?.levelId, 2, "a bad id keeps the current level")
    }
}
