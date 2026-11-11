import Foundation

/// Exact-cover backtracking: can these rectangles fill the desk with no overlap and no gap?
/// Used by unit tests to validate levels, and ready to drive a future "hint" button.
enum TilingSolver {
    struct Placement: Equatable {
        let origin: GridPoint
        /// True when the item had to be turned 90° (only possible with `allowRotation`).
        let isRotated: Bool
    }

    /// Origins only, no rotation. One origin per size (same order as `sizes`), or nil when no tiling exists.
    static func solve(rows: Int, columns: Int, sizes: [GridSize], fixed: [Int: GridPoint] = [:]) -> [GridPoint]? {
        solvePlacements(rows: rows, columns: columns, sizes: sizes, fixed: fixed, allowRotation: false)?.map(\.origin)
    }

    /// Full search. `fixed` pins items (index -> origin, authored orientation) before searching,
    /// e.g. messy items or the player's current placements. With `allowRotation` the free items may turn 90°.
    static func solvePlacements(rows: Int, columns: Int, sizes: [GridSize], fixed: [Int: GridPoint] = [:],
                                allowRotation: Bool) -> [Placement]? {
        guard sizes.reduce(0, { $0 + $1.area }) == rows * columns else { return nil }

        var grid = DeskGrid(rows: rows, columns: columns)
        var result = [Placement?](repeating: nil, count: sizes.count)
        let ids = sizes.map { _ in UUID() }

        for (index, origin) in fixed {
            guard sizes.indices.contains(index), grid.place(ids[index], size: sizes[index], at: origin) else { return nil }
            result[index] = Placement(origin: origin, isRotated: false)
        }

        func orientations(_ i: Int) -> [(size: GridSize, rotated: Bool)] {
            let s = sizes[i]
            guard allowRotation, s.width != s.height else { return [(s, false)] }
            return [(s, false), (GridSize(width: s.height, height: s.width), true)]
        }

        /// Two free items are interchangeable when they have the same footprint (up to rotation if allowed),
        /// so trying the second one at the same cell would repeat the same sub-tree.
        func shapeKey(_ s: GridSize) -> GridSize {
            allowRotation ? GridSize(width: min(s.width, s.height), height: max(s.width, s.height)) : s
        }

        func firstEmpty() -> GridPoint? {
            for r in 0..<rows {
                for c in 0..<columns where grid.occupant(at: GridPoint(row: r, column: c)) == nil {
                    return GridPoint(row: r, column: c)
                }
            }
            return nil
        }

        func search() -> Bool {
            // Every rectangle covering the first empty cell (row-major) must have its top-left exactly there.
            guard let cell = firstEmpty() else { return result.allSatisfy { $0 != nil } }
            var tried = Set<[GridSize]>()
            for i in sizes.indices where result[i] == nil {
                for option in orientations(i) {
                    guard tried.insert([shapeKey(sizes[i]), option.size]).inserted else { continue }
                    if grid.place(ids[i], size: option.size, at: cell) {
                        result[i] = Placement(origin: cell, isRotated: option.rotated)
                        if search() { return true }
                        result[i] = nil
                        grid.remove(ids[i])
                    }
                }
            }
            return false
        }

        return search() ? result.compactMap { $0 } : nil
    }
}
