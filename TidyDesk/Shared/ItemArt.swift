import SwiftUI
import UIKit

/// Which picture an item gets, resolved once per name and cached.
///
/// Fallback chain (the app never crashes and never shows an empty "?" image):
/// 1. `.asset`: the top-down vector art `imageName` exists in Assets.xcassets;
/// 2. `.symbol`: the item's own SF Symbol (`symbol` in the level JSON), else its category's default symbol;
/// 3. `.plain`: just the coloured category tile.
enum ItemArt: Equatable {
    case asset(String)
    case symbol(String)
    case plain

    var isAsset: Bool {
        if case .asset = self { return true }
        return false
    }

    @MainActor private static var cache: [String: ItemArt] = [:]

    @MainActor
    static func resolve(for item: TechItem) -> ItemArt {
        resolve(imageName: item.imageName, symbol: item.symbolName, category: item.category)
    }

    @MainActor
    static func resolve(imageName: String, symbol: String?, category: ItemCategory, bundle: Bundle = .main) -> ItemArt {
        let key = "\(imageName)|\(symbol ?? "")|\(category.rawValue)"
        if let cached = cache[key] { return cached }

        let art: ItemArt
        if !imageName.isEmpty, UIImage(named: imageName, in: bundle, with: nil) != nil {
            art = .asset(imageName)
        } else if let s = [symbol, category.defaultSymbol].compactMap({ $0 }).first(where: { UIImage(systemName: $0) != nil }) {
            art = .symbol(s)
            #if DEBUG
            print("🖼️ [ItemArt] asset '\(imageName)' not in Assets.xcassets yet, showing SF Symbol '\(s)'")
            #endif
        } else {
            art = .plain
        }
        cache[key] = art
        return art
    }

    /// Tests / asset hot-swaps.
    @MainActor static func clearCache() { cache = [:] }
}

/// Draws an `ItemArt` scaled to fit the proposed frame, keeping its aspect ratio.
struct ItemArtworkView: View {
    let art: ItemArt
    /// Colour for SF Symbol fallbacks (vector assets keep their own colours).
    var symbolTint: Color = .white.opacity(0.95)

    var body: some View {
        switch art {
        case .asset(let name):
            Image(name)
                .resizable()
                .interpolation(.high)   // smooth when an asset is raster (PNG); vectors are re-rendered anyway
                .antialiased(true)
                .scaledToFit()
        case .symbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .fontWeight(.medium)
                .foregroundStyle(symbolTint)
        case .plain:
            Color.clear
        }
    }
}
