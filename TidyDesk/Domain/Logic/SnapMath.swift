import CoreGraphics

/// Pure geometry for snap-to-grid. All points are in the game's named coordinate space.
///
/// Pipeline for one drag event:
/// 1. item centre (finger − grab offset) → item top-left in points;
/// 2. `fractionalOrigin`: top-left in *cell units* relative to the desk, e.g. (col 2.3, row 0.8);
/// 3. `snapOrigin`: picks the integer origin cell:
///    * **hysteresis**: keep the current cell while the item is within 0.5 + 0.15 cell of it, so a finger
///      resting on a cell boundary doesn't flicker the preview (and the selection haptic) back and forth;
///    * **nearest**: the rounded cell, if both checks pass there;
///    * **magnet**: otherwise the closest *valid* neighbouring origin (floor/ceil on each axis) within
///      `maxReach` cells, so a slightly off drop next to an obstacle or the desk edge still lands;
///    * else the rounded cell, flagged invalid (red preview, bounce-back on drop).
enum SnapMath {
    /// Neighbour origins farther than this (in cells, on either axis) never attract the item.
    static let maxReach: CGFloat = 0.75
    /// Extra distance (in cells) before leaving the current cell.
    static let hysteresis: CGFloat = 0.15

    /// Item top-left in cell units relative to the desk origin (not rounded).
    static func fractionalOrigin(itemTopLeft: CGPoint, boardOrigin: CGPoint, cellSize: CGFloat) -> CGPoint {
        precondition(cellSize > 0)
        return CGPoint(x: (itemTopLeft.x - boardOrigin.x) / cellSize,
                       y: (itemTopLeft.y - boardOrigin.y) / cellSize)
    }

    /// Nearest board cell for an item whose top-left corner is at `itemTopLeft` (plain rounding).
    static func nearestOrigin(itemTopLeft: CGPoint, boardOrigin: CGPoint, cellSize: CGFloat) -> GridPoint {
        let f = fractionalOrigin(itemTopLeft: itemTopLeft, boardOrigin: boardOrigin, cellSize: cellSize)
        return GridPoint(row: Int(f.y.rounded()), column: Int(f.x.rounded()))
    }

    /// Chooses the origin cell for a fractional position (see type docs).
    /// - Parameters:
    ///   - current: origin currently previewed for this drag (for hysteresis), if any.
    ///   - isAllowed: boundary + overlap check for an origin (`DeskGrid.canPlace`).
    static func snapOrigin(fractional f: CGPoint,
                           current: GridPoint?,
                           isAllowed: (GridPoint) -> Bool) -> (origin: GridPoint, isValid: Bool) {
        // 1. Hysteresis: stick with a valid current cell while we are still close to it.
        if let current, distance(f, current) <= 0.5 + hysteresis, isAllowed(current) {
            return (current, true)
        }

        // 2./3. Rounded cell first, then the other floor/ceil neighbours, closest first.
        let rounded = GridPoint(row: Int(f.y.rounded()), column: Int(f.x.rounded()))
        var candidates: [GridPoint] = []
        for row in Set([Int(f.y.rounded(.down)), Int(f.y.rounded(.up))]) {
            for column in Set([Int(f.x.rounded(.down)), Int(f.x.rounded(.up))]) {
                candidates.append(GridPoint(row: row, column: column))
            }
        }
        candidates.sort { lhs, rhs in
            let dl = squaredDistance(f, lhs), dr = squaredDistance(f, rhs)
            return dl != dr ? dl < dr : lhs == rounded // ties: prefer plain rounding
        }
        for candidate in candidates where distance(f, candidate) <= maxReach || candidate == rounded {
            if isAllowed(candidate) { return (candidate, true) }
        }
        // 4. Nothing valid nearby.
        return (rounded, false)
    }

    static func topLeft(of origin: GridPoint, boardOrigin: CGPoint, cellSize: CGFloat) -> CGPoint {
        CGPoint(x: boardOrigin.x + CGFloat(origin.column) * cellSize,
                y: boardOrigin.y + CGFloat(origin.row) * cellSize)
    }

    /// Centre of the target block; the drop animation flies the item's centre here,
    /// which aligns its top-left exactly with the origin cell.
    static func center(of origin: GridPoint, size: GridSize, boardOrigin: CGPoint, cellSize: CGFloat) -> CGPoint {
        let tl = topLeft(of: origin, boardOrigin: boardOrigin, cellSize: cellSize)
        return CGPoint(x: tl.x + CGFloat(size.width) * cellSize / 2,
                       y: tl.y + CGFloat(size.height) * cellSize / 2)
    }

    /// The item counts as "over the desk" while its centre is within half a cell of the desk edge.
    static func isHovering(itemCenter: CGPoint, boardFrame: CGRect, cellSize: CGFloat) -> Bool {
        boardFrame.insetBy(dx: -cellSize / 2, dy: -cellSize / 2).contains(itemCenter)
    }

    /// Chebyshev distance in cells (largest offset on either axis).
    static func distance(_ f: CGPoint, _ cell: GridPoint) -> CGFloat {
        max(abs(f.x - CGFloat(cell.column)), abs(f.y - CGFloat(cell.row)))
    }

    private static func squaredDistance(_ f: CGPoint, _ cell: GridPoint) -> CGFloat {
        let dx = f.x - CGFloat(cell.column), dy = f.y - CGFloat(cell.row)
        return dx * dx + dy * dy
    }
}

extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGSize) -> CGPoint { CGPoint(x: lhs.x - rhs.width, y: lhs.y - rhs.height) }
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGSize { CGSize(width: lhs.x - rhs.x, height: lhs.y - rhs.y) }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
