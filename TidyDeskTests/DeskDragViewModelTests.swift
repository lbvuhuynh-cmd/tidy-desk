import XCTest
@testable import TidyDesk

@MainActor
final class RecordingFeedback: GameFeedback {
    var events: [String] = []
    func pickUp() { events.append("pickUp") }
    func cellCrossed() { events.append("cellCrossed") }
    func snapped(_ traits: ItemTraits) { events.append("snapped"); snappedTraits.append(traits) }
    var snappedTraits: [ItemTraits] = []
    func rejected() { events.append("rejected") }
    func returnedToDrawer() { events.append("returnedToDrawer") }
    func rotated() { events.append("rotated") }
    func lightsOn() { events.append("lightsOn") }
    func levelCleared() { events.append("levelCleared") }
}

@MainActor
final class DeskDragViewModelTests: XCTestCase {
    /// 2 rows x 3 columns:  [K K K] / [C C M]
    private let level = LevelData(levelId: 1, levelName: "Test", gridRows: 2, gridCols: 3, items: [
        .init(id: "keyboard", name: "Compact Keyboard", gridWidth: 3, gridHeight: 1, imageName: "keyboard.fill", category: .peripheral),
        .init(id: "cable", name: "Cable Bundle", gridWidth: 2, gridHeight: 1, imageName: "cable.connector", category: .power),
        .init(id: "mug", name: "Coffee Mug", gridWidth: 1, gridHeight: 1, imageName: "cup.and.saucer.fill", category: .cozy),
    ])

    private var feedback: RecordingFeedback!
    private var vm: DeskDragViewModel!
    /// Completions of drop animations, held so tests can inspect the in-flight state and then settle.
    private var pendingSettles: [() -> Void] = []

    override func setUp() async throws {
        feedback = RecordingFeedback()
        vm = DeskDragViewModel(level: level, feedback: feedback)
        pendingSettles = []
        vm.animateSettle = { [unowned self] _, body, completion in
            body()
            self.pendingSettles.append(completion)
        }
    }

    private func finishSettleAnimations() {
        let completions = pendingSettles
        pendingSettles = []
        completions.forEach { $0() }
    }

    private var keyboard: TechItem { vm.items[0] }
    private var cable: TechItem { vm.items[1] }
    private var mug: TechItem { vm.items[2] }

    // MARK: Rules

    func testPerfectSolveClearsLevelWithThreeStars() {
        XCTAssertTrue(vm.place(keyboard.id, at: GridPoint(row: 0, column: 0)))
        XCTAssertTrue(vm.place(cable.id, at: GridPoint(row: 1, column: 0)))
        XCTAssertFalse(vm.isLevelClear)
        XCTAssertTrue(vm.place(mug.id, at: GridPoint(row: 1, column: 2)))
        XCTAssertTrue(vm.isLevelClear)
        XCTAssertTrue(vm.grid.isFull)
        XCTAssertEqual(vm.moves, 3)
        XCTAssertEqual(vm.stars, 3)
        XCTAssertTrue(vm.drawerItems.isEmpty)
    }

    func testCollisionLeavesStateUntouched() {
        vm.place(keyboard.id, at: .zero)
        XCTAssertFalse(vm.place(mug.id, at: GridPoint(row: 0, column: 1)))
        XCTAssertNil(mug.currentPosition)
        XCTAssertEqual(vm.moves, 1)
    }

    func testOutOfBoundsRejected() {
        XCTAssertFalse(vm.place(cable.id, at: GridPoint(row: 0, column: 2)))
        XCTAssertFalse(vm.canPlace(keyboard.id, at: GridPoint(row: 2, column: 0)))
        XCTAssertEqual(vm.moves, 0)
    }

    func testMovingFreesOldCellsAndCountsAMove() {
        vm.place(mug.id, at: .zero)
        vm.place(mug.id, at: GridPoint(row: 1, column: 2))
        XCTAssertNil(vm.grid.occupant(at: .zero))
        XCTAssertEqual(vm.grid.occupant(at: GridPoint(row: 1, column: 2)), mug.id)
        XCTAssertEqual(vm.moves, 2)
        // Dropping in the same spot is not a move.
        vm.place(mug.id, at: GridPoint(row: 1, column: 2))
        XCTAssertEqual(vm.moves, 2)
    }

    func testReturnToDrawerAndRestart() {
        vm.place(mug.id, at: .zero)
        vm.returnToDrawer(mug.id)
        XCTAssertFalse(mug.isPlaced)
        XCTAssertTrue(vm.grid.occupiedCells.isEmpty)
        vm.place(keyboard.id, at: .zero)
        vm.restart()
        XCTAssertEqual(vm.moves, 0)
        XCTAssertTrue(vm.placedItems.isEmpty)
        XCTAssertEqual(vm.drawerItems.count, 3)
    }

    func testExtraMovesLowerStars() {
        XCTAssertEqual(StarRating.stars(moves: 3, itemCount: 3), 3)
        XCTAssertEqual(StarRating.stars(moves: 5, itemCount: 3), 2)
        XCTAssertEqual(StarRating.stars(moves: 6, itemCount: 3), 1)
    }

    // MARK: Messy start

    func testMessyItemsStartOnTheDesk() {
        let messy = LevelData(levelId: 2, levelName: "Messy", gridRows: 2, gridCols: 3, items: [
            .init(id: "mug", name: "Coffee Mug", gridWidth: 1, gridHeight: 1, initialPosition: GridPoint(row: 0, column: 1),
                  imageName: "cup.and.saucer.fill", category: .cozy),
            .init(id: "cable", name: "Cable Bundle", gridWidth: 2, gridHeight: 1, imageName: "cable.connector", category: .power),
            .init(id: "keyboard", name: "Compact Keyboard", gridWidth: 3, gridHeight: 1, imageName: "keyboard.fill", category: .peripheral),
        ])
        vm.load(messy)
        let mug = vm.items[0]
        XCTAssertEqual(mug.currentPosition, GridPoint(row: 0, column: 1))
        XCTAssertEqual(vm.grid.occupant(at: GridPoint(row: 0, column: 1)), mug.id)
        XCTAssertEqual(vm.drawerItems.count, 2)
        XCTAssertEqual(vm.moves, 0)
        XCTAssertEqual(vm.placementCounts[mug.id], nil, "no item-done effect for the starting mess")

        // The keyboard fits in row 1, but then the cable has no 2-wide gap: the mug must move.
        XCTAssertTrue(vm.place(vm.items[2].id, at: GridPoint(row: 1, column: 0)))
        XCTAssertFalse(vm.canPlace(vm.items[1].id, at: GridPoint(row: 0, column: 0)))
        XCTAssertTrue(vm.place(mug.id, at: GridPoint(row: 0, column: 2)))
        XCTAssertTrue(vm.place(vm.items[1].id, at: GridPoint(row: 0, column: 0)))
        XCTAssertTrue(vm.isLevelClear)
        XCTAssertEqual(vm.stars, 3)
    }

    func testInvalidMessyStartFallsBackToDrawer() {
        let broken = LevelData(levelId: 3, levelName: "Broken", gridRows: 1, gridCols: 2, items: [
            .init(id: "a", name: "A", gridWidth: 2, gridHeight: 1, initialPosition: GridPoint(row: 0, column: 1), // sticks out
                  imageName: "keyboard.fill"),
        ])
        vm.load(broken)
        XCTAssertNil(vm.items[0].currentPosition)
        XCTAssertTrue(vm.grid.occupiedCells.isEmpty)
        XCTAssertEqual(vm.items[0].category, .peripheral, "missing category defaults to peripheral")
        XCTAssertFalse(LevelValidator.problems(in: broken).isEmpty, "the validator flags it at load time")
    }

    // MARK: Fixed targets (correctPosition)

    func testFixedTargetsMustAllBeMetToClear() {
        let fixed = LevelData(levelId: 4, levelName: "Fixed", gridRows: 2, gridCols: 3, items: [
            .init(id: "keyboard", name: "Keyboard", gridWidth: 3, gridHeight: 1,
                  correctPosition: GridPoint(row: 1, column: 0), imageName: "keyboard.fill"),
            .init(id: "cable", name: "Cable", gridWidth: 2, gridHeight: 1,
                  correctPosition: GridPoint(row: 0, column: 1), imageName: "cable.connector"),
            .init(id: "mug", name: "Mug", gridWidth: 1, gridHeight: 1,
                  correctPosition: GridPoint(row: 0, column: 0), imageName: "cup.and.saucer.fill"),
        ])
        vm.load(fixed)
        XCTAssertEqual(vm.targetItems.count, 3)
        let (kb, cb, mg) = (vm.items[0].id, vm.items[1].id, vm.items[2].id)

        // Desk full, but in the "wrong" arrangement -> not cleared yet.
        vm.place(kb, at: GridPoint(row: 0, column: 0))
        vm.place(cb, at: GridPoint(row: 1, column: 0))
        vm.place(mg, at: GridPoint(row: 1, column: 2))
        XCTAssertTrue(vm.grid.isFull)
        XCTAssertFalse(vm.isLevelClear)

        // Rearrange onto the targets.
        vm.returnToDrawer(kb); vm.returnToDrawer(cb); vm.returnToDrawer(mg)
        vm.place(mg, at: GridPoint(row: 0, column: 0))
        vm.place(cb, at: GridPoint(row: 0, column: 1))
        XCTAssertFalse(vm.isLevelClear)
        vm.place(kb, at: GridPoint(row: 1, column: 0))
        XCTAssertTrue(vm.isLevelClear)
    }

    // MARK: Gesture engine (no rendering; checks snap preview + drop decision)

    /// Board 3x2 cells of 50pt at (100, 100); drawer below it.
    private func layOut() {
        vm.cellSize = 50
        vm.drawerCellSize = 30
        vm.frames = [
            FrameKey.board: CGRect(x: 100, y: 100, width: 150, height: 100),
            FrameKey.drawer: CGRect(x: 0, y: 400, width: 400, height: 200),
        ]
    }

    func testDraggingFromDrawerSnapsToNearestValidCell() {
        layOut()
        let start = CGPoint(x: 200, y: 500)
        vm.dragChanged(itemID: mug.id, startLocation: start, location: start)
        XCTAssertEqual(vm.session?.source, .drawer)
        XCTAssertNil(vm.hover)

        // Drawer pickups float `lift` = min(25, 50) + 12 = 37pt above the finger.
        // Item centre (182, 128) -> top-left (157, 103) -> nearest cell column 1, row 0.
        vm.dragChanged(itemID: mug.id, startLocation: start, location: CGPoint(x: 182, y: 165))
        XCTAssertEqual(vm.hover, HoverPreview(origin: GridPoint(row: 0, column: 1), size: mug.size, isValid: true))
        XCTAssertEqual(vm.resolveDrop(), .placed(GridPoint(row: 0, column: 1)))
        XCTAssertEqual(feedback.events, ["pickUp", "cellCrossed"])

        // Small wiggles inside the same cell: no extra tick. Crossing into the next cell: one more tick.
        vm.dragChanged(itemID: mug.id, startLocation: start, location: CGPoint(x: 185, y: 167))
        XCTAssertEqual(feedback.events.filter { $0 == "cellCrossed" }.count, 1)
        vm.dragChanged(itemID: mug.id, startLocation: start, location: CGPoint(x: 232, y: 165))
        XCTAssertEqual(vm.hover?.origin, GridPoint(row: 0, column: 2))
        XCTAssertEqual(feedback.events.filter { $0 == "cellCrossed" }.count, 2)

        // Finger lifts over a valid cell: rigid + snap sound fire immediately (onEnded), not after the landing animation.
        vm.dragEnded(itemID: mug.id)
        XCTAssertEqual(feedback.events, ["pickUp", "cellCrossed", "cellCrossed", "snapped"])
        // The mug lands with its own ceramic clink (traits from the asset name).
        XCTAssertEqual(feedback.snappedTraits, [ItemTraits(material: .ceramic, life: .steam)])
        XCTAssertEqual(vm.settle, .landing)

        // Landing animation done: the mug is committed to the hovered cell and the drag is over.
        finishSettleAnimations()
        XCTAssertEqual(mug.currentPosition, GridPoint(row: 0, column: 2))
        XCTAssertNil(vm.settle)
        XCTAssertNil(vm.session)
    }

    func testInvalidDropOverDeskPlaysError() {
        layOut()
        vm.place(keyboard.id, at: .zero)
        let start = CGPoint(x: 200, y: 500)
        vm.frames[FrameKey.drawerItem(mug.id)] = CGRect(x: 180, y: 480, width: 30, height: 30)
        vm.dragChanged(itemID: mug.id, startLocation: start, location: start)
        vm.dragChanged(itemID: mug.id, startLocation: start, location: CGPoint(x: 182, y: 165)) // over the keyboard
        vm.dragEnded(itemID: mug.id)
        XCTAssertEqual(feedback.events.last, "rejected")
        XCTAssertEqual(vm.settle, .bouncingBack)
        XCTAssertFalse(feedback.events.contains("snapped"))

        finishSettleAnimations()
        XCTAssertFalse(mug.isPlaced)
        XCTAssertNil(vm.settle)
    }

    func testHoverOverOccupiedCellIsInvalidAndBounces() {
        layOut()
        vm.place(keyboard.id, at: .zero)
        let start = CGPoint(x: 200, y: 500)
        vm.dragChanged(itemID: mug.id, startLocation: start, location: start)
        vm.dragChanged(itemID: mug.id, startLocation: start, location: CGPoint(x: 182, y: 165))
        XCTAssertEqual(vm.hover?.isValid, false)
        XCTAssertEqual(vm.hover?.blockedCells, [GridPoint(row: 0, column: 1)], "preview paints the keyboard's cell red")
        XCTAssertEqual(vm.resolveDrop(), .bouncedBack)
        XCTAssertTrue(feedback.events.contains("cellCrossed"), "cell boundaries tick even over occupied cells")
    }

    // MARK: Tap-to-rotate

    func testRotateSwapsFootprintInDrawerOnly() {
        XCTAssertTrue(vm.rotate(keyboard.id))
        XCTAssertEqual(keyboard.size, GridSize(width: 1, height: 3))
        XCTAssertTrue(keyboard.isRotated)
        XCTAssertEqual(vm.rotationCounts[keyboard.id], 1)
        XCTAssertEqual(vm.moves, 0, "rotating is free")
        XCTAssertEqual(feedback.events, ["rotated"])

        // A 1x3 keyboard does not fit a 2-row desk any more...
        XCTAssertFalse(vm.canPlace(keyboard.id, at: .zero))
        // ...turn it back and place it; once on the desk it can no longer rotate.
        vm.rotate(keyboard.id)
        XCTAssertEqual(keyboard.size, GridSize(width: 3, height: 1))
        XCTAssertFalse(keyboard.isRotated)
        XCTAssertTrue(vm.place(keyboard.id, at: .zero))
        XCTAssertFalse(vm.rotate(keyboard.id))
        XCTAssertEqual(keyboard.size, GridSize(width: 3, height: 1))
    }

    func testRotationIsKeptWhenReturnedToDrawerAndResetOnRestart() {
        vm.rotate(cable.id)                                  // 2x1 -> 1x2
        XCTAssertTrue(vm.place(cable.id, at: GridPoint(row: 0, column: 0)))
        XCTAssertEqual(vm.grid.occupant(at: GridPoint(row: 1, column: 0)), cable.id)
        vm.returnToDrawer(cable.id)
        XCTAssertEqual(cable.size, GridSize(width: 1, height: 2))
        vm.restart()
        XCTAssertEqual(cable.size, GridSize(width: 2, height: 1))
        XCTAssertTrue(vm.rotationCounts.isEmpty)
    }

    // MARK: Clock & score

    func testClockStartsOnFirstActionAndFreezesOnClear() {
        var clock = Date(timeIntervalSince1970: 1_000)
        vm.now = { clock }
        XCTAssertEqual(vm.elapsed(), 0)
        clock += 30                                          // reading the level: not counted
        XCTAssertNil(vm.startedAt)

        vm.place(keyboard.id, at: .zero)
        clock += 12
        XCTAssertEqual(vm.elapsed(), 12, accuracy: 0.001)
        vm.place(cable.id, at: GridPoint(row: 1, column: 0))
        clock += 8
        vm.place(mug.id, at: GridPoint(row: 1, column: 2))
        XCTAssertTrue(vm.isLevelClear)
        XCTAssertEqual(vm.finishTime ?? -1, 20, accuracy: 0.001)
        clock += 100
        XCTAssertEqual(vm.elapsed(), 20, accuracy: 0.001, "frozen after clear")
        // 3 items: base 300, par 28 s -> (28 - 20) * 5 = 40 bonus, no extra moves.
        XCTAssertEqual(vm.score, 340)
    }

    func testMagnetSnapsNextToAnObstacle() {
        layOut()
        vm.place(keyboard.id, at: .zero)                       // row 0 is full
        let start = CGPoint(x: 200, y: 500)
        vm.dragChanged(itemID: mug.id, startLocation: start, location: start)
        // Mug centre (215, 145) -> top-left (190, 120) -> fractional (col 1.8, row 0.4).
        // Nearest cell (0, 2) is the keyboard; (1, 2) is 0.6 cell away and free -> magnet.
        vm.dragChanged(itemID: mug.id, startLocation: start, location: CGPoint(x: 215, y: 182))
        XCTAssertEqual(vm.hover, HoverPreview(origin: GridPoint(row: 1, column: 2), size: mug.size, isValid: true))
        XCTAssertEqual(vm.resolveDrop(), .placed(GridPoint(row: 1, column: 2)))
    }

    func testDraggingPlacedItemIntoDrawerRemovesIt() {
        layOut()
        vm.place(mug.id, at: GridPoint(row: 1, column: 2))
        // Grab the mug at its centre (225, 175) and drag it to the drawer.
        let start = CGPoint(x: 225, y: 175)
        vm.dragChanged(itemID: mug.id, startLocation: start, location: start)
        XCTAssertEqual(vm.session?.source, .board(GridPoint(row: 1, column: 2)))
        vm.dragChanged(itemID: mug.id, startLocation: start, location: CGPoint(x: 200, y: 480))
        XCTAssertNil(vm.hover)
        XCTAssertEqual(vm.resolveDrop(), .returnedToDrawer)

        vm.dragEnded(itemID: mug.id)
        XCTAssertFalse(mug.isPlaced)
        XCTAssertNil(vm.session)
    }

    func testSecondFingerOnAnotherItemIsIgnored() {
        layOut()
        let start = CGPoint(x: 200, y: 500)
        vm.dragChanged(itemID: mug.id, startLocation: start, location: start)
        vm.dragChanged(itemID: cable.id, startLocation: CGPoint(x: 50, y: 450), location: CGPoint(x: 60, y: 450))
        XCTAssertEqual(vm.session?.itemID, mug.id)
    }
}

final class SnapMathTests: XCTestCase {
    func testRoundsToNearestCell() {
        let board = CGPoint(x: 100, y: 100)
        XCTAssertEqual(SnapMath.nearestOrigin(itemTopLeft: CGPoint(x: 124, y: 100), boardOrigin: board, cellSize: 50),
                       GridPoint(row: 0, column: 0))
        XCTAssertEqual(SnapMath.nearestOrigin(itemTopLeft: CGPoint(x: 126, y: 174), boardOrigin: board, cellSize: 50),
                       GridPoint(row: 1, column: 1))
        XCTAssertEqual(SnapMath.nearestOrigin(itemTopLeft: CGPoint(x: 60, y: 100), boardOrigin: board, cellSize: 50),
                       GridPoint(row: 0, column: -1), "off-board origins are returned as-is; the grid rejects them")
    }

    func testCenterAndHovering() {
        let center = SnapMath.center(of: GridPoint(row: 1, column: 0), size: GridSize(width: 2, height: 1),
                                     boardOrigin: CGPoint(x: 100, y: 100), cellSize: 50)
        XCTAssertEqual(center, CGPoint(x: 150, y: 175))
        let board = CGRect(x: 100, y: 100, width: 150, height: 100)
        XCTAssertTrue(SnapMath.isHovering(itemCenter: CGPoint(x: 80, y: 150), boardFrame: board, cellSize: 50))
        XCTAssertFalse(SnapMath.isHovering(itemCenter: CGPoint(x: 70, y: 150), boardFrame: board, cellSize: 50))
    }
}
