import XCTest
@testable import TidyDesk

final class ItemTraitsTests: XCTestCase {
    private func traits(_ name: String, _ category: ItemCategory = .peripheral) -> ItemTraits {
        ItemTraits.of(imageName: name, category: category)
    }

    func testDeviceNamesMapToTheRightPersonality() {
        XCTAssertEqual(traits("keyboard_mechanical"), ItemTraits(material: .keys, life: .underglow))
        XCTAssertEqual(traits("coffee_mug", .cozy), ItemTraits(material: .ceramic, life: .steam))
        XCTAssertEqual(traits("plant", .cozy), ItemTraits(material: .ceramic, life: .sway))
        XCTAssertEqual(traits("desk_lamp_tall", .cozy), ItemTraits(material: .device, life: .warmLight))
        XCTAssertEqual(traits("monitor_ultrawide", .display), ItemTraits(material: .device, life: .screenGlow))
        XCTAssertEqual(traits("speaker_tower", .audio), ItemTraits(material: .device, life: .soundWaves))
        XCTAssertEqual(traits("wifi_router", .power).life, .statusLED)
        XCTAssertEqual(traits("power_strip", .power), ItemTraits(material: .cable, life: .statusLED))
        XCTAssertEqual(traits("cable_bundle", .power), ItemTraits(material: .cable, life: .none))
        XCTAssertEqual(traits("desk_mat"), ItemTraits(material: .soft, life: .none))
        XCTAssertEqual(traits("mouse_wireless"), ItemTraits(material: .device, life: .none))
    }

    /// "headphones" and "microphone" contain "phone" but must not light up like a phone screen.
    func testPhoneLookalikesAreNotScreens() {
        XCTAssertEqual(traits("headphones", .audio), ItemTraits(material: .soft, life: .none))
        XCTAssertEqual(traits("microphone", .audio).life, .statusLED)
        XCTAssertEqual(traits("mic_boom", .audio).life, .statusLED)
        XCTAssertEqual(traits("phone", .mobile).life, .screenGlow)
    }

    func testUnknownNamesFallBackToCategory() {
        XCTAssertEqual(traits("mystery_gadget", .display).life, .screenGlow)
        XCTAssertEqual(traits("mystery_gadget", .power).material, .cable)
        XCTAssertEqual(traits("mystery_gadget", .cozy).material, .soft)
    }

    @MainActor
    func testEveryShippedItemHasASnapSoundFile() {
        let manager = LevelManager(bundle: Bundle(for: DeskDragViewModel.self))
        for level in manager.availableLevels {
            for spec in level.items {
                let sound = SoundManager.Sound.snap(for: ItemTraits.of(imageName: spec.imageName,
                                                                      category: spec.category ?? .peripheral).material)
                let (_, source) = SoundManager.loadData(for: sound, in: Bundle(for: DeskDragViewModel.self))
                XCTAssertEqual(source, .bundleFile("\(sound.rawValue).wav"), "\(spec.imageName)")
            }
        }
    }

    @MainActor
    func testEveryMaterialHasItsOwnSnap() {
        let sounds = ItemMaterial.allCases.map(SoundManager.Sound.snap(for:))
        XCTAssertEqual(Set(sounds).count, ItemMaterial.allCases.count)
    }
}
