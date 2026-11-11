import XCTest
@testable import TidyDesk

final class DeskGridTests: XCTestCase {
    private let keyboard = GridSize(width: 3, height: 1)
    private let mousePad = GridSize(width: 2, height: 2)

    func testPlaceMarksEveryCoveredCell() {
        var grid = DeskGrid(rows: 3, columns: 4)
        let id = UUID()
        XCTAssertTrue(grid.place(id, size: mousePad, at: GridPoint(row: 1, column: 2)))
        XCTAssertEqual(grid.occupiedCells.count, 4)
        for cell in [GridPoint(row: 1, column: 2), GridPoint(row: 1, column: 3), GridPoint(row: 2, column: 2), GridPoint(row: 2, column: 3)] {
            XCTAssertEqual(grid.occupant(at: cell), id)
        }
    }

    func testOutOfBoundsIsRejected() {
        var grid = DeskGrid(rows: 2, columns: 3)
        XCTAssertFalse(grid.canPlace(size: keyboard, at: GridPoint(row: 0, column: 1)))  // sticks out right
        XCTAssertFalse(grid.canPlace(size: mousePad, at: GridPoint(row: 1, column: 0)))     // sticks out bottom
        XCTAssertFalse(grid.canPlace(size: keyboard, at: GridPoint(row: -1, column: 0))) // negative
        XCTAssertFalse(grid.place(UUID(), size: keyboard, at: GridPoint(row: 0, column: 1)))
        XCTAssertTrue(grid.occupiedCells.isEmpty)
    }

    func testOverlapIsRejectedAndReportsCollision() {
        var grid = DeskGrid(rows: 3, columns: 3)
        let a = UUID(), b = UUID()
        XCTAssertTrue(grid.place(a, size: mousePad, at: .zero))
        XCTAssertFalse(grid.canPlace(size: keyboard, at: GridPoint(row: 1, column: 0)))
        XCTAssertEqual(grid.collisions(size: keyboard, at: GridPoint(row: 1, column: 0)), [a])
        XCTAssertFalse(grid.place(b, size: keyboard, at: GridPoint(row: 1, column: 0)))
        XCTAssertTrue(grid.place(b, size: keyboard, at: GridPoint(row: 2, column: 0)))
    }

    func testItemCanMoveOntoItsOwnCells() {
        var grid = DeskGrid(rows: 3, columns: 3)
        let id = UUID()
        grid.place(id, size: mousePad, at: .zero)
        XCTAssertTrue(grid.canPlace(size: mousePad, at: GridPoint(row: 0, column: 1), ignoring: id))
        XCTAssertTrue(grid.place(id, size: mousePad, at: GridPoint(row: 0, column: 1)))
        XCTAssertNil(grid.occupant(at: .zero), "old cells are freed")
        XCTAssertEqual(grid.occupiedCells.count, 4)
    }

    func testRemoveAndFull() {
        var grid = DeskGrid(rows: 1, columns: 3)
        let id = UUID()
        grid.place(id, size: keyboard, at: .zero)
        XCTAssertTrue(grid.isFull)
        grid.remove(id)
        XCTAssertFalse(grid.isFull)
        XCTAssertTrue(grid.occupiedCells.isEmpty)
    }

    // MARK: Matrix storage + full diagnostic check (8 columns x 6 rows desk)

    func testMatrixStorageIsRowMajorAndTracksFootprints() {
        var grid = DeskGrid(rows: 6, columns: 8)
        XCTAssertEqual(grid.cells.count, 48)
        let pad = UUID()
        grid.place(pad, size: GridSize(width: 4, height: 2), at: GridPoint(row: 2, column: 3))
        XCTAssertEqual(grid.cells[2 * 8 + 3], pad)          // top-left
        XCTAssertEqual(grid.cells[3 * 8 + 6], pad)          // bottom-right
        XCTAssertNil(grid.cells[2 * 8 + 7])
        XCTAssertEqual(grid.footprint(of: pad),
                       DeskGrid.Footprint(origin: GridPoint(row: 2, column: 3), size: GridSize(width: 4, height: 2)))
        XCTAssertEqual(grid.occupiedCount, 8)

        grid.place(pad, size: GridSize(width: 4, height: 2), at: .zero) // move: old cells cleared
        XCTAssertNil(grid.occupant(at: GridPoint(row: 3, column: 6)))
        XCTAssertEqual(grid.occupiedCount, 8)
        grid.remove(pad)
        XCTAssertEqual(grid.occupiedCount, 0)
        XCTAssertTrue(grid.cells.allSatisfy { $0 == nil })
        grid.remove(pad) // removing twice is harmless
        XCTAssertEqual(grid.occupiedCount, 0)
    }

    func testCheckReportsOverhangAndBlockedCells() {
        var grid = DeskGrid(rows: 6, columns: 8)
        let mouse = UUID()
        grid.place(mouse, size: GridSize(width: 1, height: 1), at: GridPoint(row: 0, column: 6))

        // Keyboard 3x1 at column 6: covers 6 (mouse), 7 (free), 8 (off the desk).
        let check = grid.check(size: keyboard, at: GridPoint(row: 0, column: 6))
        XCTAssertFalse(check.isAllowed)
        XCTAssertFalse(check.isWithinBounds)
        XCTAssertEqual(check.outOfBoundsCells, [GridPoint(row: 0, column: 8)])
        XCTAssertEqual(check.blockedCells, [GridPoint(row: 0, column: 6)])
        XCTAssertEqual(check.blockers, [mouse])

        let fine = grid.check(size: keyboard, at: GridPoint(row: 1, column: 5))
        XCTAssertTrue(fine.isAllowed)
        XCTAssertEqual(fine.isAllowed, grid.canPlace(size: keyboard, at: GridPoint(row: 1, column: 5)))
    }

    func testCanPlaceItemUsesRotatedFootprint() {
        let grid = DeskGrid(rows: 6, columns: 8)
        var pad = TechItem(name: "Mouse Pad", widthInGrid: 4, heightInGrid: 2, imageName: "rectangle.fill", category: .peripheral)
        XCTAssertEqual(pad.gridWidth, 4)
        XCTAssertTrue(grid.canPlaceItem(pad, at: GridPoint(row: 4, column: 4)).isAllowed)  // rows 4-5
        pad.rotate()                                                                        // now 2 wide x 4 tall
        XCTAssertEqual(pad.gridWidth, 2)
        XCTAssertEqual(pad.gridHeight, 4)
        XCTAssertEqual(pad.widthInGrid, 4, "authored size never changes")
        let rotated = grid.canPlaceItem(pad, at: GridPoint(row: 4, column: 4))
        XCTAssertEqual(rotated.outOfBoundsCells.count, 4, "rows 6 and 7 hang off a 6-row desk")
    }
}

final class SnapOriginTests: XCTestCase {
    private func snap(_ x: CGFloat, _ y: CGFloat, current: GridPoint? = nil,
                      blocked: Set<GridPoint> = []) -> (origin: GridPoint, isValid: Bool) {
        SnapMath.snapOrigin(fractional: CGPoint(x: x, y: y), current: current) { origin in
            origin.row >= 0 && origin.column >= 0 && origin.row < 6 && origin.column < 8 && !blocked.contains(origin)
        }
    }

    func testRoundsToNearestFreeCell() {
        let result = snap(2.3, 0.8)
        XCTAssertEqual(result.origin, GridPoint(row: 1, column: 2))
        XCTAssertTrue(result.isValid)
    }

    func testMagnetPullsToFreeNeighbourWhenNearestIsBlocked() {
        // Nearest (1, 2) is taken; (1, 3) is 0.7 cell away -> within reach, so it snaps there.
        let result = snap(2.3, 0.8, blocked: [GridPoint(row: 1, column: 2)])
        XCTAssertEqual(result.origin, GridPoint(row: 1, column: 3))
        XCTAssertTrue(result.isValid)
    }

    func testMagnetHasLimitedReach() {
        // Nearest (1, 2) blocked, neighbours all > 0.75 cell away or blocked -> invalid at the rounded cell.
        let result = snap(2.1, 1.1, blocked: [GridPoint(row: 1, column: 2)])
        XCTAssertEqual(result.origin, GridPoint(row: 1, column: 2))
        XCTAssertFalse(result.isValid)
    }

    func testMagnetPullsBackOntoTheDeskEdge() {
        // Hanging 0.4 cell off the left edge: column -0.4 rounds to 0 anyway; at -0.6 the magnet still lands it at 0.
        XCTAssertEqual(snap(-0.6, 2.0).origin, GridPoint(row: 2, column: 0))
        XCTAssertTrue(snap(-0.6, 2.0).isValid)
        XCTAssertFalse(snap(-0.9, 2.0).isValid, "too far off the edge")
    }

    func testHysteresisKeepsCurrentCellNearTheBoundary() {
        // 0.6 past column 2 would round to 3, but we were on 2 and are within 0.5 + 0.15 -> stay.
        XCTAssertEqual(snap(2.6, 1.0, current: GridPoint(row: 1, column: 2)).origin, GridPoint(row: 1, column: 2))
        // Further out -> switch.
        XCTAssertEqual(snap(2.7, 1.0, current: GridPoint(row: 1, column: 2)).origin, GridPoint(row: 1, column: 3))
        // Hysteresis never holds on to an invalid cell.
        XCTAssertEqual(snap(2.6, 1.0, current: GridPoint(row: 1, column: 2), blocked: [GridPoint(row: 1, column: 2)]).origin,
                       GridPoint(row: 1, column: 3))
    }
}

final class TilingSolverTests: XCTestCase {
    func testFindsTiling() throws {
        let sizes = [GridSize(width: 2, height: 1), GridSize(width: 3, height: 1), GridSize(width: 1, height: 1)]
        let solution = try XCTUnwrap(TilingSolver.solve(rows: 2, columns: 3, sizes: sizes))
        var grid = DeskGrid(rows: 2, columns: 3)
        for (size, origin) in zip(sizes, solution) {
            XCTAssertTrue(grid.place(UUID(), size: size, at: origin))
        }
        XCTAssertTrue(grid.isFull)
    }

    func testAreaMismatchHasNoSolution() {
        XCTAssertNil(TilingSolver.solve(rows: 2, columns: 2, sizes: [GridSize(width: 1, height: 3)]))
    }

    func testRightAreaButImpossibleShape() {
        // 3x3 board, two 2x2 boxes + a 1x1: area 9 but the boxes cannot both fit.
        let sizes = [GridSize(width: 2, height: 2), GridSize(width: 2, height: 2), GridSize(width: 1, height: 1)]
        XCTAssertNil(TilingSolver.solve(rows: 3, columns: 3, sizes: sizes))
    }

    func testRespectsFixedPlacements() {
        let sizes = [GridSize(width: 1, height: 2), GridSize(width: 1, height: 2)]
        XCTAssertEqual(TilingSolver.solve(rows: 2, columns: 2, sizes: sizes, fixed: [0: GridPoint(row: 0, column: 1)]),
                       [GridPoint(row: 0, column: 1), GridPoint(row: 0, column: 0)])
    }

    func testRotationCanUnlockATiling() {
        // A one-column, three-row desk: a 3-wide item only fits when turned.
        let sizes = [GridSize(width: 3, height: 1)]
        XCTAssertNil(TilingSolver.solvePlacements(rows: 3, columns: 1, sizes: sizes, allowRotation: false))
        XCTAssertEqual(TilingSolver.solvePlacements(rows: 3, columns: 1, sizes: sizes, allowRotation: true),
                       [.init(origin: .zero, isRotated: true)])
    }

    func testPinnedItemsKeepTheirOrientation() {
        // 2x2: item 0 (2x1) pinned at the top; item 1 (1x2) must lie flat -> rotated.
        let sizes = [GridSize(width: 2, height: 1), GridSize(width: 1, height: 2)]
        let result = TilingSolver.solvePlacements(rows: 2, columns: 2, sizes: sizes,
                                                  fixed: [0: .zero], allowRotation: true)
        XCTAssertEqual(result, [.init(origin: .zero, isRotated: false),
                                .init(origin: GridPoint(row: 1, column: 0), isRotated: true)])
    }
}

final class ScoreCalculatorTests: XCTestCase {
    func testPerfectFastRunGetsTimeBonus() {
        // 5 items, par = 40 s; 10 s -> 30 s under par -> +150.
        XCTAssertEqual(ScoreCalculator.score(itemCount: 5, moves: 5, seconds: 10), 650)
    }

    func testExtraMovesCostAndScoreHasAFloor() {
        XCTAssertEqual(ScoreCalculator.score(itemCount: 5, moves: 7, seconds: 40), 450)
        XCTAssertEqual(ScoreCalculator.score(itemCount: 5, moves: 60, seconds: 999), 125)
    }

    func testTimeFormatting() {
        XCTAssertEqual(ScoreCalculator.formatTime(0), "0:00")
        XCTAssertEqual(ScoreCalculator.formatTime(65.9), "1:05")
        XCTAssertEqual(ScoreCalculator.formatTime(600), "10:00")
    }
}
