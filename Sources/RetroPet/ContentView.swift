import SwiftUI
import AppKit

func ageString(_ s: Double) -> String {
    let h = s / 3600
    if h >= 24 { return "\(Int(h / 24))d" }
    if h >= 1 { return "\(Int(h))h" }
    return "\(Int(s / 60))m"
}

extension PetEngine {
    var eatActive: Bool { eatUntil.map { now < $0 } ?? false }
    var glowActive: Bool { glowUntil.map { now < $0 } ?? false }
}

/// One crisp pixel-sprite (vector-rect per pixel -> sharp at any scale).
/// `tint` overrides the palette (glow silhouette); `overrides` per-color.
struct PixelSpriteView: View {
    let frame: Frame
    let scale: CGFloat
    var tint: Color? = nil
    var overrides: [Character: Color] = [:]   // breed colors

    var body: some View {
        Canvas { ctx, size in
            let g = Sprites.grid(frame)
            let cell = size.width / CGFloat(SpriteGrid.size)
            for y in 0..<SpriteGrid.size {
                for x in 0..<SpriteGrid.size {
                    let ch = g.at(x, y)
                    guard ch != "." else { continue }
                    let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell,
                                      width: cell + 0.6, height: cell + 0.6)
                    ctx.fill(Path(rect), with: .color(tint ?? overrides[ch] ?? Pal.color(ch)))
                }
            }
        }
        .frame(width: CGFloat(SpriteGrid.size) * scale,
               height: CGFloat(SpriteGrid.size) * scale)
    }
}

// MARK: - Native, flicker-free dragging (screen-space deltas)

/// Right-click anywhere on the panel (background layer) opens the settings menu.
struct PanelRightClickArea: NSViewRepresentable {
    var onRightClick: () -> Void

    func makeNSView(context: Context) -> RightClickView { RightClickView() }
    func updateNSView(_ v: RightClickView, context: Context) { v.onRightClick = onRightClick }
}

final class RightClickView: NSView {
    var onRightClick: (() -> Void)?
    override func rightMouseDown(with event: NSEvent) { onRightClick?() }
}

/// Left-ear hot spot: click toggles the controls (in "ear" mode),
/// drag still moves the pet, right-click still opens the menu.
struct EarClickArea: NSViewRepresentable {
    var onDrag: (CGFloat, CGFloat) -> Void
    var onRelease: (_ moved: Bool) -> Void
    var onRightClick: () -> Void

    func makeNSView(context: Context) -> EarClickView { EarClickView() }
    func updateNSView(_ v: EarClickView, context: Context) {
        v.onDrag = onDrag
        v.onRelease = onRelease
        v.onRightClick = onRightClick
    }
}

final class EarClickView: NSView {
    var onDrag: ((CGFloat, CGFloat) -> Void)?
    var onRelease: ((Bool) -> Void)?
    var onRightClick: (() -> Void)?

    private var last: NSPoint?
    private var travelled: CGFloat = 0

    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func mouseDown(with event: NSEvent) {
        last = NSEvent.mouseLocation
        travelled = 0
    }

    override func mouseDragged(with event: NSEvent) {
        guard let l = last else { return }
        let cur = NSEvent.mouseLocation
        let dx = cur.x - l.x, dy = cur.y - l.y
        travelled += abs(dx) + abs(dy)
        onDrag?(dx, dy)
        last = cur
    }

    override func mouseUp(with event: NSEvent) {
        onRelease?(travelled > 3)
        last = nil
    }

    override func rightMouseDown(with event: NSEvent) { onRightClick?() }
}

struct DragArea: NSViewRepresentable {
    var onDrag: (CGFloat, CGFloat) -> Void
    var onRelease: (_ moved: Bool) -> Void
    var onRightClick: () -> Void
    var activateOnClick = false     // egg: needs keyboard (H cheat) -> activate

    func makeNSView(context: Context) -> DragAreaView { DragAreaView() }
    func updateNSView(_ v: DragAreaView, context: Context) {
        v.onDrag = onDrag
        v.onRelease = onRelease
        v.onRightClick = onRightClick
        v.activateOnClick = activateOnClick
    }
}

final class DragAreaView: NSView {
    var onDrag: ((CGFloat, CGFloat) -> Void)?
    var onRelease: ((Bool) -> Void)?
    var onRightClick: (() -> Void)?
    var activateOnClick = false

    private var last: NSPoint?
    private var travelled: CGFloat = 0

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        if activateOnClick {
            NSApp.activate(ignoringOtherApps: true)   // keyboard: the H cheat
        }
        window?.makeKey()
        last = NSEvent.mouseLocation
        travelled = 0
    }

    override func mouseDragged(with event: NSEvent) {
        guard let l = last else { return }
        let cur = NSEvent.mouseLocation           // screen coords: stable while the window moves
        let dx = cur.x - l.x, dy = cur.y - l.y
        travelled += abs(dx) + abs(dy)
        onDrag?(dx, dy)
        last = cur
    }

    override func mouseUp(with event: NSEvent) {
        onRelease?(travelled > 3)                 // no-move click = pat
        last = nil
    }

    override func rightMouseDown(with event: NSEvent) { onRightClick?() }
}

// MARK: - Root

struct PetRootView: View {
    @ObservedObject var engine: PetEngine
    @ObservedObject var sound: SoundBank
    var dragDelta: (CGFloat, CGFloat) -> Void
    var settle: () -> Void
    var popMenu: () -> Void
    var onPlay: () -> Void = {}
    var moveWindow: (Double, Double) -> Void          // wander: move the panel itself

    @State private var dropHot = false
    @State private var lastT: Double = 0
    @State private var eggDetail = false   // click the egg's temp badge -> details
    @AppStorage("RetroPet.showMode") private var showMode = "hover"   // hover | ear

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            content(t: t)
                .frame(width: 280, height: 240)
                .contentShape(Rectangle())
                .onHover { engine.hover = $0 }     // whole-panel hover: controls stay
                .background(PanelRightClickArea(onRightClick: popMenu))   // right-click anywhere
                .onChange(of: t) { nt in
                    // drive the wander: the pet's window itself moves on screen
                    let dt = min(max(nt - lastT, 0), 1)
                    lastT = nt
                    guard dt > 0 else { return }
                    switch engine.stepWander(dt: dt) {
                    case .moving(let dx, let dy):
                        if dx != 0 || dy != 0 { moveWindow(dx, dy) }
                    case .ended: settle()          // episode done: remember position
                    case .idle: break
                    }
                }
        }
    }

    /// Sprite size grows with age (starts small, tops out after ~a day).
    private var scale: CGFloat { CGFloat(engine.ageScale()) * (engine.mood == .egg ? 1.5 : 1.0) }

    private func content(t: Double) -> some View {
        let mood = engine.mood
        let frame = pickFrame(mood: mood, t: t)
        return ZStack {
            if mood == .dead {
                PixelSpriteView(frame: .ghost, scale: scale)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
                DeadOverlay(engine: engine)
            } else {
                aura(mood: mood, t: t)
                    .allowsHitTesting(false)
                petView(mood: mood, frame: frame, t: t)
                if engine.eatActive && mood != .egg && mood != .hatch {
                    PixelSpriteView(frame: .food, scale: 4)
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                        .offset(x: 44, y: 12)
                        .allowsHitTesting(false)
                }
                heartsOverlay(t: t)
                poopsOverlay
                if mood == .egg && eggDetail { eggDetailCard }
                if mood != .egg && !engine.model.dead { needPods(t: t) }
                if dropHot { feedMeHint }
                let showControls = engine.controlsPinned
                    || (showMode == "ear" ? engine.earOpen : engine.hover)
                if showControls {
                    VStack {
                        Spacer()
                        ControlsBar(engine: engine, sound: sound, onSettings: popMenu, onPlay: onPlay)
                            .padding(.bottom, 6)
                    }
                    .padding(.horizontal, 10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: engine.hover)
        .animation(.easeOut(duration: 0.2), value: engine.controlsPinned)
    }

    // MARK: pet (drag / pat / drop target)

    private func petView(mood: Mood, frame: Frame, t: Double) -> some View {
        ZStack {
            PixelSpriteView(frame: frame, scale: scale, overrides: engine.breedOverrides)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
            earGlow(frame: frame, t: t)
            // retro temp display, painted directly on the egg shell
            if mood == .egg || mood == .hatch { eggTempOverlay(frame: frame) }
        }
        .scaleEffect(x: stretchX(t: t), y: stretchY(t: t))
        .offset(x: wobbleX(mood: mood, t: t),
                y: bobY(mood: mood, t: t) + jumpY(t: t))
        .overlay(
            DragArea(
                onDrag: { dx, dy in
                    engine.dragged = true          // dangling-leg wiggle while picked up
                    engine.walkUntil = nil
                    dragDelta(dx, dy)
                },
                onRelease: { moved in
                    engine.dragged = false
                    if moved { settle() }
                    else if mood == .egg { eggDetail.toggle() }   // click anywhere on the egg -> details
                    else { engine.pat() }
                },
                onRightClick: { popMenu() },
                activateOnClick: mood == .egg
            )
        )
        .overlay(alignment: .topLeading) {          // left-ear hot spot
            if mood != .egg && mood != .dead {
                EarClickArea(
                    onDrag: { dx, dy in dragDelta(dx, dy) },
                    onRelease: { moved in
                        if moved {
                            settle()
                        } else if showMode == "ear" {
                            engine.earOpen.toggle()          // click left ear: open/close controls
                        } else {
                            engine.pat()
                        }
                    },
                    onRightClick: { popMenu() }
                )
                .frame(width: 30, height: 30)
                .padding(.leading, 5.5 * scale - 15)   // tracks the left ear at any size
                .padding(.top, 3 * scale - 15)
            }
        }
        .scaleEffect(dropHot ? 1.14 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dropHot)
        .dropDestination(for: URL.self) { urls, _ in
            for u in urls { feedDropped(u) }
            dropHot = false
            return true
        } isTargeted: { dropHot = $0 }
        .dropDestination(for: String.self) { texts, _ in
            // fallback: some browsers drop tabs as plain-text URLs
            var ate = false
            for t in texts {
                if let u = URL(string: t), BrowserEater.isWebURL(u) {
                    feedDropped(u); ate = true
                }
            }
            dropHot = false
            return ate
        } isTargeted: { _ in }
        .modifier(PetPlayModifier(engine: engine))
    }

    /// Dropped a file -> eat it (trashed). Dropped a browser tab / link ->
    /// eat it AND close the matching open tab in the browser.
    private func feedDropped(_ u: URL) {
        if BrowserEater.isWebURL(u) {
            if let hit = BrowserEater.closeTab(url: u.absoluteString) {
                engine.feedTab(browser: hit.browser, title: hit.title, url: u.absoluteString)
            } else {
                // no matching tab (or no permission): still a tasty web snack
                engine.feedTab(browser: "the web", title: u.host ?? "a link", url: u.absoluteString)
            }
        } else {
            engine.feedFile(url: u)
        }
    }

    /// Soft pulsing silhouette glow while `glowUntil` lasts (fed a nice file).
    @ViewBuilder
    private func earGlow(frame: Frame, t: Double) -> some View {
        if engine.glowActive {
            let pulse = 0.3 + 0.25 * (0.5 + 0.5 * sin(t * 7))
            PixelSpriteView(frame: frame, scale: scale, tint: Pal.color("Y"))
                .blur(radius: 2.5)
                .opacity(pulse)
                .allowsHitTesting(false)
        }
    }

    // MARK: mood aura (stats you *feel*, not read)

    @ViewBuilder
    private func aura(mood: Mood, t: Double) -> some View {
        let color: Color = {
            switch mood {
            case .happy: return Pal.color("B")
            case .neutral: return Color(red: 0.55, green: 0.75, blue: 0.95)
            case .sad: return Color(red: 0.95, green: 0.6, blue: 0.45)
            case .asleep: return Pal.color("D")
            case .egg, .hatch: return Pal.color("W")
            case .dead: return Pal.color("G")
            }
        }()
        let base = 0.30 + 0.07 * sin(t * 1.8)
        Circle()
            .fill(RadialGradient(colors: [color.opacity(base), color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: 75))
            .frame(width: 150, height: 150)
            .blur(radius: 7)
    }

    // Incubation: temperature painted directly on the egg shell.
    // `frame` lets it sit over the shell; inherits the pet's wobble/bob.
    @ViewBuilder
    private func eggTempOverlay(frame: Frame) -> some View {
        let color: Color = engine.eggTemp >= 62 ? .yellow : (engine.eggTemp >= 48 ? Color(red: 1, green: 0.85, blue: 0.45) : .white)
        let plateW = max(28.0, scale * 5.0)
        let plateH = max(13.0, scale * 2.2)
        let icon = max(7.0, scale * 0.9)
        ZStack {
            Capsule().fill(Color.black.opacity(0.5))
                .frame(width: plateW, height: plateH)
                .overlay(Capsule().stroke(color.opacity(0.75), lineWidth: max(1, scale * 0.35)))
            HStack(spacing: 1) {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: icon, weight: .bold))
                    .foregroundColor(color)
                Text("\(Int(engine.eggTemp.rounded()))°")
                    .font(PixelFont.font(max(6.0, scale)))
                    .foregroundColor(color)
                    .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // sit over the shell
        .offset(y: -scale * 1.9)       // right over the shell's mid-section
        // click handled by the egg's DragArea (whole-egg)
    }

    // The details: nice glass card above the egg.
    private var eggDetailCard: some View {
        let t = engine.eggTemp
        let filled = Int(min(10, max(0, engine.eggProgressValue / PetRates.eggSeconds * 10)))
        let state = t < 32 ? "chilly" : (t < 48 ? "just right" : (t < 62 ? "warm" : "HOT"))
        return VStack(spacing: 5) {
            Text("INCUBATING")
                .font(PixelFont.font(7))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
            Text("CPU \(Int(t.rounded()))°C")
                .font(PixelFont.font(9))
                .foregroundColor(t >= 62 ? .yellow : .white)
                .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
            Text(state)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.75))
                .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < filled ? Color.white.opacity(0.85) : Color.white.opacity(0.25))
                        .frame(width: 9, height: 5)
                }
            }
            Text("a warm mac hatches it faster")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.6))
                .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.22)))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        .offset(y: -62)
        .onTapGesture { eggDetail = false }
    }

    // Need pods: a small vertical column LEFT of the pet.
    // Minimal glass dots, full color when urgent, dim otherwise.
    private func needPods(t: Double) -> some View {
        let hovering = engine.hover || engine.controlsPinned || dropHot
        let stats: [(Frame, Double)] = [
            (.drumstick, engine.model.hunger),
            (.heart, engine.model.happiness),
            (.zz, engine.model.energy),
        ]
        return VStack(spacing: 5) {
            ForEach(Array(stats.enumerated()), id: \.offset) { pair in
                let i = pair.0
                let value = pair.1.1
                let low = value < 40
                if low || hovering {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        PixelSpriteView(frame: pair.1.0, scale: 1.1)
                            .opacity(low ? 1 : 0.6)
                    }
                    .frame(width: 19, height: 19)
                    .overlay(
                        Circle().stroke(
                            low ? Color.red.opacity(0.7 + 0.3 * (0.5 + 0.5 * sin(t * 3.2 + Double(i))))
                                : Color.white.opacity(0.35),
                            lineWidth: low ? 1.4 : 0.8)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1.5)
                    .offset(y: low ? CGFloat(1.8 * sin(t * 2.4 + Double(i))) : 0)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .offset(x: -72)   // just left of the pet, any size
        .animation(.easeOut(duration: 0.25), value: hovering)
        .allowsHitTesting(false)
    }

    private var feedMeHint: some View {
        VStack {
            Spacer().frame(height: 30)
            Text("FEED ME!")
                .font(PixelFont.font(7))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    // MARK: particles

    private func heartsOverlay(t: Double) -> some View {
        ForEach(engine.particles) { p in
            let ageT = max(0, t - p.start.timeIntervalSinceReferenceDate)
            PixelSpriteView(frame: p.frame, scale: 3)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .offset(x: CGFloat(p.dx), y: -6 - CGFloat(ageT) * 16)
                .opacity(Double(1 - ageT / 1.4))
                .allowsHitTesting(false)
        }
    }

    // The toilet: a pile pops out briefly, then the file auto-restores.
    // Click it to restore immediately.
    @ViewBuilder
    private var poopsOverlay: some View {
        if let pile = engine.pile {
            PixelSpriteView(frame: .poop, scale: 3)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
                .offset(x: CGFloat(pile.dx), y: CGFloat(pile.dy))
                .onTapGesture { engine.restorePile() }
                .help("\(pile.fileName) — click to put it back now")
        }
    }

    // MARK: frames & motion

    private func pickFrame(mood: Mood, t: Double) -> Frame {
        // A file is coming: huge chomping mouth, fast cycle
        if dropHot && mood != .dead && mood != .egg && mood != .hatch {
            return Int(t * 6) % 2 == 0 ? .chompA : .chompB
        }
        let fast = Int(t * 6) % 2 == 0   // 6fps
        let p = Int(t * 4) % 2           // chunky 4fps
        // Pooping: squeeze
        if engine.poopActive && mood != .dead && mood != .egg && mood != .hatch {
            return fast ? .strainA : .strainB
        }
        // Rarely: a happy little hop (legs splayed mid-air)
        if engine.jumpActive && mood != .dead && mood != .egg && mood != .hatch {
            return fast ? .dangleA : .dangleB
        }
        // Swimming in the pool: head above water, ripples
        if engine.swimActive && mood != .dead && mood != .egg && mood != .hatch {
            return fast ? .swimA : .swimB
        }
        // Picked up: cats dangle their legs and kick a little (feet only,
        // arms stay hidden — no flailing)
        if engine.dragged && engine.hasLegs
            && mood != .dead && mood != .egg && mood != .hatch {
            return fast ? .dangleA : .dangleB
        }
        // Growth moment / wandering: excited trot
        if (engine.growActive || engine.isWalking)
            && mood != .dead && mood != .egg && mood != .hatch {
            return engine.evolution >= 2
                ? (fast ? .walkLegs2A : .walkLegs2B)
                : (fast ? .walkLegsA : .walkLegsB)
        }
        // Play tricks override mood frames
        if engine.playActive && mood != .dead && mood != .egg && mood != .hatch {
            let p = Int(t * 12) % 2
            switch engine.playMode {
            case .toss:  return p == 0 ? .happyA : .happyB
            case .spin:  return p == 0 ? .spinA : .spinB
            case .salto: return p == 0 ? .saltoA : .saltoB
            case .zoom:  return p == 0 ? .zoomA : .zoomB
            }
        }
        switch mood {
        case .egg: return engine.eggProgressValue > PetRates.eggSeconds - 60 ? .eggCrack : .egg
        case .hatch: return .happyA
        case .dead: return .ghost
        case .asleep: return p == 0 ? .sleepA : .sleepB
        case .sad: return p == 0 ? .sadA : .sadB
        case .happy: return .happyA        // still ^ ^ happy face
        case .neutral:
            if engine.eatActive { return p == 0 ? .eatA : .eatB }
            let cyc = t.truncatingRemainder(dividingBy: 6)
            if (3.2...3.6).contains(cyc) { return .blink }
            if engine.model.hunger < 40 && (1.5...2.1).contains(cyc) {
                return .lick               // hungry: licks its lips sometimes
            }
            return restFace(t: t, legged: engine.hasLegs)
        }
    }

    /// Random-but-static expression, changing every few seconds:
    /// stare / look left / look right / smug wink / wave / cool (shades).
    private func restFace(t: Double, legged: Bool) -> Frame {
        let window = Int(floor(t / 4))            // 4s expression slots
        let r = abs(sin(Double(window) * 12.9898) * 43758.5453)
            .truncatingRemainder(dividingBy: 1)   // 0..<1 pseudo-random
        let lvl = engine.evolution
        if legged {
            switch lvl {
            case 3:          // gadget: shades, waves, smug
                if r < 0.20 { return .cool2 }
                if r < 0.40 { return .wave2 }
                if r < 0.60 { return .stand2A }
                if r < 0.80 { return .stand2B }
                return .cool2
            case 2:          // arms: waves hello
                if r < 0.30 { return .wave2 }
                if r < 0.55 { return .stand2A }
                if r < 0.80 { return .stand2B }
                return .wave2
            default:         // legs only: the classic set
                if r < 0.30 { return .standA }
                if r < 0.45 { return .standLookL }
                if r < 0.60 { return .standLookR }
                if r < 0.70 { return .standSmug }
                return Int(t * 2) % 2 == 0 ? .standA : .standB
            }
        }
        if r < 0.35 { return .idleA }
        if r < 0.50 { return .lookL }
        if r < 0.65 { return .lookR }
        if r < 0.75 { return .smug }
        return .idleA
    }

    /// Horizontal stretch: chubbiness (eat too much / not playing enough)
    /// plus the growth milestone bounce.
    private func stretchX(t: Double) -> CGFloat {
        var x: CGFloat = 1 + CGFloat(engine.chubValue) / 100 * 0.18
        if engine.growBounceActive, let until = engine.growBounceUntil {
            let left = until.timeIntervalSinceReferenceDate - t
            let phase = 1 - max(0, min(1, left / 1.6))
            x *= 1 + 0.08 * CGFloat(sin(.pi * phase))
        }
        return x
    }

    /// Vertical: chubby squash + springy grow-up stretch.
    private func stretchY(t: Double) -> CGFloat {
        var y: CGFloat = 1 - CGFloat(engine.chubValue) / 100 * 0.10
        if engine.growBounceActive, let until = engine.growBounceUntil {
            let left = until.timeIntervalSinceReferenceDate - t
            let phase = 1 - max(0, min(1, left / 1.6))
            y *= 1 + 0.16 * CGFloat(sin(.pi * phase))
        }
        return y
    }

    /// Jump arc: one smooth hop up and down while `jumpActive`.
    private func jumpY(t: Double) -> CGFloat {
        guard engine.jumpActive, let until = engine.jumpUntil else { return 0 }
        let left = until.timeIntervalSinceReferenceDate - t   // time remaining
        let phase = 1 - max(0, min(1, left / PetRates.jumpSeconds))
        return -14 * CGFloat(sin(.pi * phase))
    }

    private func bobY(mood: Mood, t: Double) -> CGFloat {
        if engine.isWalking || engine.growActive {   // trotty bounce
            return Int(t * 6) % 2 == 0 ? -1 : 0
        }
        let step = Int(t * 2) % 2
        if mood == .happy { return 0 }             // still happy face
        if mood == .asleep { return 1 }
        return step == 0 ? -2 : 0
    }

    private func wobbleX(mood: Mood, t: Double) -> CGFloat {
        guard mood == .egg else { return 0 }
        return Int(t * 3) % 2 == 0 ? -2 : 2
    }
}

// MARK: - Controls (modern glass buttons)

struct ControlsBar: View {
    let engine: PetEngine
    let sound: SoundBank
    var onSettings: () -> Void = {}
    var onPlay: () -> Void = {}

    @State private var showTricks = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ctl("carrot.fill", color: .orange, tip: "Feed a snack") { engine.feed() }
                ctl("gamecontroller.fill", color: .pink, tip: "Play") { showTricks.toggle() }
                ctl("zzz", color: .indigo, tip: engine.model.asleep ? "Wake up" : "Sleep") { engine.toggleSleep() }
                Divider()
                    .frame(height: 16)
                    .overlay(Color.white.opacity(0.25))
                ctl("gearshape.fill", color: .gray, tip: "Settings") { onSettings() }
            }
            if showTricks {
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        trickBtn(mode: .toss)
                        trickBtn(mode: .spin)
                        trickBtn(mode: .salto)
                        trickBtn(mode: .zoom)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .transition(.opacity)
            }
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.18)))
    }

    private func trickBtn(mode: PlayMode) -> some View {
        ctl(mode.icon, color: .pink, tip: mode.rawValue) {
            engine.play(mode)
            showTricks = false
        }
    }

    @ViewBuilder
    private func ctl(_ icon: String, color: Color, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(IconButtonStyle(color: color))
        .help(tip)
    }
}

struct IconButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color)
            .background(Circle().fill(Color.white.opacity(configuration.isPressed ? 0.38 : 0.14)))
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
    }
}


// MARK: - Pool (gadget stage: a little pixel pond you can park anywhere)

struct PoolRootView: View {
    @ObservedObject var engine: PetEngine
    var dragDelta: (CGFloat, CGFloat) -> Void
    var settle: () -> Void
    var popMenu: () -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.4)) { tl in
            ZStack {
                PixelSpriteView(frame: .pool, scale: 6)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
                    .opacity(engine.swimActive ? 1.0 : 0.95)
                    .scaleEffect(Int(tl.date.timeIntervalSinceReferenceDate * 2) % 2 == 0 && engine.swimActive ? 1.03 : 1)
            }
            .frame(width: 110, height: 110)
            .contentShape(Rectangle())
            .overlay(
                DragArea(
                    onDrag: { dx, dy in dragDelta(dx, dy) },
                    onRelease: { moved in if moved { settle() } },
                    onRightClick: { popMenu() }
                )
            )
        }
    }
}

// MARK: - Play animation (toss / spin / salto / zoom)
struct PetPlayModifier: ViewModifier {
    let engine: PetEngine
    @ViewBuilder
    func body(content: Content) -> some View {
        let phase = engine.playPhase
        if engine.playActive, engine.playMode == .toss {
            // Toss: launch up in an arc, rotate half-turn at peak, then settle
            let yOffset = -8 * phase * (1 - phase)      // parabolic arc up then down
            let rotation = .pi * 0.5 * phase * (1 - phase)  // half-turn at apex
            content
                .offset(y: yOffset)
                .rotationEffect(.radians(rotation))
        } else if engine.playActive, engine.playMode == .spin {
            // Spin: rapid continuous spin with subtle scale wobble
            let rotations = 6 * phase                          // 6 full turns
            let wobble = 1 + 0.03 * sin(.pi * phase * 4)      // gentle scale wobble
            content.rotationEffect(.radians(.pi * 2 * rotations))
                .scaleEffect(wobble)
        } else if engine.playActive, engine.playMode == .salto {
            // Salto: full 360° front-flip illusion with squash-and-stretch
            let rotation = .pi * 2 * phase                       // full flip
            let squash = 1 - 0.15 * phase                      // compress during flip
            let stretch = 1 + 0.15 * phase                     // extend during flip
            content
                .rotationEffect(.radians(rotation))
                .scaleEffect(x: squash, y: stretch)
        } else if engine.playActive, engine.playMode == .zoom {
            // Zoom: rapid dash pulse with motion stretch
            let pulse = 1.15 - 0.15 * cos(.pi * phase)       // overshoot pulse
            let forward = 1 + 0.1 * phase                    // stretch forward
            content.scaleEffect(pulse).offset(x: 4 * phase)
        } else { content }
    }
}

// MARK: - Death (retro tombstone, pixel font RIP)

struct DeadOverlay: View {
    let engine: PetEngine

    var body: some View {
        VStack(spacing: 6) {
            Spacer()
            Text("R.I.P. \(engine.model.name.uppercased())")
                .font(PixelFont.font(9))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
            Text("your pet really died")
                .font(PixelFont.font(6))
                .foregroundColor(.white.opacity(0.75))
                .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
            Button {
                engine.newPet()
            } label: {
                Text("NEW PET")
                    .font(PixelFont.font(7))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.16)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
            }
            .buttonStyle(.plain)
            Text("a death note was left on your Desktop")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(.bottom, 10)
    }
}