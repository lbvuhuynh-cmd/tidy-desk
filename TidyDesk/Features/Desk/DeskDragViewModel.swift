import SwiftUI
import Observation

/// Name of the coordinate space shared by gestures, frames and the floating drag layer.
enum GameSpace {
    static let name = "game"
}

/// Keys for frames reported through `FramePreferenceKey`.
enum FrameKey {
    static let board = "board"
    static let drawer = "drawer"
    static func drawerItem(_ id: UUID) -> String { "drawer-item-\(id.uuidString)" }
}

enum DragSource: Equatable {
    case drawer
    case board(GridPoint)
}

struct DragSession: Equatable {
    let itemID: UUID
    let source: DragSource
    /// Finger position minus the item's centre, so the item does not jump under the finger.
    let grabFromCenter: CGSize
    var location: CGPoint
}

/// Live preview on the desk while dragging: which cells the item would cover, and which of them are a problem.
struct HoverPreview: Equatable {
    let origin: GridPoint
    let size: GridSize
    let isValid: Bool
    /// In-desk cells already taken by another item (painted strong red).
    var blockedCells: Set<GridPoint> = []

    /// Footprint cells that are on the desk (the ones the preview highlights).
    func visibleCells(rows: Int, columns: Int) -> [GridPoint] {
        DeskGrid.cells(origin: origin, size: size).filter {
            $0.row >= 0 && $0.row < rows && $0.column >= 0 && $0.column < columns
        }
    }
}

enum DropOutcome: Equatable {
    case placed(GridPoint)
    case returnedToDrawer
    case bouncedBack
}

/// What the floating item is doing after the finger lifted. Drives its elevation (shadow / scale / opacity).
enum SettleKind: Equatable {
    /// Falling into a valid cell: elevation goes to zero as it lands.
    case landing
    /// Invalid drop: springs back to where it came from.
    case bouncingBack
}

/// Drag & drop engine + level state.
///
/// Split in two halves:
/// * **Rules** (`place`, `returnToDrawer`, `rotate`, `canPlace`): gesture-free, fully unit-tested.
/// * **Gesture handling** (`dragChanged`, `dragEnded`, `dragCancelled`): turns finger positions in the
///   `GameSpace` coordinate space into snap previews and drop outcomes, and drives the floating item's animation.
@Observable
@MainActor
final class DeskDragViewModel {
    // MARK: Level state
    private(set) var level: LevelData
    private(set) var items: [TechItem]
    private(set) var grid: DeskGrid
    private(set) var moves = 0
    private(set) var isLevelClear = false
    /// Bumped per item on each placement by the player (not for messy starting items);
    /// drives the "pop + glow ring" item-done effect on the desk.
    private(set) var placementCounts: [UUID: Int] = [:]
    /// Bumped per item on each tap-to-rotate; drives the spin animation.
    private(set) var rotationCounts: [UUID: Int] = [:]

    // MARK: Clock & score
    /// Set on the player's first interaction, so reading the level does not count.
    private(set) var startedAt: Date?
    /// Seconds from first interaction to the last item placed.
    private(set) var finishTime: TimeInterval?
    /// Injectable for tests.
    @ObservationIgnored var now: () -> Date = { Date() }

    // MARK: Drag state
    private(set) var session: DragSession?
    private(set) var hover: HoverPreview?
    /// Centre of the floating (dragged) item in `GameSpace`.
    private(set) var floatingCenter: CGPoint = .zero
    /// Extra scale on the floating item: 1 while dragging, 1/liftScale when landing, smaller when flying to the drawer.
    private(set) var floatingScale: CGFloat = 1
    /// Non-nil while the drop animation runs; new drags are ignored meanwhile.
    private(set) var settle: SettleKind?
    var isSettling: Bool { settle != nil }

    // MARK: Layout (set by the view)
    var cellSize: CGFloat = 56
    var drawerCellSize: CGFloat = 32
    /// Frames in `GameSpace`, written from a preference key. Not observed: they change during layout only.
    @ObservationIgnored var frames: [String: CGRect] = [:]

    /// "Lift-off": the floating item is drawn this much bigger than its resting size.
    static let liftScale: CGFloat = 1.08
    /// "Lift-off": the floating item is slightly see-through, like it hovers above the desk.
    static let liftOpacity: Double = 0.9
    /// A touch that moves less than this is a tap, not a drag (matches the DragGesture minimum distance).
    static let dragThreshold: CGFloat = 6

    let feedback: GameFeedback

    init(level: LevelData, feedback: GameFeedback) {
        let board = level.makeBoard()
        self.level = level
        self.items = board.items
        self.grid = board.grid
        self.feedback = feedback
    }

    // MARK: - Queries

    var drawerItems: [TechItem] { items.filter { !$0.isPlaced } }
    var placedItems: [TechItem] { items.filter(\.isPlaced) }
    var stars: Int { StarRating.stars(moves: moves, itemCount: items.count) }
    var score: Int { ScoreCalculator.score(itemCount: items.count, moves: moves, seconds: finishTime ?? elapsed()) }

    func findItem(_ id: UUID) -> TechItem? { items.first { $0.id == id } }

    /// Win condition, driven by the level data:
    /// * free-fit items: just on the desk;
    /// * items with a `correctPosition`: on exactly that cell, in the authored orientation.
    var isSolved: Bool { items.allSatisfy { $0.isPlaced && $0.isAtTarget } }

    /// Items whose target outline should be drawn on the desk (fixed-target levels).
    var targetItems: [TechItem] { items.filter { $0.targetPosition != nil } }

    func canPlace(_ id: UUID, at origin: GridPoint) -> Bool {
        guard let item = findItem(id) else { return false }
        return grid.canPlace(size: item.size, at: origin, ignoring: id)
    }

    /// Seconds played so far (frozen once the level is clear).
    func elapsed(at date: Date? = nil) -> TimeInterval {
        if let finishTime { return finishTime }
        guard let startedAt else { return 0 }
        return max(0, (date ?? now()).timeIntervalSince(startedAt))
    }

    // MARK: - Rules

    func load(_ level: LevelData) {
        let board = level.makeBoard()
        self.level = level
        items = board.items
        grid = board.grid
        moves = 0
        isLevelClear = false
        placementCounts = [:]
        rotationCounts = [:]
        startedAt = nil
        finishTime = nil
        session = nil
        hover = nil
        settle = nil
        floatingScale = 1
    }

    func restart() { load(level) }

    /// Places or moves an item. Returns false (and changes nothing) on collision / out of bounds.
    @discardableResult
    func place(_ id: UUID, at origin: GridPoint) -> Bool {
        guard !isLevelClear, let index = items.firstIndex(where: { $0.id == id }) else { return false }
        let item = items[index]
        guard grid.place(id, size: item.size, at: origin) else { return false }
        startClockIfNeeded()
        if item.currentPosition != origin { moves += 1 }
        items[index].currentPosition = origin
        placementCounts[id, default: 0] += 1
        if isSolved {
            finishTime = elapsed()
            isLevelClear = true
        }
        return true
    }

    func returnToDrawer(_ id: UUID) {
        guard !isLevelClear, let index = items.firstIndex(where: { $0.id == id }) else { return }
        grid.remove(id)
        items[index].currentPosition = nil
    }

    /// Tap-to-rotate: turns a drawer item 90° (width <-> height). Items on the desk cannot rotate.
    /// Not counted as a move.
    @discardableResult
    func rotate(_ id: UUID) -> Bool {
        guard !isLevelClear, session == nil,
              let index = items.firstIndex(where: { $0.id == id }), !items[index].isPlaced else { return false }
        startClockIfNeeded()
        items[index].rotate()
        rotationCounts[id, default: 0] += 1
        feedback.rotated()
        return true
    }

    // MARK: - Gestures

    func dragChanged(itemID: UUID, startLocation: CGPoint, location: CGPoint) {
        if session == nil {
            guard !isSettling, !isLevelClear, let item = findItem(itemID) else { return }
            beginDrag(item, at: startLocation)
        }
        guard var current = session, current.itemID == itemID else { return } // second finger on another item
        current.location = location
        session = current
        withAnimation(.interactiveSpring(response: 0.14, dampingFraction: 0.86)) {
            floatingCenter = location - current.grabFromCenter
        }
        updateHover()
    }

    func dragEnded(itemID: UUID) {
        guard let current = session, current.itemID == itemID, !isSettling else { return }
        let outcome = resolveDrop() ?? .bouncedBack
        let wasOverBoard = hover != nil
        hover = nil

        switch outcome {
        case .placed(let origin):
            guard let item = findItem(itemID), let board = frames[FrameKey.board] else { return finish() }
            settle = .landing
            // Rigid "click" + snap sound right as the finger lifts: zero perceived latency.
            feedback.snapped()
            let target = SnapMath.center(of: origin, size: item.size, boardOrigin: board.origin, cellSize: cellSize)
            // "Falls and grips": quick, slightly bouncy spring into the cell while the shadow collapses.
            withAnimation(.spring(response: 0.22, dampingFraction: 0.68)) {
                floatingCenter = target
                floatingScale = 1 / Self.liftScale // land at exactly cell size
            } completion: { [weak self] in
                guard let self else { return }
                self.place(itemID, at: origin)
                self.finish()
            }

        case .returnedToDrawer:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                returnToDrawer(itemID)
                finish()
            }
            feedback.returnedToDrawer()

        case .bouncedBack:
            // Over the desk = a real collision/out-of-bounds -> warning buzz. Elsewhere = just letting go.
            if wasOverBoard { feedback.rejected() } else { feedback.returnedToDrawer() }
            slideBack(current)
        }
    }

    /// The system cancelled the gesture (incoming call, Control Center, ...): put the item back.
    func dragCancelled(itemID: UUID) {
        guard let current = session, current.itemID == itemID, !isSettling else { return }
        hover = nil
        slideBack(current)
    }

    /// Where would the current drag land if the finger lifted now? Internal for tests.
    func resolveDrop() -> DropOutcome? {
        guard let current = session else { return nil }
        if let hover, hover.isValid { return .placed(hover.origin) }
        // Dragging a placed item away from the desk, onto the drawer, takes it off the desk.
        if case .board = current.source,
           let drawer = frames[FrameKey.drawer], drawer.contains(current.location),
           hover == nil {
            return .returnedToDrawer
        }
        return .bouncedBack
    }

    // MARK: - Private

    private func startClockIfNeeded() {
        if startedAt == nil { startedAt = now() }
    }

    private func beginDrag(_ item: TechItem, at startLocation: CGPoint) {
        let source: DragSource
        let grab: CGSize
        if let origin = item.currentPosition, let board = frames[FrameKey.board] {
            source = .board(origin)
            let center = SnapMath.center(of: origin, size: item.size, boardOrigin: board.origin, cellSize: cellSize)
            grab = startLocation - center
        } else {
            source = .drawer
            // From the drawer the item pops up above the finger so it is not hidden under it.
            let lift = min(CGFloat(item.gridHeight) * cellSize / 2, cellSize) + 12
            grab = CGSize(width: 0, height: lift)
        }
        startClockIfNeeded()
        session = DragSession(itemID: item.id, source: source, grabFromCenter: grab, location: startLocation)
        floatingCenter = startLocation - grab
        floatingScale = 1
        settle = nil
        feedback.pickUp()
    }

    private func updateHover() {
        guard let current = session, let item = findItem(current.itemID), let board = frames[FrameKey.board] else {
            hover = nil
            return
        }
        let center = current.location - current.grabFromCenter // the un-animated, true position
        guard SnapMath.isHovering(itemCenter: center, boardFrame: board, cellSize: cellSize) else {
            if hover != nil { hover = nil }
            return
        }
        // Drop position -> item top-left (rotation-aware footprint) -> fractional cell -> origin cell.
        let size = item.size
        let topLeft = CGPoint(x: center.x - CGFloat(size.width) * cellSize / 2,
                              y: center.y - CGFloat(size.height) * cellSize / 2)
        let fractional = SnapMath.fractionalOrigin(itemTopLeft: topLeft, boardOrigin: board.origin, cellSize: cellSize)
        let desk = self.grid
        let snap = SnapMath.snapOrigin(fractional: fractional, current: hover?.origin) { origin in
            desk.canPlace(size: size, at: origin, ignoring: item.id)   // fast path: bounds, then early-exit overlap
        }
        var preview = HoverPreview(origin: snap.origin, size: size, isValid: snap.isValid)
        if !snap.isValid {
            // Full diagnostic only when something is wrong: which cells to paint red.
            preview.blockedCells = Set(desk.canPlaceItem(item, at: snap.origin).blockedCells)
        }
        guard preview != hover else { return }
        // Selection "tick" every time the item crosses a cell boundary (or first enters the desk).
        if preview.origin != hover?.origin { feedback.cellCrossed() }
        hover = preview
    }

    private func slideBack(_ current: DragSession) {
        guard let item = findItem(current.itemID) else { return finish() }
        let target: CGPoint
        var scale: CGFloat = 1 / Self.liftScale
        switch current.source {
        case .board(let origin):
            guard let board = frames[FrameKey.board] else { return finish() }
            target = SnapMath.center(of: origin, size: item.size, boardOrigin: board.origin, cellSize: cellSize)
        case .drawer:
            guard let slot = frames[FrameKey.drawerItem(item.id)] else { return finish() }
            target = slot.center
            scale = drawerCellSize / (cellSize * Self.liftScale)
        }
        settle = .bouncingBack
        // Bouncier spring than the landing, so a rejected drop reads as "boing, not there".
        withAnimation(.spring(response: 0.36, dampingFraction: 0.58)) {
            floatingCenter = target
            floatingScale = scale
        } completion: { [weak self] in
            self?.finish()
        }
    }

    private func finish() {
        session = nil
        hover = nil
        settle = nil
        floatingScale = 1
    }
}
