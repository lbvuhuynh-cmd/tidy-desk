import XCTest
import SwiftUI
@testable import TidyDesk

/// Renders every device item (its real `ItemTileView`) to PNG so the art can be reviewed without playing:
/// resting, lifted (elevation 1 at the 1.08x lift size) and rotated, on the oak and walnut desk colours.
///
/// Off by default (skipped). Run on the Mac with:
///   TEST_RUNNER_TIDY_SNAPSHOTS=1 xcodebuild ... test -only-testing:TidyDeskTests/ArtPreviewTests
/// Output: <repo>/screenshots/art/<imageName>.png (+ contact sheet _all_light.png / _all_dark.png). See MAC_BUILD.md.
@MainActor
final class ArtPreviewTests: XCTestCase {
    private let cell: CGFloat = 60   // a typical iPhone cell size

    func testRenderArtPreviews() throws {
        guard ProcessInfo.processInfo.environment["TIDY_SNAPSHOTS"] != nil else {
            throw XCTSkip("Set TEST_RUNNER_TIDY_SNAPSHOTS=1 to render art previews")
        }
        let outDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("screenshots/art", isDirectory: true)
        try? FileManager.default.removeItem(at: outDir)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        ItemArt.clearCache()
        let items = uniqueItems()
        XCTAssertFalse(items.isEmpty)

        for item in items {
            let row = previewRow(item).environment(\.colorScheme, .light)
            try write(row, to: outDir.appendingPathComponent("\(item.imageName).png"))
        }
        for scheme in [ColorScheme.light, .dark] {
            // Two columns: a single column of every item is ~9500 px tall at 2x, past the renderer's
            // texture limit (~8192 px), and comes out blank.
            let half = (items.count + 1) / 2
            let columns = [Array(items[..<half]), Array(items[half...])]
            let sheet = HStack(alignment: .top, spacing: 24) {
                ForEach(columns.indices, id: \.self) { c in
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(columns[c], id: \.imageName) { self.previewRow($0) }
                    }
                }
            }
            .padding(16)
            .background(Theme.background)
            .environment(\.colorScheme, scheme)
            try write(sheet, to: outDir.appendingPathComponent(scheme == .light ? "_all_light.png" : "_all_dark.png"))
        }
        print("ArtPreviewTests: wrote \(items.count) previews to \(outDir.path)")
    }

    /// One item per distinct imageName across all levels.
    private func uniqueItems() -> [TechItem] {
        let manager = LevelManager(bundle: .main)
        var seen = Set<String>()
        var result: [TechItem] = []
        for level in manager.availableLevels {
            for spec in level.items where seen.insert(spec.imageName).inserted {
                result.append(TechItem(key: spec.id, name: spec.name, widthInGrid: spec.gridWidth,
                                       heightInGrid: spec.gridHeight, imageName: spec.imageName,
                                       symbolName: spec.symbol, category: spec.category ?? .peripheral))
            }
        }
        return result.sorted { $0.imageName < $1.imageName }
    }

    /// name | resting | lifted | rotated, each on a desk-coloured patch with the cell grid drawn.
    private func previewRow(_ item: TechItem) -> some View {
        var rotated = item
        if !item.isSquare { rotated.rotate() }
        let art = ItemArt.resolve(for: item)
        return HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.imageName).font(.system(size: 13, weight: .semibold, design: .monospaced))
                Text("\(item.widthInGrid)x\(item.heightInGrid) · \(art.isAsset ? "ASSET" : "fallback")")
                    .font(.system(size: 11)).foregroundStyle(art.isAsset ? Color.green : Color.secondary)
            }
            .frame(width: 170, alignment: .leading)
            desk(item, elevation: 0, scale: 1)
            desk(item, elevation: 1, scale: 1.08)
            if !item.isSquare { desk(rotated, elevation: 0, scale: 1) }
        }
    }

    private func desk(_ item: TechItem, elevation: CGFloat, scale: CGFloat) -> some View {
        let w = CGFloat(item.gridWidth) * cell, h = CGFloat(item.gridHeight) * cell
        return ZStack {
            Path { p in
                for c in 0...item.gridWidth { p.move(to: CGPoint(x: CGFloat(c) * cell, y: 0)); p.addLine(to: CGPoint(x: CGFloat(c) * cell, y: h)) }
                for r in 0...item.gridHeight { p.move(to: CGPoint(x: 0, y: CGFloat(r) * cell)); p.addLine(to: CGPoint(x: w, y: CGFloat(r) * cell)) }
            }
            .stroke(Theme.deskEdge.opacity(0.6), lineWidth: 1)
            // Lifted: drawn at the 1.08x size like FloatingTile, overhanging its cells.
            ItemTileView(item: item, cellSize: cell * scale, elevation: elevation)
        }
        .frame(width: w, height: h)
        .padding(12)
        .background(Theme.desk, in: RoundedRectangle(cornerRadius: 10))
    }

    private func write(_ view: some View, to url: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "ImageRenderer returned nil for \(url.lastPathComponent)")
        try XCTUnwrap(image.pngData()).write(to: url)
    }
}
