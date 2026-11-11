import Foundation

/// Result of a full placement check: *why* a spot is (not) allowed, cell by cell.
/// Drives the live preview (which cells to paint red) and the drop decision.
struct PlacementCheck: Equatable, Sendable {
    let origin: GridPoint
    let size: GridSize
    /// Footprint cells that fall outside the desk (boundary check).
    let outOfBoundsCells: [GridPoint]
    /// Footprint cells inside the desk that another item already occupies (overlap check).
    let blockedCells: [GridPoint]
    /// Items in the way.
    let blockers: Set<UUID>

    var isWithinBounds: Bool { outOfBoundsCells.isEmpty }
    var isFree: Bool { blockedCells.isEmpty }
    /// Both checks pass -> the item may snap here.
    var isAllowed: Bool { isWithinBounds && isFree }
}

/// The desk: a `rows × columns` occupancy matrix. Pure value type, no UI.
///
/// Storage is a flat row-major array (`cells[row * columns + column]`), so reading a cell is an index,
/// not a hash lookup. Each placed item's footprint is also remembered, so removing or moving an item
/// clears exactly its own cells: O(item area) instead of scanning the whole desk.
struct DeskGrid: Equatable, Sendable {
    struct Footprint: Equatable, Sendable {
        let origin: GridPoint
        let size: GridSize
    }

    let rows: Int
    let columns: Int
    /// Row-major occupancy matrix: id of the item covering each cell, or nil.
    private(set) var cells: [UUID?]
    private(set) var footprints: [UUID: Footprint] = [:]
    private(set) var occupiedCount = 0

    init(rows: Int, columns: Int) {
        precondition(rows > 0 && columns > 0, "Desk must be at least 1x1")
        self.rows = rows
        self.columns = columns
        self.cells = Array(repeating: nil, count: rows * columns)
    }

    var cellCount: Int { rows * columns }
    var isFull: Bool { occupiedCount == cellCount }

    /// Dictionary view of the matrix (cell -> item), for debugging and tests.
    var occupiedCells: [GridPoint: UUID] {
        var result: [GridPoint: UUID] = [:]
        for (index, id) in cells.enumerated() {
            if let id { result[GridPoint(row: index / columns, column: index % columns)] = id }
        }
        return result
    }

    func contains(_ cell: GridPoint) -> Bool {
        cell.row >= 0 && cell.row < rows && cell.column >= 0 && cell.column < columns
    }

    @inline(__always)
    private func index(_ row: Int, _ column: Int) -> Int { row * columns + column }

    func occupant(at cell: GridPoint) -> UUID? {
        contains(cell) ? cells[index(cell.row, cell.column)] : nil
    }

    func footprint(of id: UUID) -> Footprint? { footprints[id] }

    /// All cells an item of `size` would cover with its top-left at `origin` (may include off-desk cells).
    static func cells(origin: GridPoint, size: GridSize) -> [GridPoint] {
        var result: [GridPoint] = []
        result.reserveCapacity(size.area)
        for r in origin.row..<(origin.row + size.height) {
            for c in origin.column..<(origin.column + size.width) {
                result.append(GridPoint(row: r, column: c))
            }
        }
        return result
    }

    // MARK: - Checks

    /// 1. Boundary check: does the whole footprint lie on the desk? Pure arithmetic, no cell reads.
    func isInBounds(origin: GridPoint, size: GridSize) -> Bool {
        origin.row >= 0 && origin.column >= 0
            && origin.row + size.height <= rows
            && origin.column + size.width <= columns
    }

    /// Fast yes/no used on every drag event: boundary check first (cheap), then the overlap check
    /// with an early exit on the first occupied cell. `ignoring` lets an item move onto its own cells.
    func canPlace(size: GridSize, at origin: GridPoint, ignoring id: UUID? = nil) -> Bool {
        guard isInBounds(origin: origin, size: size) else { return false }
        for r in origin.row..<(origin.row + size.height) {
            let rowStart = r * columns
            for c in origin.column..<(origin.column + size.width) {
                if let other = cells[rowStart + c], other != id { return false }
            }
        }
        return true
    }

    /// Full diagnostic check (`canPlaceItem`): which cells are off the desk, which are taken, and by whom.
    func check(size: GridSize, at origin: GridPoint, ignoring id: UUID? = nil) -> PlacementCheck {
        var outside: [GridPoint] = []
        var blocked: [GridPoint] = []
        var blockers = Set<UUID>()
        for cell in Self.cells(origin: origin, size: size) {
            guard contains(cell) else {
                outside.append(cell)
                continue
            }
            if let other = cells[index(cell.row, cell.column)], other != id {
                blocked.append(cell)
                blockers.insert(other)
            }
        }
        return PlacementCheck(origin: origin, size: size, outOfBoundsCells: outside,
                              blockedCells: blocked, blockers: blockers)
    }

    /// Convenience for an item, using its current (rotation-aware) footprint.
    func canPlaceItem(_ item: TechItem, at origin: GridPoint) -> PlacementCheck {
        check(size: item.size, at: origin, ignoring: item.id)
    }

    /// Ids of other items that would be overlapped.
    func collisions(size: GridSize, at origin: GridPoint, ignoring id: UUID? = nil) -> Set<UUID> {
        check(size: size, at: origin, ignoring: id).blockers
    }

    // MARK: - Mutations

    /// Places (or moves) `id`. Returns false and changes nothing when the spot is invalid.
    @discardableResult
    mutating func place(_ id: UUID, size: GridSize, at origin: GridPoint) -> Bool {
        guard canPlace(size: size, at: origin, ignoring: id) else { return false }
        remove(id)
        fill(Footprint(origin: origin, size: size), with: id)
        footprints[id] = Footprint(origin: origin, size: size)
        occupiedCount += size.area
        return true
    }

    mutating func remove(_ id: UUID) {
        guard let footprint = footprints.removeValue(forKey: id) else { return }
        fill(footprint, with: nil)
        occupiedCount -= footprint.size.area
    }

    mutating func removeAll() {
        cells = Array(repeating: nil, count: cellCount)
        footprints = [:]
        occupiedCount = 0
    }

    private mutating func fill(_ footprint: Footprint, with value: UUID?) {
        for r in footprint.origin.row..<(footprint.origin.row + footprint.size.height) {
            let rowStart = r * columns
            for c in footprint.origin.column..<(footprint.origin.column + footprint.size.width) {
                cells[rowStart + c] = value
            }
        }
    }
}
