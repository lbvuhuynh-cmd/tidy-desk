import Foundation

/// One level, decoded from a bundled `level_<n>.json` file (schema: `schema/level_schema.json`).
///
/// ```json
/// {
///   "levelId": 1,
///   "levelName": "Morning Coffee",
///   "gridRows": 2,
///   "gridCols": 3,
///   "items": [
///     { "id": "mug", "name": "Coffee Mug", "gridWidth": 1, "gridHeight": 1,
///       "initialPosition": { "row": 0, "col": 1 }, "imageName": "cup.and.saucer.fill", "category": "cozy" },
///     { "id": "keyboard", "name": "Compact Keyboard", "gridWidth": 3, "gridHeight": 1,
///       "initialPosition": null, "correctPosition": { "row": 1, "col": 0 }, "imageName": "keyboard.fill" }
///   ]
/// }
/// ```
/// Immutable; runtime state lives in `DeskDragViewModel`.
struct LevelData: Identifiable, Codable, Hashable, Sendable {
    struct Item: Codable, Hashable, Sendable {
        /// Unique within the level (e.g. "keyboard").
        let id: String
        let name: String
        /// Authored footprint (before any tap-to-rotate).
        let gridWidth: Int
        let gridHeight: Int
        /// Where the item starts: a desk cell (a "messy" item lying in the wrong spot), or `nil` / absent = drawer.
        let initialPosition: GridPoint?
        /// Optional fixed target. When present the level only clears once this item sits exactly here,
        /// in its authored orientation. Absent = "free fit" (anywhere that fits is fine).
        let correctPosition: GridPoint?
        /// Asset name in Assets.xcassets, snake_case, e.g. "keyboard_mechanical". Drawn top-down in the authored
        /// orientation (`gridWidth` × `gridHeight`). One asset name = one footprint across all levels.
        let imageName: String
        /// Optional SF Symbol shown while the asset is not in the catalog yet (e.g. "keyboard.fill").
        let symbol: String?
        /// Optional; drives the tile colour. Defaults to `.peripheral`.
        let category: ItemCategory?

        init(id: String, name: String, gridWidth: Int, gridHeight: Int, initialPosition: GridPoint? = nil,
             correctPosition: GridPoint? = nil, imageName: String, symbol: String? = nil, category: ItemCategory? = nil) {
            self.id = id
            self.name = name
            self.gridWidth = gridWidth
            self.gridHeight = gridHeight
            self.initialPosition = initialPosition
            self.correctPosition = correctPosition
            self.imageName = imageName
            self.symbol = symbol
            self.category = category
        }

        var size: GridSize { GridSize(width: gridWidth, height: gridHeight) }
    }

    let levelId: Int
    let levelName: String
    let gridRows: Int
    let gridCols: Int
    /// Drawer order = array order.
    let items: [Item]

    var id: Int { levelId }
    var totalItemArea: Int { items.reduce(0) { $0 + $1.size.area } }
    var messyItemCount: Int { items.filter { $0.initialPosition != nil }.count }
    /// True when at least one item has a fixed `correctPosition` (the desk shows its outline as a target).
    var hasFixedTargets: Bool { items.contains { $0.correctPosition != nil } }

    /// Fresh runtime state: new UUIDs, messy items already on the desk, the rest in the drawer.
    /// Invalid starting spots (overlap / out of bounds) fall back to the drawer; `LevelValidator` reports them.
    func makeBoard() -> (items: [TechItem], grid: DeskGrid) {
        var grid = DeskGrid(rows: gridRows, columns: gridCols)
        let built = items.map { spec -> TechItem in
            var item = TechItem(key: spec.id, name: spec.name, widthInGrid: spec.gridWidth, heightInGrid: spec.gridHeight,
                                imageName: spec.imageName, symbolName: spec.symbol,
                                category: spec.category ?? .peripheral, targetPosition: spec.correctPosition)
            if let start = spec.initialPosition, grid.place(item.id, size: item.size, at: start) {
                item.currentPosition = start
            }
            return item
        }
        return (built, grid)
    }
}
