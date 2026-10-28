import SwiftUI

// 16x16 hand-designed pixel sprites. "." = transparent.
// Retro pet + modern pastel palette.

struct SpriteGrid {
    static let size = 16
    let cells: [[Character]]   // [y][x]

    func at(_ x: Int, _ y: Int) -> Character {
        guard x >= 0, x < Self.size, y >= 0, y < Self.size else { return "." }
        return cells[y][x]
    }
}

struct RGBA { let r: Double; let g: Double; let b: Double }

enum Pal {
    static let rgba: [Character: RGBA] = [
        "K": RGBA(r: 0.20, g: 0.19, b: 0.26),   // outline plum
        "B": RGBA(r: 0.62, g: 0.87, b: 0.74),    // mint body
        "S": RGBA(r: 0.44, g: 0.71, b: 0.58),    // mint shade
        "W": RGBA(r: 1.00, g: 0.96, b: 0.88),    // cream white
        "E": RGBA(r: 0.15, g: 0.14, b: 0.20),    // eyes / dark
        "P": RGBA(r: 1.00, g: 0.66, b: 0.72),    // blush
        "Y": RGBA(r: 1.00, g: 0.85, b: 0.49),    // yellow accents / glow
        "R": RGBA(r: 1.00, g: 0.56, b: 0.67),    // hearts / flowers
        "G": RGBA(r: 0.93, g: 0.95, b: 1.00),    // ghost body
        "D": RGBA(r: 0.79, g: 0.84, b: 0.96),    // ghost shade
        "T": RGBA(r: 0.78, g: 0.80, b: 0.84),    // tombstone
        "N": RGBA(r: 0.48, g: 0.78, b: 0.31),    // grass
        "O": RGBA(r: 0.98, g: 0.97, b: 0.93),    // egg shell
        "M": RGBA(r: 0.84, g: 0.55, b: 0.35),   // meat / brown
        "A": RGBA(r: 0.47, g: 0.72, b: 0.98),   // water
    ]
    static let fallback = RGBA(r: 1, g: 0, b: 1)
    static func color(_ c: Character) -> Color {
        let a = rgba[c] ?? fallback
        return Color(red: a.r, green: a.g, blue: a.b)
    }
    static func nsColor(_ c: Character) -> NSColor {
        let a = rgba[c] ?? fallback
        return NSColor(red: a.r, green: a.g, blue: a.b, alpha: 1)
    }
    static func cgColor(_ c: Character) -> CGColor {
        let a = rgba[c] ?? fallback
        return CGColor(srgbRed: a.r, green: a.g, blue: a.b, alpha: 1)
    }
}

enum Frame: String, CaseIterable {
    case idleA, blink, walkA, walkB, happyA, happyB, sadA, sadB
    case sleepA, sleepB, eatA, eatB
    case ghost, tomb, egg, eggCrack, food, heart
    case drumstick, zz, sparkle
    case lick, chompA, chompB
    case standA, standB, walkLegsA, walkLegsB, dangleA, dangleB
    case lookL, lookR, smug, standLookL, standLookR, standSmug
    case strainA, strainB, poop
    case stand2A, stand2B, wave2, cool2
    case walkLegs2A, walkLegs2B, dangle2A, dangle2B
    case swimA, swimB, pool
    // Play tricks:
    case spinA, spinB, saltoA, saltoB, zoomA, zoomB
}

enum Sprites {
    private final class Builder {
        var cells: [[Character]] = Array(
            repeating: Array(repeating: Character("."), count: SpriteGrid.size),
            count: SpriteGrid.size
        )
        func p(_ x: Int, _ y: Int, _ c: Character) {
            guard x >= 0, x < SpriteGrid.size, y >= 0, y < SpriteGrid.size else { return }
            cells[y][x] = c
        }
        func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: Character) {
            for dy in 0..<h { for dx in 0..<w { p(x + dx, y + dy, c) } }
        }
        func finish() -> SpriteGrid { SpriteGrid(cells: cells) }
    }

    // MARK: parts

    private static func ear(_ b: Builder, _ x0: Int, _ inner: Character, _ dy: Int) {
        b.rect(x0, 2 + dy, 3, 1, "K")
        b.p(x0, 3 + dy, "K"); b.p(x0 + 1, 3 + dy, inner); b.p(x0 + 2, 3 + dy, "K")
        b.p(x0, 4 + dy, "K"); b.p(x0 + 1, 4 + dy, inner); b.p(x0 + 2, 4 + dy, "K")
    }

    // Rounded 10x10 blob body with cat ears. dy shifts it up (legs need rows).
    private static func body(_ b: Builder, skin: Character, earL: Int, earR: Int,
                             belly: Bool, blush: Bool, feet: Character, dy: Int = 0) {
        ear(b, earL, skin, dy)
        ear(b, earR, skin, dy)
        b.rect(4, 5 + dy, 8, 1, "K")          // top outline
        b.rect(3, 6 + dy, 1, 8, "K")          // left outline
        b.rect(12, 6 + dy, 1, 8, "K")          // right outline
        b.rect(4, 14 + dy, 8, 1, "K")          // bottom outline
        b.rect(4, 6 + dy, 8, 8, skin)          // fill
        if belly { b.rect(5, 10 + dy, 4, 3, "W") }
        b.rect(4, 13 + dy, 2, 1, feet)         // feet shade
        b.rect(10, 13 + dy, 2, 1, feet)
        if blush { b.p(4, 9 + dy, "P"); b.p(11, 9 + dy, "P") }
    }

    private static func eyes(_ b: Builder, open: Bool, _ dy: Int = 0, look: Int = 0) {
        let lx = 5 + look, rx = 9 + look
        if open {
            b.rect(lx, 7 + dy, 2, 2, "E"); b.rect(rx, 7 + dy, 2, 2, "E")
        } else {
            b.rect(lx, 8 + dy, 2, 1, "E"); b.rect(rx, 8 + dy, 2, 1, "E")
        }
    }

    /// The friendly little :3 mouth — resting default, so it never looks sad.
    private static func smile(_ b: Builder, _ dy: Int = 0) {
        b.rect(7, 9 + dy, 2, 1, "K")
        b.p(6, 10 + dy, "K"); b.p(9, 10 + dy, "K")
    }

    private static func eggShell(_ b: Builder) {
        b.rect(5, 4, 6, 1, "K")
        b.rect(4, 5, 1, 9, "K")
        b.rect(11, 5, 1, 9, "K")
        b.rect(5, 14, 6, 1, "K")
        b.rect(5, 5, 6, 9, "O")
        b.rect(6, 7, 2, 2, "Y")
        b.p(9, 10, "Y"); b.p(10, 11, "Y")
    }

    // Legged body: sits 2 rows higher so legs fit underneath.
    private static func legBody(_ b: Builder, earL: Int = 4) {
        body(b, skin: "B", earL: earL, earR: 9, belly: true, blush: true, feet: "S", dy: -2)
    }

    private static func legs(_ b: Builder, pawLX: Int, pawRX: Int,
                             liftL: Bool = false, liftR: Bool = false) {
        b.rect(4, 13, 2, 2, "S")
        b.rect(10, 13, 2, 2, "S")
        b.rect(3, 13, 1, 3, "K")
        b.rect(12, 13, 1, 3, "K")
        if liftL { b.rect(pawLX, 14, 2, 1, "W") } else { b.rect(pawLX, 15, 2, 1, "W") }
        if liftR { b.rect(pawRX, 14, 2, 1, "W") } else { b.rect(pawRX, 15, 2, 1, "W") }
    }

    /// Stubby little arms (evolution stage 2+), beside the legged body.
    private static func arms(_ b: Builder, _ dy: Int) {
        b.rect(1, 9 + dy, 1, 3, "K")     // left arm outline
        b.rect(2, 9 + dy, 1, 3, "S")     // left arm
        b.rect(13, 9 + dy, 1, 3, "S")    // right arm
        b.rect(14, 9 + dy, 1, 3, "K")     // right arm outline
        b.p(2, 11 + dy, "W")             // paw
        b.p(13, 11 + dy, "W")
    }

    /// One arm raised — waving hello (stage 2+).
    private static func wave(_ b: Builder) {
        b.rect(1, 3, 1, 4, "K")          // raised arm outline
        b.rect(2, 3, 1, 4, "S")
        b.rect(1, 2, 2, 1, "W")          // paw up high
        b.rect(13, 9, 1, 3, "S")          // other arm down
        b.rect(14, 9, 1, 3, "K")
        b.p(13, 11, "W")
    }

    /// Sunglasses (stage 3: the gadget) over the eyes.
    private static func shades(_ b: Builder, _ dy: Int) {
        b.rect(4, 5 + dy, 8, 2, "K")
        b.p(5, 5 + dy, "Y")             // shine
        b.p(10, 5 + dy, "Y")
    }

    /// The pool: a little pixel pond.
    private static func pond(_ b: Builder) {
        b.rect(3, 7, 10, 6, "A")                  // water
        b.rect(3, 6, 10, 1, "K")                 // rim
        b.rect(2, 7, 1, 6, "K")
        b.rect(13, 7, 1, 6, "K")
        b.rect(3, 13, 10, 1, "K")
        b.p(5, 9, "W"); b.p(9, 11, "W"); b.p(7, 12, "W")   // ripples
    }

    /// Swimming: head above the water band.
    private static func swimmer(_ b: Builder, phase: Int) {
        ear(b, 4, "B", 0)
        ear(b, 9, "B", 0)
        b.rect(4, 5, 8, 1, "K")
        b.rect(3, 6, 1, 3, "K")
        b.rect(12, 6, 1, 3, "K")
        b.rect(4, 6, 8, 3, "B")
        if phase == 0 {
            b.rect(5, 7, 2, 1, "E"); b.rect(9, 7, 2, 1, "E")
        } else {
            b.rect(5, 6, 2, 1, "E"); b.rect(9, 6, 2, 1, "E")
        }
        b.rect(7, 8, 2, 1, "K")          // little smile
        b.rect(2, 9, 12, 1, "K")          // water surface
        b.rect(2, 10, 12, 4, "A")
        if phase == 0 { b.p(4, 11, "W"); b.p(11, 12, "W") }
        else { b.p(6, 12, "W"); b.p(9, 11, "W") }
    }

    // MARK: frames

    static func grid(_ f: Frame) -> SpriteGrid {
        let b = Builder()
        switch f {
        // Resting default: friendly :3 face (never looks sad by default)
        case .idleA, .walkA:
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: true)
            smile(b)
        case .walkB:
            body(b, skin: "B", earL: 5, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: true)
            smile(b)
        case .blink:
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: false)
            smile(b)
        // Expression variants (randomly rotated while resting)
        case .lookL:
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: true, look: -1)
            smile(b)
        case .lookR:
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: true, look: 1)
            smile(b)
        case .smug:   // one-eye wink + :3 — very pleased with itself
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            b.rect(5, 7, 2, 2, "E")            // left eye open
            b.rect(9, 8, 2, 1, "E")            // right eye winked
            smile(b)
        case .happyA, .happyB:
            // ^ ^ content squint + :3 smile — deliberately STILL
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            b.p(5, 8, "E"); b.p(6, 7, "E")       // left ^
            b.p(9, 7, "E"); b.p(10, 8, "E")      // right ^
            b.rect(7, 9, 2, 1, "K")               // :3 smile
            b.p(6, 10, "K"); b.p(9, 10, "K")
        case .sadA, .sadB:
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: false, feet: "S")
            eyes(b, open: false)
            b.p(6, 9, "E"); b.p(9, 9, "E")
            b.p(7, 10, "E"); b.p(8, 10, "E")
            if f == .sadA { b.p(10, 10, "P") } else { b.p(10, 11, "P") }
        case .sleepA, .sleepB:
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: false)
            b.rect(7, 9, 2, 1, "E")
            // zzz — white letters + dark drop-shadow: readable on any background
            b.rect(13, 2, 3, 1, "K"); b.p(14, 3, "K"); b.rect(13, 4, 3, 1, "K")
            b.rect(12, 1, 3, 1, "W"); b.p(13, 2, "W"); b.rect(12, 3, 3, 1, "W")
            if f == .sleepB {
                b.rect(14, 5, 2, 1, "K"); b.rect(14, 7, 2, 1, "K")
                b.rect(13, 4, 3, 1, "W"); b.p(14, 5, "W"); b.rect(13, 6, 3, 1, "W")
            }
        case .eatA, .eatB:
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: true)
            if f == .eatA { b.rect(7, 9, 2, 2, "E") } else { b.rect(7, 9, 2, 1, "E") }
        case .lick:
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: true)
            b.rect(6, 9, 4, 1, "E")          // small open mouth
            b.p(6, 10, "Y")                 // tongue tip
        case .chompA:   // HUGE mouth wide open (a file is coming!)
            body(b, skin: "B", earL: 4, earR: 9, belly: false, blush: true, feet: "S")
            eyes(b, open: false)             // excited squint
            b.rect(5, 9, 6, 5, "K")          // mouth outline
            b.rect(6, 10, 4, 3, "E")         // maw
            b.rect(6, 10, 4, 1, "W")         // upper teeth
            b.rect(6, 12, 4, 1, "P")         // tongue
        case .chompB:   // huge mouth snapped shut
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: true)
            b.rect(5, 10, 6, 1, "K")         // lips pressed together
            b.rect(6, 10, 4, 1, "W")         // teeth gleam
        case .strainA, .strainB:   // pooping: squeezing
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            b.rect(5, 7, 2, 2, "E"); b.rect(9, 7, 2, 2, "E")   // eyes squeezed shut
            b.p(7, 9, "E"); b.p(8, 9, "E")                      // little o mouth
            // effort sweat drops alternate sides
            if f == .strainA { b.p(2, 6, "W"); b.p(13, 8, "W") } else { b.p(13, 6, "W"); b.p(2, 8, "W") }
        case .standA:   // legged, resting on all fours
            legBody(b)
            eyes(b, open: true, -2)
            smile(b, -2)
            legs(b, pawLX: 4, pawRX: 10)
        case .standB:   // resting, one paw lifted (cat twitch)
            legBody(b)
            eyes(b, open: true, -2)
            smile(b, -2)
            legs(b, pawLX: 4, pawRX: 10, liftR: true)
        case .standLookL:
            legBody(b)
            eyes(b, open: true, -2, look: -1)
            smile(b, -2)
            legs(b, pawLX: 4, pawRX: 10)
        case .standLookR:
            legBody(b)
            eyes(b, open: true, -2, look: 1)
            smile(b, -2)
            legs(b, pawLX: 4, pawRX: 10)
        case .standSmug:
            legBody(b)
            b.rect(5, 5, 2, 2, "E")            // left eye open
            b.rect(9, 6, 2, 1, "E")            // right eye winked
            smile(b, -2)
            legs(b, pawLX: 4, pawRX: 10)
        case .walkLegsA:   // trot: paws apart
            legBody(b)
            eyes(b, open: true, -2)
            smile(b, -2)
            legs(b, pawLX: 5, pawRX: 9)
        case .walkLegsB:   // trot: paws together, ear flick
            legBody(b, earL: 5)
            eyes(b, open: true, -2)
            smile(b, -2)
            legs(b, pawLX: 4, pawRX: 10)
        case .dangleA:   // picked up: legs splayed out mid-kick
            legBody(b)
            eyes(b, open: true, -2)
            b.rect(3, 13, 2, 3, "S"); b.rect(11, 13, 2, 3, "S")
            b.rect(2, 13, 1, 3, "K"); b.rect(13, 13, 1, 3, "K")
            b.rect(3, 15, 2, 1, "W"); b.rect(11, 15, 2, 1, "W")
        case .dangleB:   // picked up: legs together
            legBody(b)
            eyes(b, open: true, -2)
            b.rect(5, 13, 2, 3, "S"); b.rect(9, 13, 2, 3, "S")
            b.rect(4, 13, 1, 3, "K"); b.rect(11, 13, 1, 3, "K")
            b.rect(5, 15, 2, 1, "W"); b.rect(9, 15, 2, 1, "W")
        case .poop:   // little pile (soft-serve style)
            b.p(7, 12, "K"); b.p(8, 12, "M"); b.p(9, 12, "K")
            b.rect(6, 13, 1, 1, "K"); b.rect(7, 13, 3, 1, "M"); b.p(10, 13, "K")
            b.p(5, 14, "K"); b.rect(6, 14, 5, 1, "M"); b.p(11, 14, "K")
            b.rect(5, 15, 7, 1, "K")
            b.p(7, 13, "W")            // tiny shine
        case .stand2A:   // legs + ARMS (evolution stage 2+)
            legBody(b)
            arms(b, 0)
            eyes(b, open: true, -2)
            smile(b, -2)
            legs(b, pawLX: 4, pawRX: 10)
        case .stand2B:
            legBody(b)
            arms(b, 0)
            eyes(b, open: true, -2)
            smile(b, -2)
            legs(b, pawLX: 4, pawRX: 10, liftR: true)
        case .wave2:   // waving hello
            legBody(b)
            wave(b)
            eyes(b, open: true, -2)
            smile(b, -2)
            legs(b, pawLX: 4, pawRX: 10)
        case .cool2:   // gadget stage: shades, too cool to move
            legBody(b)
            arms(b, 0)
            shades(b, -2)
            b.rect(7, 7, 2, 1, "K")           // smug little mouth
            legs(b, pawLX: 4, pawRX: 10)
        case .walkLegs2A:
            legBody(b)
            arms(b, 0)
            eyes(b, open: true, -2)
            smile(b, -2)
            legs(b, pawLX: 5, pawRX: 9)
        case .walkLegs2B:
            legBody(b, earL: 5)
            arms(b, 0)
            eyes(b, open: true, -2)
            smile(b, -2)
            legs(b, pawLX: 4, pawRX: 10)
        case .dangle2A:   // picked up: kicks legs, flails arms
            legBody(b)
            arms(b, -1)
            eyes(b, open: true, -2)
            b.rect(3, 13, 2, 3, "S"); b.rect(11, 13, 2, 3, "S")
            b.rect(2, 13, 1, 3, "K"); b.rect(13, 13, 1, 3, "K")
            b.rect(3, 15, 2, 1, "W"); b.rect(11, 15, 2, 1, "W")
        case .dangle2B:
            legBody(b)
            b.rect(5, 13, 2, 3, "S"); b.rect(9, 13, 2, 3, "S")
            b.rect(4, 13, 1, 3, "K"); b.rect(11, 13, 1, 3, "K")
            b.rect(1, 8, 1, 3, "K"); b.rect(2, 8, 1, 3, "S")   // arms up!
            b.rect(13, 8, 1, 3, "S"); b.rect(14, 8, 1, 3, "K")
            b.p(2, 7, "W"); b.p(13, 7, "W")
            b.rect(5, 15, 2, 1, "W"); b.rect(9, 15, 2, 1, "W")
            eyes(b, open: true, -2)
        case .swimA:
            swimmer(b, phase: 0)
        case .swimB:
            swimmer(b, phase: 1)
        case .pool:
            pond(b)
        case .ghost:
            body(b, skin: "G", earL: 4, earR: 9, belly: true, blush: false, feet: "D")
            b.p(5, 7, "E"); b.p(6, 8, "E"); b.p(6, 7, "E"); b.p(5, 8, "E")   // X eyes
            b.p(9, 7, "E"); b.p(10, 8, "E"); b.p(10, 7, "E"); b.p(9, 8, "E")
            b.rect(7, 9, 2, 2, "E")   // little o mouth
            b.rect(7, 1, 2, 1, "Y")   // halo
        case .tomb:
            b.rect(5, 6, 6, 1, "K")
            b.p(4, 7, "K"); b.p(11, 7, "K")
            b.rect(4, 8, 1, 5, "K")
            b.rect(11, 8, 1, 5, "K")
            b.rect(5, 13, 6, 1, "K")
            b.rect(5, 7, 6, 6, "T")
            b.p(7, 8, "K"); b.p(7, 9, "K"); b.p(7, 10, "K")   // carved cross
            b.p(6, 9, "K"); b.p(8, 9, "K")
            b.rect(3, 15, 3, 1, "N"); b.rect(9, 15, 3, 1, "N")  // grass
            b.p(2, 14, "N"); b.p(13, 14, "N")
            b.p(2, 13, "R"); b.p(13, 13, "R")                  // flowers
        case .egg:
            eggShell(b)
        case .eggCrack:
            eggShell(b)
            b.p(5, 7, "K"); b.p(6, 8, "K"); b.p(7, 7, "K")
            b.p(8, 8, "K"); b.p(9, 7, "K"); b.p(10, 8, "K")
        case .food:   // onigiri
            b.p(7, 5, "K"); b.p(8, 5, "K")
            b.rect(6, 6, 1, 1, "K"); b.rect(7, 6, 2, 1, "W"); b.p(9, 6, "K")
            b.rect(5, 7, 1, 3, "K"); b.rect(10, 7, 1, 3, "K")
            b.rect(6, 7, 4, 3, "W")
            b.rect(6, 9, 4, 1, "E")   // nori band
            b.rect(6, 10, 4, 1, "K")  // bottom outline
        case .heart:
            b.p(5, 5, "R"); b.p(6, 5, "R"); b.p(8, 5, "R"); b.p(9, 5, "R")
            b.rect(4, 6, 7, 2, "R")
            b.rect(5, 8, 5, 1, "R")
            b.rect(6, 9, 3, 1, "R")
            b.p(7, 10, "R")
            b.p(5, 6, "W")            // shine
        case .drumstick:   // need pod: hunger
            b.rect(5, 3, 5, 1, "K")
            b.rect(4, 4, 1, 5, "K")
            b.rect(10, 4, 1, 4, "K")
            b.rect(5, 8, 5, 1, "K")
            b.rect(5, 4, 5, 4, "M")
            b.p(6, 4, "W")
            b.p(9, 9, "W")
            b.p(10, 9, "K")
            b.p(10, 10, "W"); b.p(11, 10, "K")
            b.p(11, 11, "W"); b.p(12, 11, "K")
            b.p(12, 12, "W"); b.p(11, 12, "W"); b.p(12, 13, "W")
        case .zz:   // need pod: energy
            b.rect(3, 3, 6, 1, "W")
            b.p(7, 4, "W"); b.p(6, 5, "W"); b.p(5, 6, "W"); b.p(4, 7, "W")
            b.rect(3, 8, 6, 1, "W")
            b.rect(9, 10, 4, 1, "W")
            b.p(12, 11, "W"); b.p(11, 12, "W")
            b.rect(9, 13, 4, 1, "W")
        case .sparkle:
            b.rect(7, 5, 2, 1, "W")
            b.rect(7, 9, 2, 1, "W")
            b.rect(5, 7, 2, 1, "W")
            b.rect(9, 7, 2, 1, "W")
            b.rect(7, 7, 2, 2, "Y")
        case .spinA:   // play: spin (dizzy squint)
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: false)
            smile(b)
        case .spinB:
            body(b, skin: "B", earL: 5, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: true)
            smile(b)
        case .saltoA:   // play: salto (arms flail, mid-flight mouth)
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: true)
            b.rect(7, 9, 2, 1, "K")
            b.p(6, 10, "K"); b.p(9, 10, "K")
        case .saltoB:
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: true, look: 1)
            smile(b)
        case .zoomA:   // play: zoom (big confident stretch)
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: true)
            smile(b)
        case .zoomB:
            body(b, skin: "B", earL: 4, earR: 9, belly: true, blush: true, feet: "S")
            eyes(b, open: false)
            smile(b)
        }
        return b.finish()
    }

    static func ascii(_ f: Frame) -> String {
        let g = grid(f)
        return g.cells.map { row in row.map { String($0) }.joined() }.joined(separator: "\n")
    }
}