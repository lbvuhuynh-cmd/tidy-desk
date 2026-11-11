import Foundation

/// What kind of desk object this is. Drives the tile colour (muted, "cozy tech" palette)
/// and is ready for future rules such as "the mouse belongs next to the keyboard".
enum ItemCategory: String, Codable, CaseIterable, Sendable {
    case peripheral   // keyboard, mouse, mouse pad, controller
    case display      // monitor, laptop, tablet
    case audio        // headphones, speaker, microphone
    case mobile       // phone, webcam
    case power        // cables, power strip, charger
    case cozy         // mug, plant, lamp, notebook
}

/// One draggable desk object with a rectangular footprint.
///
/// Size model:
/// * `widthInGrid` × `heightInGrid` = the **authored** size (as in Levels.json), never changes;
/// * `isRotated` = turned 90° by tap-to-rotate;
/// * `gridWidth` × `gridHeight` = the **current** footprint on the grid, derived from the two above.
///   Everything that touches the grid (collision, snap, layout) uses these.
struct TechItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    /// The item's `id` in the level JSON (e.g. "keyboard"). Stable across replays, unlike `id`.
    let key: String
    var name: String
    let widthInGrid: Int
    let heightInGrid: Int
    /// Top-left cell on the desk, or `nil` while the item sits in the accessory drawer.
    var currentPosition: GridPoint?
    /// Asset-catalog image name. If no such asset exists the SF Symbol with this name is drawn instead,
    /// so real artwork can be dropped into Assets.xcassets later without code changes.
    var imageName: String
    var category: ItemCategory
    /// Turned 90° from its authored orientation (tap-to-rotate in the drawer).
    private(set) var isRotated: Bool = false
    /// Fixed target from the level's `correctPosition` (nil = free fit).
    let targetPosition: GridPoint?

    /// Satisfies its level target: always true for free-fit items; otherwise on the target cell,
    /// in the authored orientation.
    var isAtTarget: Bool {
        guard let targetPosition else { return true }
        return currentPosition == targetPosition && !isRotated
    }

    /// Columns covered right now (depends on rotation).
    var gridWidth: Int { isRotated ? heightInGrid : widthInGrid }
    /// Rows covered right now (depends on rotation).
    var gridHeight: Int { isRotated ? widthInGrid : heightInGrid }
    /// Current footprint.
    var size: GridSize { GridSize(width: gridWidth, height: gridHeight) }

    /// Derived from `currentPosition` so the two can never disagree.
    var isPlaced: Bool { currentPosition != nil }

    /// Rotating a square changes nothing about the fit, but still spins for feedback.
    var isSquare: Bool { widthInGrid == heightInGrid }

    /// Quarter turn: swaps the current footprint. Only valid off the desk (the view model enforces it).
    mutating func rotate() {
        isRotated.toggle()
    }

    init(
        id: UUID = UUID(),
        key: String = "",
        name: String,
        widthInGrid: Int,
        heightInGrid: Int,
        currentPosition: GridPoint? = nil,
        imageName: String,
        category: ItemCategory,
        targetPosition: GridPoint? = nil
    ) {
        precondition(widthInGrid > 0 && heightInGrid > 0, "Item footprint must be at least 1x1")
        self.id = id
        self.key = key.isEmpty ? name : key
        self.targetPosition = targetPosition
        self.name = name
        self.widthInGrid = widthInGrid
        self.heightInGrid = heightInGrid
        self.currentPosition = currentPosition
        self.imageName = imageName
        self.category = category
    }
}
