import Foundation

/// What an item is made of, i.e. what it *sounds* like when it lands on the wooden desk.
enum ItemMaterial: String, CaseIterable, Sendable {
    /// Keyboards: a little clatter of keycaps.
    case keys
    /// Mugs, plant pots: a bright ceramic "clink".
    case ceramic
    /// Desk mat, notebook, headphones: a muffled, cushioned thump.
    case soft
    /// Cables, power strips: a short rustle and a plastic tick.
    case cable
    /// Hard-shell electronics (laptop, monitor, phone, speaker…): the classic woody click.
    case device
}

/// What an item does once it sits on the desk: the small "it came alive" moment that makes a tidy desk
/// feel lived in. Purely visual (see `ItemLifeEffect`); `powersOn` items also play a soft power-on blip.
enum ItemLife: String, CaseIterable, Sendable {
    /// Coffee: wisps of steam.
    case steam
    /// Desk lamps: a warm pool of light on the wood.
    case warmLight
    /// Monitors, laptops, tablets, phones: the screen wakes up with a cool glow.
    case screenGlow
    /// Plants: leaves swaying gently.
    case sway
    /// Speakers: soft sound-wave rings.
    case soundWaves
    /// Routers, mics, webcams, controllers, power strips: a blinking status LED.
    case statusLED
    /// Keyboards: RGB underglow.
    case underglow
    /// Nothing special (notebook, desk mat, cables…).
    case none

    /// Electronics that switch on: they get the power-on blip after the snap.
    var powersOn: Bool {
        switch self {
        case .warmLight, .screenGlow, .underglow, .soundWaves: true
        default: false
        }
    }
}

/// Personality of an item: derived from its asset name (`keyboard_mechanical` → keys + underglow), with the
/// category as a fallback, so level files need no extra fields and new assets just work if they follow the naming.
struct ItemTraits: Equatable, Sendable {
    let material: ItemMaterial
    let life: ItemLife

    static func of(imageName: String, category: ItemCategory) -> ItemTraits {
        let name = imageName.lowercased()
        func has(_ words: String...) -> Bool { words.contains { name.contains($0) } }

        // Order matters: "headphones" and "microphone" both contain "phone".
        if has("keyboard") { return .init(material: .keys, life: .underglow) }
        if has("headphone") { return .init(material: .soft, life: .none) }
        if has("mic") { return .init(material: .device, life: .statusLED) }
        if has("mug", "coffee", "cup", "tea") { return .init(material: .ceramic, life: .steam) }
        // Garden: paper / fabric / sacks land soft; tools clink; anything growing sways.
        if has("seed_packet", "gloves", "soil", "basket") { return .init(material: .soft, life: .none) }
        if has("watering") { return .init(material: .ceramic, life: .none) }
        if has("shears", "trowel", "birdhouse") { return .init(material: .device, life: .none) }
        if has("plant", "succulent", "cactus", "flower", "herb", "seedling", "monstera") {
            return .init(material: .ceramic, life: .sway)
        }
        if has("lamp", "light") { return .init(material: .device, life: .warmLight) }
        if has("monitor", "laptop", "tablet", "phone", "display", "screen") {
            return .init(material: .device, life: .screenGlow)
        }
        if has("speaker") { return .init(material: .device, life: .soundWaves) }
        if has("router", "wifi", "webcam", "controller", "power_strip") {
            return .init(material: has("power_strip") ? .cable : .device, life: .statusLED)
        }
        if has("cable", "charger", "cord") { return .init(material: .cable, life: .none) }
        if has("mat", "notebook", "book", "pad") { return .init(material: .soft, life: .none) }
        if has("mouse") { return .init(material: .device, life: .none) }

        switch category {
        case .peripheral, .mobile: return .init(material: .device, life: .none)
        case .display: return .init(material: .device, life: .screenGlow)
        case .audio: return .init(material: .device, life: .none)
        case .power: return .init(material: .cable, life: .none)
        case .cozy, .garden: return .init(material: .soft, life: .none)
        }
    }
}

extension TechItem {
    var traits: ItemTraits { ItemTraits.of(imageName: imageName, category: category) }
}
