import Foundation

/// Structural checks run on every level as it is loaded. A level with problems is skipped (and reported)
/// instead of crashing the game. Solvability is a heavier check and lives in the unit tests +
/// `tools/check_levels.py`.
enum LevelValidator {
    static func problems(in level: LevelData) -> [String] {
        var problems: [String] = []
        let rows = level.gridRows, cols = level.gridCols

        if level.levelId < 1 { problems.append("levelId must be >= 1") }
        if level.levelName.trimmingCharacters(in: .whitespaces).isEmpty { problems.append("levelName is empty") }
        guard rows > 0, cols > 0 else { return problems + ["gridRows / gridCols must be > 0"] }
        if level.items.isEmpty { problems.append("no items") }

        let ids = level.items.map(\.id)
        if Set(ids).count != ids.count { problems.append("item ids are not unique") }

        // "Cozy tidy" rule: the items fill the desk exactly.
        if level.totalItemArea != rows * cols {
            problems.append("item area \(level.totalItemArea) != desk area \(rows * cols)")
        }

        var start = DeskGrid(rows: rows, columns: cols)
        var target = DeskGrid(rows: rows, columns: cols)
        for item in level.items {
            let tag = "item '\(item.id)'"
            if item.name.isEmpty || item.imageName.isEmpty { problems.append("\(tag): name / imageName missing") }
            guard item.gridWidth > 0, item.gridHeight > 0 else {
                problems.append("\(tag): gridWidth / gridHeight must be > 0")
                continue
            }
            let fitsAsAuthored = item.gridWidth <= cols && item.gridHeight <= rows
            let fitsRotated = item.gridHeight <= cols && item.gridWidth <= rows
            if !fitsAsAuthored && !fitsRotated {
                problems.append("\(tag): \(item.gridWidth)x\(item.gridHeight) does not fit the desk in any orientation")
            }
            if let p = item.initialPosition, !start.place(UUID(), size: item.size, at: p) {
                problems.append("\(tag): initialPosition \(p) is off the desk or overlaps another item")
            }
            if let p = item.correctPosition, !target.place(UUID(), size: item.size, at: p) {
                problems.append("\(tag): correctPosition \(p) is off the desk or overlaps another target")
            }
        }
        if level.messyItemCount == level.items.count, !level.items.isEmpty {
            problems.append("every item starts on the desk; nothing left in the drawer")
        }
        return problems
    }
}
