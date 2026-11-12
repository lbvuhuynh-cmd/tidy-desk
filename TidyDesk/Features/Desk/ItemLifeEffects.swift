import SwiftUI

/// "It came alive" effects for items sitting on the desk (see `ItemLife`): steam over the coffee, a warm pool of
/// lamp light, screens waking up with a cool glow, keyboard underglow, speaker rings, blinking status LEDs and a
/// gently swaying plant.
///
/// Drawn in two layers by `DeskSurfaceView` so light spills *under* neighbouring items and steam floats *over* them:
/// * `.under`: glows on the wood (lamp, screen, underglow);
/// * `.over`: steam, sound rings, status LED.
/// The plant sway is applied to the item itself (`ItemSwayEffect`).
///
/// Effects fade in shortly after the item lands (in time with the power-on blip), get a little brighter when the
/// whole desk is complete (`boost`), switch off while the item is being dragged, and respect Reduce Motion
/// (glows stay, nothing moves).
struct ItemLifeView: View {
    enum Layer { case under, over }

    let item: TechItem
    let layer: Layer
    let cellSize: CGFloat
    /// On the desk and not being dragged.
    let isAwake: Bool
    /// Desk complete: the "after" moment.
    let boost: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var power: Double = 0     // 0 = off, 1 = on (fades in)
    @State private var flash: Double = 0     // screen "turn on" flicker

    private var life: ItemLife { item.traits.life }
    private var size: CGSize {
        CGSize(width: CGFloat(item.gridWidth) * cellSize, height: CGFloat(item.gridHeight) * cellSize)
    }
    private var level: Double { power * (boost ? 1 : 0.72) }

    var body: some View {
        Group {
            switch layer {
            case .under: underLayer
            case .over: overLayer
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.6), value: boost)
        .task(id: isAwake) {
            guard isAwake else {
                withAnimation(.easeOut(duration: 0.15)) { power = 0 }
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(200))       // after the landing bounce
                withAnimation(.easeOut(duration: 0.12)) { flash = 1 }
                withAnimation(.easeOut(duration: 0.5)) { power = 1 }
                try await Task.sleep(for: .milliseconds(140))
                withAnimation(.easeOut(duration: 0.4)) { flash = 0 }
            } catch {}
        }
    }

    // MARK: Under the items (light on the wood)

    @ViewBuilder
    private var underLayer: some View {
        let glowBoost = colorScheme == .dark ? 1.25 : 1.0
        switch life {
        case .warmLight:
            let reach = max(size.width, size.height) / 2 + cellSize * 1.7
            RadialGradient(colors: [Self.warm.opacity(0.62), Self.warm.opacity(0.22), Self.warm.opacity(0)],
                           center: .center, startRadius: 0, endRadius: reach)
                .frame(width: reach * 2, height: reach * 2)
                .opacity(level * glowBoost)
                .blendMode(colorScheme == .dark ? .plusLighter : .normal)

        case .screenGlow:
            RoundedRectangle(cornerRadius: cellSize * 0.3, style: .continuous)
                .fill(Self.screen)
                .frame(width: size.width + cellSize * 0.5, height: size.height + cellSize * 0.5)
                .blur(radius: cellSize * 0.32)
                .opacity((level * 0.55 + flash * 0.45) * glowBoost)

        case .underglow:
            breathing(period: 6) { phase in
                RoundedRectangle(cornerRadius: cellSize * 0.3, style: .continuous)
                    .fill(AngularGradient(colors: Theme.led, center: .center))
                    .hueRotation(.degrees(phase * 360))
                    .frame(width: size.width + cellSize * 0.2, height: size.height + cellSize * 0.25)
                    .offset(y: cellSize * 0.06)
                    .blur(radius: cellSize * 0.25)
                    .opacity(level * 0.6 * glowBoost)
            }

        default:
            EmptyView()
        }
    }

    // MARK: Over the items

    @ViewBuilder
    private var overLayer: some View {
        switch life {
        case .steam:
            breathing(period: 2.4) { phase in
                Canvas { context, canvas in
                    Self.drawSteam(in: &context, size: canvas, phase: phase, cell: cellSize)
                }
                .frame(width: cellSize * 0.8, height: cellSize * 1.05)
                .offset(y: -cellSize * 0.42)          // rises from the cup and out over the top edge
                .opacity(level)
            }

        case .soundWaves:
            breathing(period: 1.8) { phase in
                Canvas { context, canvas in
                    let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                    for ring in 0..<2 {
                        let p = (phase + Double(ring) * 0.5).truncatingRemainder(dividingBy: 1)
                        // Rings grow outward from the speaker's own outline.
                        let grow = CGFloat(p) * cellSize * 0.9
                        let rx = size.width * 0.42 + grow, ry = size.height * 0.42 + grow
                        let rect = CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2)
                        context.stroke(Path(roundedRect: rect, cornerRadius: min(rx, ry) * 0.6), with: .color(Theme.led[2].opacity((1 - p) * 0.5)),
                                       lineWidth: max(1.5, cellSize * 0.04))
                    }
                }
                .frame(width: size.width + cellSize * 2, height: size.height + cellSize * 2)
                .opacity(level)
            }

        case .statusLED:
            breathing(period: 1.6) { phase in
                let on = reduceMotion || phase < 0.72
                let dot = max(4, cellSize * 0.1)
                Circle()
                    .fill(Self.ledColor(for: item))
                    .frame(width: dot, height: dot)
                    .shadow(color: Self.ledColor(for: item).opacity(0.9), radius: dot * 0.9)
                    .opacity(level * (on ? 1 : 0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(cellSize * 0.2)
            }

        default:
            EmptyView()
        }
    }

    /// Repeating 0→1 phase for looping effects; frozen at a pleasant midpoint with Reduce Motion
    /// and while switched off (no work for idle items).
    private func breathing<V: View>(period: Double, @ViewBuilder _ content: @escaping (Double) -> V) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || power == 0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            content(reduceMotion ? 0.35 : (t / period).truncatingRemainder(dividingBy: 1))
        }
    }

    // MARK: Drawing helpers

    static let warm = Color(red: 1.0, green: 0.82, blue: 0.5)
    static let screen = Color(red: 0.55, green: 0.76, blue: 1.0)

    static func ledColor(for item: TechItem) -> Color {
        let name = item.imageName
        if name.contains("mic") || name.contains("webcam") { return Color(red: 1, green: 0.35, blue: 0.35) }  // "on air"
        if name.contains("controller") { return Color(red: 0.45, green: 0.65, blue: 1) }
        return Color(red: 0.35, green: 0.9, blue: 0.55)
    }

    /// Three soft wavy wisps rising and fading, staggered in time.
    static func drawSteam(in context: inout GraphicsContext, size: CGSize, phase: Double, cell: CGFloat) {
        for wisp in 0..<3 {
            let p = (phase + Double(wisp) / 3).truncatingRemainder(dividingBy: 1)
            let alpha = sin(p * .pi) * 0.75
            let baseX = size.width * (0.32 + 0.18 * CGFloat(wisp))
            let bottom = size.height * (1 - CGFloat(p) * 0.75)
            let length = size.height * 0.3
            let sway = CGFloat(sin((p * 2 + Double(wisp)) * .pi)) * size.width * 0.08
            var path = Path()
            path.move(to: CGPoint(x: baseX + sway, y: bottom))
            path.addCurve(to: CGPoint(x: baseX - sway, y: bottom - length),
                          control1: CGPoint(x: baseX + sway + size.width * 0.12, y: bottom - length * 0.35),
                          control2: CGPoint(x: baseX - sway - size.width * 0.12, y: bottom - length * 0.65))
            context.stroke(path, with: .color(.white.opacity(alpha)),
                           style: StrokeStyle(lineWidth: max(1.5, cell * 0.055), lineCap: .round))
        }
    }
}

/// Plants sway a couple of degrees, like there's a breeze from the window. Applied to the item itself.
struct ItemSwayEffect: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isActive && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                content.rotationEffect(.degrees(sin(t * 2 * .pi / 3.4) * 2.2), anchor: .bottom)
            }
        } else {
            content
        }
    }
}

/// Level-clear "before/after": a band of warm light sweeps diagonally across the desk once.
struct LightSweepEffect: ViewModifier {
    let isCleared: Bool
    var cornerRadius: CGFloat = 0
    @State private var progress: CGFloat = -1

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                LinearGradient(colors: [.white.opacity(0), ItemLifeView.warm.opacity(0.55), .white.opacity(0.7),
                                        ItemLifeView.warm.opacity(0.55), .white.opacity(0)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: w * 0.45, height: (w + h) * 1.5)
                    .rotationEffect(.degrees(22))
                    .position(x: w / 2 + progress * (w * 0.75 + h * 0.4), y: h / 2)
                    .blendMode(.plusLighter)
                    .opacity(progress > -1 && progress < 1 ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .allowsHitTesting(false)
        }
        .task(id: isCleared) {
            progress = -1
            guard isCleared else { return }
            do {
                try await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeInOut(duration: 1.0)) { progress = 1 }
            } catch {}
        }
    }
}
