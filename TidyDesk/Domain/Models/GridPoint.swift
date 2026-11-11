import Foundation

/// A cell coordinate on the desk grid. `row` grows downward, `column` grows rightward.
/// JSON form (level files): `{ "row": 2, "col": 3 }`.
struct GridPoint: Hashable, Codable, Sendable, CustomStringConvertible {
    var row: Int
    var column: Int

    init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    private enum CodingKeys: String, CodingKey {
        case row
        case column = "col"
    }

    static let zero = GridPoint(row: 0, column: 0)

    var description: String { "(r\(row), c\(column))" }
}

/// Footprint of an item, in grid cells.
struct GridSize: Hashable, Codable, Sendable {
    var width: Int
    var height: Int

    var area: Int { width * height }
}
