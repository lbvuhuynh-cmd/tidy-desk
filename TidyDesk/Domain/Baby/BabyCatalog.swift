import Foundation

/// Something the player can give the baby in Baby Corner.
struct BabyShopItem: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Bought every time it is given (milk, snacks). Fills the tummy.
        case food
        /// Bought once, then playing with it is free. Fills joy.
        case toy
        /// Bought once, then worn any time.
        case outfit
    }

    let id: String
    let name: String
    /// Placeholder picture (big emoji reads well for young kids who can't read yet).
    let emoji: String
    let kind: Kind
    /// Coins. 0 = owned from the start.
    let price: Int
    /// The baby has to be at least this old.
    let minStage: BabyStage
    /// Tummy (food) or joy (toy) added per use.
    let fill: Double
    /// Growth points per use (food, toy). Outfits give none.
    let growth: Int
    /// Outfit colour (0xRRGGBB); unused for food and toys.
    let color: UInt32

    init(id: String, name: String, emoji: String, kind: Kind, price: Int, minStage: BabyStage = .newborn,
         fill: Double = 0, growth: Int = 0, color: UInt32 = 0) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.kind = kind
        self.price = price
        self.minStage = minStage
        self.fill = fill
        self.growth = growth
        self.color = color
    }
}

/// Everything sold in Baby Corner. Ids are stored in `BabyProfile.unlockedItemIds`, so never rename one.
enum BabyCatalog {
    static let items: [BabyShopItem] = [
        // Food: paid per feed.
        BabyShopItem(id: "food.milk", name: "Milk", emoji: "🍼", kind: .food, price: 4, fill: 35, growth: 6),
        BabyShopItem(id: "food.porridge", name: "Porridge", emoji: "🥣", kind: .food, price: 6, minStage: .roller, fill: 45, growth: 8),
        BabyShopItem(id: "food.banana", name: "Banana", emoji: "🍌", kind: .food, price: 5, minStage: .crawler, fill: 30, growth: 7),
        BabyShopItem(id: "food.cookie", name: "Cookie", emoji: "🍪", kind: .food, price: 7, minStage: .toddler, fill: 40, growth: 9),
        BabyShopItem(id: "food.pasta", name: "Pasta", emoji: "🍝", kind: .food, price: 8, minStage: .explorer, fill: 50, growth: 10),
        // Toys: buy once, play for free (growth only while joy isn't full).
        BabyShopItem(id: "toy.rattle", name: "Rattle", emoji: "🪇", kind: .toy, price: 0, fill: 30, growth: 4),
        BabyShopItem(id: "toy.duck", name: "Rubber Duck", emoji: "🦆", kind: .toy, price: 15, fill: 35, growth: 5),
        BabyShopItem(id: "toy.teddy", name: "Teddy Bear", emoji: "🧸", kind: .toy, price: 20, fill: 40, growth: 5),
        BabyShopItem(id: "toy.ball", name: "Ball", emoji: "⚽️", kind: .toy, price: 25, minStage: .crawler, fill: 40, growth: 6),
        BabyShopItem(id: "toy.car", name: "Toy Car", emoji: "🚗", kind: .toy, price: 35, minStage: .toddler, fill: 45, growth: 7),
        BabyShopItem(id: "toy.blocks", name: "Blocks", emoji: "🧱", kind: .toy, price: 30, minStage: .toddler, fill: 45, growth: 7),
        BabyShopItem(id: "toy.crayons", name: "Crayons", emoji: "🖍️", kind: .toy, price: 30, minStage: .explorer, fill: 50, growth: 8),
        // Outfits: buy once, wear any time.
        BabyShopItem(id: "outfit.onesie", name: "Onesie", emoji: "👕", kind: .outfit, price: 0, color: 0xF6E7D4),
        BabyShopItem(id: "outfit.bunny", name: "Bunny Suit", emoji: "🐰", kind: .outfit, price: 20, color: 0xF7C9D6),
        BabyShopItem(id: "outfit.stars", name: "Star Pajamas", emoji: "⭐️", kind: .outfit, price: 30, color: 0x8FA3D9),
        BabyShopItem(id: "outfit.bear", name: "Bear Hoodie", emoji: "🐻", kind: .outfit, price: 40, minStage: .infant, color: 0xC9A27E),
        BabyShopItem(id: "outfit.sunhat", name: "Sun Hat", emoji: "👒", kind: .outfit, price: 30, minStage: .crawler, color: 0xF3D98B),
        BabyShopItem(id: "outfit.dino", name: "Dino Suit", emoji: "🦖", kind: .outfit, price: 45, minStage: .explorer, color: 0x9CCB8A),
    ]

    static let defaultOutfitId = "outfit.onesie"
    /// Free items every baby starts with.
    static var starterItemIds: Set<String> { Set(items.filter { $0.price == 0 }.map(\.id)) }

    static func item(id: String) -> BabyShopItem? { items.first { $0.id == id } }
    static func items(of kind: BabyShopItem.Kind) -> [BabyShopItem] { items.filter { $0.kind == kind } }
}
