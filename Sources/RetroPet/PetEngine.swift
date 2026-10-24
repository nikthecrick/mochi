import Foundation
import Combine
import SwiftUI

enum Mood { case egg, hatch, happy, neutral, sad, asleep, dead }

/// The four tricks the play menu offers. Each one animates the pet differently.
enum PlayMode: String, CaseIterable, Codable {
    case toss = "Toss"
    case spin = "Spin"
    case salto = "Salto"
    case zoom = "Zoom"
    var icon: String {
        switch self { case .toss: return "dice"; case .spin: return "arrow.heartcircle"
        case .salto: return "figure.archery"; case .zoom: return "magnifyingglass" }
    }
}

struct PoopRecord: Codable, Identifiable {
    let id = UUID()
    let fileName: String
    let url: String?      // browser-tab meals restore as .webloc links
    let dx: Double
    let dy: Double
}

struct PetModel: Codable {
    var name: String = "Mochi"
    var bornAt: Date = Date()
    var lastTick: Date = Date()
    var hunger: Double = 90        // 100 = full
    var happiness: Double = 90
    var energy: Double = 90
    var asleep: Bool = false
    var neglect: Double = 0       // seconds of neglect accrued
    var dead: Bool = false
    var diedAt: Date?
    var deathCause: String?
    var everHatched: Bool = false
    var borrowedFrom: String?     // prepared: set when a borrowed pet is imported
    var filesEaten: Int = 0
    var bytesEaten: Int64 = 0
    var legsGrown: Bool?          // optional: old saves decode without it
    var breedName: String?       // random breed (unique colors)
    var eggProgress: Double?     // seconds of incubation done
    var hatchedAt: Date?
    var armsGrown: Bool?          // stage 2
    var gadget: Bool?             // stage 3 (cool shades)
    var poolOwned: Bool?          // stage 3 gadget: the pool
    var poolX: Double = -1
    var poolY: Double = -1
    var chub: Double?             // 0...100: eating too much / not playing enough
    var lastEaten: [String]?      // file names in the belly, waiting to be pooped
    var lastMealAt: Date?
    var windowX: Double = -1
    var windowY: Double = -1
}

/// Tunable life-rates: deliberately slow, real-time decay. A pet dies only
/// after ~4h of *total* neglect (hunger or happiness pinned at ~0).
enum PetRates {
    static let hungerPerSec = 100.0 / (8 * 3600)      // full -> starving in ~8h
    static let happyPerSec = 100.0 / (10 * 3600)      // -> sad in ~10h
    static let energyPerSec = 100.0 / (12 * 3600)     // awake battery ~12h
    static let energyGainPerSec = 100.0 / (2 * 3600)  // full recharge in ~2h sleep
    static let neglectLimit = 4.0 * 3600             // 4h neglect -> death
    static let eggSeconds = 900.0    // incubation: ~15 min (warm = faster)
    static let hatchSeconds = 2.0
    static let juicyFileMB = 8.0        // a big juicy file -> strong glow
    static let snackFileMB = 0.5        // a real snack -> some glow
    static let mealsUntilLegs = 3       // enough files eaten -> legs
    static let mealsUntilArms = 6       // -> arms
    static let mealsUntilGadget = 12    // -> gadget (shades) + pool
    static let digestSeconds = 60.0      // fallback meal -> poop delay (settings can override)
    static let walkSecondsMin = 7.0     // wander episode length
    static let walkSecondsMax = 16.0
    static let walkSpeedMin = 9.0        // px/s on screen
    static let walkSpeedMax = 16.0
    static let jumpSeconds = 0.9
    static let playDuration = 1.6     // how long a trick plays out
    static let jumpChance = 0.00007     // rare happy hops (avg every ~25 min)
    static let defaultWalkChance = 0.00085   // setting default (avg every ~20 min)
    /// Age -> sprite size (piecewise linear; hours, sprite px per cell).
    /// Starts small, grows with time, tops out after a day.
    static let growthTable: [(hours: Double, scale: Double)] = [
        (0, 4.5), (1, 5.0), (6, 5.5), (12, 6.0), (24, 6.5),
    ]
    static let digestDefaultsKey = "RetroPet.digestSeconds"     // 0 = never
    static let walkChanceDefaultsKey = "RetroPet.walkChance"    // 0 = never wanders

    /// Setting: meal -> poop delay, in seconds (0 = never).
    static func digestSetting() -> Double {
        (UserDefaults.standard.object(forKey: digestDefaultsKey) as? Double) ?? 300
    }

    /// Setting: chance per second of starting a wander (0 = never).
    static func walkChanceSetting() -> Double {
        UserDefaults.standard.object(forKey: walkChanceDefaultsKey) as? Double ?? defaultWalkChance
    }
}

final class PetEngine: ObservableObject {
    @Published var model: PetModel
    @Published var hover = false
    @Published var controlsPinned = false
    @Published var earOpen = false            // "controls on left-ear click" mode
    @Published var particles: [Puff] = []
    @Published var eatUntil: Date?
    @Published var happyUntil: Date?
    @Published var glowUntil: Date?      // ears glow (fed a nice file)
    @Published var legsUntil: Date?      // growth moment window
    @Published var dragged = false        // true while the user drags the pet
    @Published var poopUntil: Date?      // squeezing one out
    // The poop is just a short visual: strain -> pile pops out ->
    // the file is restored (back where it came from) and the pile vanishes.
    @Published var pile: PoopRecord?     // transient, not persisted
    @Published var pileUntil: Date?
    // Wander: the pet really MOVES its window across the screen — horizontal
    // AND vertical — and turns around when it sniffs the screen edge.
    @Published var walkUntil: Date?
    @Published var walkDirX: Double = 1
    @Published var walkDirY: Double = 0
    var walkSpeed: Double = 12
    var sniffUntil: Date?
    // Rare little hops (new: jump).
    @Published var jumpUntil: Date?
    // Play: a trick from the play menu (toss / spin / salto / zoom).
    @Published var playMode: PlayMode = .toss
    @Published var playUntil: Date?
    // Growing: size follows age; a springy bounce plays at milestones.
    @Published var growBounceUntil: Date?
    private var lastScaleMark = -1.0
    // Incubation: live CPU temp shown on the shell; warmth speeds hatching.
    @Published var eggTemp: Double = 40
    // Swimming: when it strolls to its pool and takes a dip.
    @Published var swimUntil: Date?
    @Published var walkToPool = false
    /// Current pet window centre (screen coords), kept fresh by the app.
    var petPos: (x: Double, y: Double)?
    /// Where pooped files get restored to (default: Desktop).
    var restoreBase: URL = FileManager.default.urls(
        for: .desktopDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser

    struct Puff: Identifiable {
        let id = UUID()
        let frame: Frame        // heart / sparkle / ...
        let dx: Double
        let start: Date
    }

    enum WanderStep {
        case moving(dx: Double, dy: Double)   // apply to the window origin
        case ended                // episode just finished (save position)
        case idle
    }

    var clock: () -> Date
    var devMode = false
    var onDeath: ((PetModel) -> Void)?
    var onEatFile: ((URL) -> Void)?      // AppDelegate trashes the eaten file
    weak var sound: SoundBank?

    private var timer: Timer?
    private var lastAutoSave = Date.distantPast

    init(clock: @escaping () -> Date = { Date() }) {
        self.clock = clock
        self.model = PetModel()
    }

    // MARK: - Time

    var now: Date { clock() }
    var age: Double { now.timeIntervalSince(model.bornAt) }

    var hasLegs: Bool { model.legsGrown == true }
    var hasArms: Bool { model.armsGrown == true }
    var hasGadget: Bool { model.gadget == true }
    /// Evolution stage: 0 blob, 1 legs, 2 arms, 3 gadget.
    var evolution: Int {
        if model.gadget == true { return 3 }
        if model.armsGrown == true { return 2 }
        if model.legsGrown == true { return 1 }
        return 0
    }
    var growActive: Bool { legsUntil.map { now < $0 } ?? false }
    var isWalking: Bool {
        !model.dead && !model.asleep && !dragged
            && (walkUntil.map { now < $0 } ?? false)
    }
    var poopActive: Bool { poopUntil.map { now < $0 } ?? false }
    var jumpActive: Bool { jumpUntil.map { now < $0 } ?? false }
    var swimActive: Bool { swimUntil.map { now < $0 } ?? false }
    var growBounceActive: Bool { growBounceUntil.map { now < $0 } ?? false }
    var playActive: Bool { playUntil.map { now < $0 } ?? false }
    /// 0..1 progress of the current trick.
    var playPhase: Double {
        guard let u = playUntil else { return 0 }
        let remaining = u.timeIntervalSince(now)
        return max(0, min(1, 1 - remaining / PetRates.playDuration))
    }

    /// Chubbiness 0...100 (nil -> slim default).
    var chubValue: Double { min(100, max(0, model.chub ?? 0)) }

    /// Sprite size from age: starts small, grows to full size within ~a day.
    func ageScale() -> Double {
        let hours = age / 3600
        let t = PetRates.growthTable
        guard hours > 0, hours < t[t.count - 1].hours else {
            return hours <= 0 ? t[0].scale : t[t.count - 1].scale
        }
        for i in 1..<t.count where hours <= t[i].hours {
            let (h0, s0) = t[i - 1]
            let (h1, s1) = t[i]
            return s0 + (s1 - s0) * (hours - h0) / (h1 - h0)
        }
        return t[t.count - 1].scale
    }

    var mood: Mood {
        if model.dead { return .dead }
        if !model.everHatched { return .egg }
        if let h = model.hatchedAt, now.timeIntervalSince(h) < PetRates.hatchSeconds { return .hatch }
        if model.asleep { return .asleep }
        if model.hunger < 15 || model.happiness < 15 { return .sad }
        if (model.hunger + model.happiness) / 2 > 65 { return .happy }
        return .neutral
    }

    func start() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func tick() {
        advance(to: now)
        advancePoopPhase()
        advanceSwim()
        maybeGrow()
        maybeWalk()
        maybeJump()
        maybePoop()
        maybePlay()
        pruneParticles()
        autoSave()
    }

    /// Little growing animation when enough size was gained since the last one.
    private func maybeGrow() {
        guard !model.dead else { return }
        let s = ageScale()
        if lastScaleMark < 0 { lastScaleMark = s; return }   // adopt baseline, no storm
        guard s - lastScaleMark >= 0.4, !growBounceActive else { return }
        lastScaleMark = s
        growBounceUntil = now.addingTimeInterval(1.6)
        spawn(.sparkle, 5)
        print(String(format: "Mochi: %@ is growing! (size %.2f)", model.name, s))
        sound?.play(.hatch)
    }

    /// Applies elapsed real time (catch-up while the app was closed, App Nap, etc.).
    func advance(to date: Date) {
        let dt = max(0, date.timeIntervalSince(model.lastTick))
        guard dt > 0 else { return }
        model.lastTick = date
        if !model.everHatched {
            // incubation: warmth (CPU temp) speeds up the egg
            model.eggProgress = (model.eggProgress ?? 0) + dt * hatchRate()
            if (model.eggProgress ?? 0) >= PetRates.eggSeconds {
                forceHatch(silent: true)
            } else {
                refreshEggTemp()
            }
        }
        guard !model.dead else { return }

        let asleep = model.asleep
        model.hunger = max(0, model.hunger - PetRates.hungerPerSec * (asleep ? 0.5 : 1) * dt)
        model.happiness = max(0, model.happiness - PetRates.happyPerSec * (asleep ? 0.25 : 1) * dt)
        if asleep {
            model.energy = min(100, model.energy + PetRates.energyGainPerSec * dt)
            if model.energy >= 100 { model.asleep = false }   // sleeps it off, silent
        } else {
            model.energy = max(0, model.energy - PetRates.energyPerSec * dt)
            if model.energy <= 0 { model.asleep = true }   // exhausted pets pass out
        }

        if model.hunger <= 8 || model.happiness <= 8 {
            let both = model.hunger <= 8 && model.happiness <= 8
            model.neglect += dt * (both ? 3 : 1.5)
            if model.neglect >= PetRates.neglectLimit {
                die(cause: both ? "starvation" : "loneliness")
            }
        } else {
            model.neglect = max(0, model.neglect - dt)
        }
        // chub slowly burns off by itself; only playing really works it off
        model.chub = max(0, chubValue - dt * 0.001)
    }

    /// Cats wander a little: mostly it rests, but sometimes it gets up and
    /// trots across the screen - left/right AND up/down - pausing to sniff
    /// and turning around at the screen edges. Rarer than it used to be.
    func maybeWalk(probability: Double? = nil) {
        let p = probability ?? PetRates.walkChanceSetting()
        guard hasLegs, !model.dead, !model.asleep, !dragged, !isWalking,
              !poopActive, !jumpActive, !swimActive, Double.random(in: 0..<1) < p else { return }
        // gadget pets with a pool sometimes stroll over for a dip
        if (model.poolOwned == true), let pos = petPos,
           let pool = poolPoint(), Double.random(in: 0..<1) < 0.25 {
            let dist = hypot(pool.x - pos.x, pool.y - pos.y)
            walkToPool = true
            walkUntil = now.addingTimeInterval(max(10, min(90, dist / walkSpeed + 4)))
        } else {
            walkToPool = false
            walkUntil = now.addingTimeInterval(Double.random(in: PetRates.walkSecondsMin...PetRates.walkSecondsMax))
        }
        if Bool.random() {          // horizontal or vertical stroll
            walkDirX = Bool.random() ? 1 : -1
            walkDirY = 0
        } else {
            walkDirX = 0
            walkDirY = Bool.random() ? 1 : -1
        }
        walkSpeed = Double.random(in: PetRates.walkSpeedMin...PetRates.walkSpeedMax)
        sniffUntil = nil
    }

    /// Hit the screen edge while wandering: turn around (sometimes
    /// switching to the other axis for the stroll back).
    func turnAround() {
        if walkDirX != 0 { walkDirX *= -1 } else { walkDirY *= -1 }
        if Bool.random() {
            let dx = walkDirX
            walkDirX = walkDirY * (Bool.random() ? 1 : -1)
            walkDirY = dx * (Bool.random() ? 1 : -1)
        }
    }

    /// Rarely: a happy little hop.
    func maybeJump(probability: Double = PetRates.jumpChance) {
        guard hasLegs, !model.dead, !model.asleep, !dragged,
              !isWalking, !poopActive, !jumpActive, !swimActive,
              Double.random(in: 0..<1) < probability else { return }
        jumpUntil = now.addingTimeInterval(PetRates.jumpSeconds)
        sound?.play(.jump)
    }

    /// Called ~10x/s from the animation clock; returns the window delta to apply.
    func stepWander(dt: Double) -> WanderStep {
        guard !model.dead, !model.asleep, !dragged else {
            if walkUntil != nil { walkUntil = nil; return .ended }
            return .idle
        }
        guard let until = walkUntil, now < until else {
            if walkUntil != nil { walkUntil = nil; return .ended }
            return .idle
        }
        if swimActive { return .idle }   // busy swimming
        if walkToPool, let pos = petPos, let pool = poolPoint() {
            let dxv = pool.x - pos.x, dyv = pool.y - pos.y
            let dist = hypot(dxv, dyv)
            if dist < 60 { startSwim(); return .ended }   // arrived: dip!
            let step = min(walkSpeed * dt, dist)
            return .moving(dx: dxv / dist * step, dy: dyv / dist * step)
        }
        if let sniff = sniffUntil {
            if now < sniff { return .moving(dx: 0, dy: 0) }   // stopped, sniffing
            sniffUntil = nil
        }
        // occasionally pause to sniff (and sometimes turn around)
        if Double.random(in: 0..<1) < 0.01 {
            sniffUntil = now.addingTimeInterval(Double.random(in: 0.6...1.8))
            turnAround()
        }
        return .moving(dx: walkDirX * walkSpeed * dt,
                       dy: walkDirY * walkSpeed * dt)
    }

    /// Pool centre in screen coords (from persisted position).
    func poolPoint() -> (x: Double, y: Double)? {
        guard model.poolOwned == true, model.poolX >= 0, model.poolY >= 0 else { return nil }
        return (model.poolX, model.poolY)
    }

    func startSwim() {
        walkUntil = nil
        walkToPool = false
        swimUntil = now.addingTimeInterval(Double.random(in: 7...14))
        model.happiness = min(100, model.happiness + 8)
        print("Mochi: \(model.name) is taking a dip in the pool")
        sound?.play(.sleep)   // whoosh: dive
        save()
    }

    private func advanceSwim() {
        guard let until = swimUntil, now >= until, !swimActive else { return }
        swimUntil = nil
        print("Mochi: \(model.name) got out of the pool, refreshed")
        sound?.play(.wake)
        spawn(.sparkle, 3)
        // walk away from the edge a little, then carry on as usual
        walkDirX = Bool.random() ? 1 : -1
        walkDirY = 0
        walkUntil = now.addingTimeInterval(3)
        save()
    }

    private func pruneParticles() {
        particles.removeAll { now.timeIntervalSince($0.start) > 1.4 }
    }

    // MARK: - Incubation & breed

    var eggProgressValue: Double { model.eggProgress ?? 0 }

    /// Warmer CPU -> faster hatch: ~0.5x cold, ~1x at ~45°C, ~2x hot.
    func hatchRate() -> Double {
        min(2.0, max(0.5, (eggTemp - 20) / 25))
    }

    private func refreshEggTemp() {
        eggTemp = MacTemp.read()
    }

    /// H key (or nature): crack the egg open now.
    func forceHatch(silent: Bool = false) {
        guard !model.dead, !model.everHatched else { return }
        model.everHatched = true
        model.eggProgress = max(model.eggProgress ?? 0, PetRates.eggSeconds)
        model.hatchedAt = now
        spawn(.sparkle, 6)
        sound?.play(.hatch)
        print("Mochi: the egg cracks open — \(model.name) the \(breed.name) is here!")
        save()
    }

    // MARK: - Breed (random colors: every pet feels unique)

    var breed: Breed {
        Breed.all.first { $0.name == model.breedName } ?? Breed.all[0]
    }

    /// Sprite palette override for the breed colors.
    var breedOverrides: [Character: Color] {
        let b = breed
        return [
            "B": Color(red: b.body.0, green: b.body.1, blue: b.body.2),
            "S": Color(red: b.shade.0, green: b.shade.1, blue: b.shade.2),
            "P": Color(red: b.blush.0, green: b.blush.1, blue: b.blush.2),
        ]
    }

    // MARK: - Actions

    func feed() {
        guard !model.dead, model.everHatched else { return }
        if model.asleep { model.asleep = false }
        model.hunger = min(100, model.hunger + 40)
        model.happiness = min(100, model.happiness + 4)
        model.chub = min(100, chubValue + 6)   // snacks add up
        eatUntil = now.addingTimeInterval(2.4)
        spawn(.heart, 1)
        sound?.play(.feed)
        save()
    }

    /// Feed the pet a real file (drag & drop / picker). Bigger files are
    /// tastier: more hunger, more happiness, and the ears glow.
    /// After enough meals it GROWS LEGS. Everything it eats is remembered —
    /// what goes in must come out (see maybePoop).
    func feedFile(url: URL) {
        guard !model.dead else { return }
        guard model.everHatched else { return }   // eggs don't eat
        if model.asleep { model.asleep = false }  // snack drop wakes it

        let bytes = Self.fileSize(url)
        let mb = Double(bytes) / 1_048_576
        let quality: Int = mb >= PetRates.juicyFileMB ? 3 : (mb >= PetRates.snackFileMB ? 2 : 1)

        model.hunger = min(100, model.hunger + min(70, 14 + mb * 4))
        model.happiness = min(100, model.happiness + min(24, 4 + mb * 2))
        model.energy = min(100, model.energy + 3)
        model.chub = min(100, chubValue + min(20, 3 + mb * 0.8))   // big meals = chub
        model.filesEaten += 1
        model.bytesEaten += Int64(bytes)
        model.lastMealAt = now

        eatUntil = now.addingTimeInterval(2.4)
        glowUntil = now.addingTimeInterval(Double(quality) * 3.5)   // ears glow
        if quality >= 2 { happyUntil = now.addingTimeInterval(Double(quality) * 2) }

        // remember the meal in the belly (poop restores by name, so keep it)
        if model.lastEaten == nil { model.lastEaten = [] }
        model.lastEaten?.append(url.lastPathComponent)
        if (model.lastEaten ?? []).count > 12 { model.lastEaten?.removeFirst() }

        let mbText = mb >= 1 ? String(format: "%.1f MB", mb) : "\(max(1, Int(bytes / 1024))) KB"
        print("Mochi: nom nom — ate \(url.lastPathComponent) (\(mbText), meal quality \(quality))")
        sound?.play(.feed)

        evolve()

        onEatFile?(url)   // -> moved to Trash by the app
        save()
    }

    /// Evolution chain: legs -> arms -> gadget (shades) -> pool unlock.
    /// Triggered by meals eaten (files or browser tabs both count).
    private func evolve() {
        if !hasLegs && model.filesEaten >= PetRates.mealsUntilLegs {
            model.legsGrown = true
            legsUntil = now.addingTimeInterval(3.5)   // celebrate with a trot
            spawn(.sparkle, 6)
            print("Mochi: \(model.name) grew legs!")
            sound?.play(.hatch)
        } else if !hasArms && model.filesEaten >= PetRates.mealsUntilArms {
            model.armsGrown = true
            legsUntil = now.addingTimeInterval(3.5)
            spawn(.sparkle, 8)
            print("Mochi: \(model.name) grew little arms!")
            sound?.play(.hatch)
        } else if !hasGadget && model.filesEaten >= PetRates.mealsUntilGadget {
            model.gadget = true
            legsUntil = now.addingTimeInterval(3.5)
            spawn(.sparkle, 10)
            print("Mochi: \(model.name) got a gadget - cool shades! (and can now own a pool)")
            sound?.play(.hatch)
        } else {
            spawn(.heart, 2)
        }
    }

    static func fileSize(_ url: URL) -> Int {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            if let size = (try? fm.attributesOfItem(atPath: url.path))?[.size] as? NSNumber {
                return size.intValue
            }
            return 0
        }
        let en = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        var total = 0
        while let item = en?.nextObject() as? URL {
            if let size = (try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                total += size
            }
        }
        return total
    }

    // MARK: toilet (poop = the files it ate, come back out)

    /// What goes in must come out: some time after a meal the pet pauses,
    /// squeezes, a little pile pops out — and shortly after, the file itself
    /// is restored from the Trash ("it pooped the file back out").
    func maybePoop(force: Bool = false) {
        guard !model.dead, !model.asleep, !poopActive, !jumpActive, pile == nil,
              !(model.lastEaten ?? []).isEmpty,
              let meal = model.lastMealAt,
              force || (PetRates.digestSetting() > 0
                        && now.timeIntervalSince(meal) > PetRates.digestSetting()),
              force || Double.random(in: 0..<1) < 0.02 else { return }

        let entry = model.lastEaten!.removeFirst()
        var displayName = entry
        var tabURL: String? = nil
        if entry.hasPrefix("tab:") {
            let rest = entry.dropFirst(4)
                .split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            tabURL = rest.count > 0 && !rest[0].isEmpty ? String(rest[0]) : nil
            displayName = rest.count > 1 && !rest[1].isEmpty ? String(rest[1]) : "a browser tab"
        }
        let side = Bool.random() ? 1.0 : -1.0
        pile = PoopRecord(
            fileName: displayName,
            url: tabURL,
            dx: side * Double.random(in: 34...54),
            dy: Double.random(in: 10...18))
        poopUntil = now.addingTimeInterval(2.2)   // squeeze...
        pileUntil = now.addingTimeInterval(4.4)    // ...pile shows briefly, then restore
        model.happiness = min(100, model.happiness + 3)   // relief
        print("Mochi: ...\(model.name) is pushing one out")
        save()
    }

    /// Feed the pet a browser tab (right-click → “Eat browser tabs…”):
    /// the tab is closed in the browser and eaten as a juicy snack.
    /// A pooped tab comes back out as a .webloc link file.
    func feedTab(browser: String, title: String, url: String) {
        guard !model.dead, model.everHatched else { return }
        if model.asleep { model.asleep = false }

        let mb = Double.random(in: 0.2...1.4)   // a juicy tab
        model.hunger = min(100, model.hunger + min(50, 10 + mb * 4))
        model.happiness = min(100, model.happiness + min(20, 4 + mb * 3))
        model.energy = min(100, model.energy + 2)
        model.chub = min(100, chubValue + 6)   // tabs are rich food
        model.filesEaten += 1
        model.bytesEaten += Int64(mb * 1_048_576)
        if model.lastEaten == nil { model.lastEaten = [] }
        model.lastEaten?.append("tab:\(url)\t\(title)")
        model.lastMealAt = now

        eatUntil = now.addingTimeInterval(2.4)
        glowUntil = now.addingTimeInterval(2.5)   // little glow: nice tab
        spawn(.heart, 2)
        evolve()
        print("Mochi: nom nom — ate the \(browser) tab '\(title)'")
        sound?.play(.feed)
        save()
    }

    /// Poop state machine (driven by tick): strain -> plop -> auto-restore.
    private func advancePoopPhase() {
        if let pu = poopUntil, now >= pu {
            poopUntil = nil
            sound?.play(.poop)              // plop
        }
        if let vu = pileUntil, now >= vu {
            pileUntil = nil
            restorePile()
        }
    }

    /// Restore the eaten file from the Trash (the pile WAS the file) —
    /// or, for browser-tab meals, re-create it as a .webloc link file.
    /// Called automatically when the pile vanishes, or immediately on click.
    @discardableResult
    func restorePile() -> Bool {
        guard let pile = pile else { return false }
        self.pile = nil
        var restored = false
        if let url = pile.url, !url.isEmpty {
            // tab meal -> clickable link file on the Desktop
            let base = DeathNote.safeName(pile.fileName.isEmpty ? "tab" : pile.fileName)
            var dest = restoreBase.appendingPathComponent(base + ".webloc")
            if FileManager.default.fileExists(atPath: dest.path) {
                dest = restoreBase.appendingPathComponent("restored-\(base).webloc")
            }
            let esc = url.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict><key>URL</key><string>\(esc)</string></dict></plist>
            """
            do {
                try xml.data(using: .utf8)?.write(to: dest, options: .atomic)
                restored = true
                print("Mochi: poop! — restored the tab as a link -> \(dest.path)")
            } catch {
                print("Mochi: couldn't write \(dest.lastPathComponent): \(error)")
            }
        } else {
            let trashURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".Trash/\(pile.fileName)")
            if FileManager.default.fileExists(atPath: trashURL.path) {
                var dest = restoreBase.appendingPathComponent(pile.fileName)
                if FileManager.default.fileExists(atPath: dest.path) {
                    dest = restoreBase.appendingPathComponent("restored-\(pile.fileName)")
                }
                do {
                    try FileManager.default.moveItem(at: trashURL, to: dest)
                    restored = true
                    print("Mochi: poop! — restored \(pile.fileName) -> \(dest.path)")
                } catch {
                    print("Mochi: couldn't restore \(pile.fileName): \(error)")
                }
            } else {
                print("Mochi: \(pile.fileName) isn't in the Trash anymore (already gone?)")
            }
        }
        spawn(.sparkle, 3)
        if restored { sound?.play(.wake) }
        save()
        return restored
    }

    /// Occasionally does a random trick when idle and happy.
    func maybePlay(probability: Double = 0.0001) {
        guard !model.dead, model.everHatched, !model.asleep,
              !playActive, !jumpActive, !poopActive, !isWalking,
              Double.random(in: 0..<1) < probability else { return }
        play(PlayMode.allCases.randomElement()!)
        sound?.play(.play)
        print("Mochi: \(model.name) plays a trick spontaneously")
    }

    // MARK: more actions

    func play(_ mode: PlayMode) {
        guard !model.dead, model.everHatched else { return }
        if model.asleep { return }
        let wasChubby = chubValue > 60
        model.happiness = min(100, model.happiness + 30)
        model.energy = max(0, model.energy - 6)
        model.hunger = max(0, model.hunger - 4)
        model.chub = max(0, chubValue - 10)   // playing it off
        if wasChubby && chubValue <= 60 {
            print("Mochi: \(model.name) burned off the extra chub — good exercise!")
        }
        playMode = mode
        playUntil = now.addingTimeInterval(PetRates.playDuration)
        spawn(.heart, 3)
        spawn(.sparkle, mode == .toss ? 2 : 4)
        sound?.play(.play)
        save()
    }

    /// Random trick, for the occasional autonomous play session.
    func playTrick() {
        guard !model.dead, model.everHatched, !model.asleep,
              !playActive, !jumpActive, !poopActive, !isWalking else { return }
        play(PlayMode.allCases.randomElement()!)
    }

    func pat() {
        guard !model.dead else { return }
        if !model.everHatched { spawn(.sparkle, 1); return }   // egg: a curious boop
        model.happiness = min(100, model.happiness + 5)
        happyUntil = now.addingTimeInterval(1.2)
        spawn(.heart, 1)
        sound?.play(.pat)
        save()
    }

    func toggleSleep() {
        guard !model.dead, model.everHatched else { return }
        if model.asleep {
            model.asleep = false
            sound?.play(.wake)
        } else {
            model.asleep = true
            walkUntil = nil
            sound?.play(.sleep)
        }
        save()
    }

    func die(cause: String) {
        guard !model.dead else { return }
        model.dead = true
        model.diedAt = now
        model.deathCause = cause
        model.asleep = false
        particles = []
        eatUntil = nil
        happyUntil = nil
        glowUntil = nil
        legsUntil = nil
        walkUntil = nil
        swimUntil = nil
        walkToPool = false
        onDeath?(model)
        save()
    }

    func newPet(name: String = "Mochi") {
        var fresh = PetModel()
        fresh.name = name.isEmpty ? "Mochi" : name
        fresh.bornAt = now
        fresh.lastTick = now
        fresh.breedName = Breed.random().name
        fresh.eggProgress = 0
        fresh.hatchedAt = nil
        fresh.windowX = model.windowX
        fresh.windowY = model.windowY
        model = fresh
        eggTemp = MacTemp.read()
        earOpen = false
        legsUntil = nil
        walkUntil = nil
        poopUntil = nil
        jumpUntil = nil
        lastScaleMark = -1
        growBounceUntil = nil
        sound?.setAmbient(true)
        sound?.play(.hatch)
        save()
    }

    func rename(_ n: String) {
        guard !n.isEmpty else { return }
        model.name = n
        save()
    }

    func spawn(_ frame: Frame, _ n: Int) {
        for _ in 0..<n {
            particles.append(Puff(frame: frame,
                                   dx: Double.random(in: -40...40),
                                   start: now))
        }
    }

    // Dev helper (also used by --smoke): age the pet by `seconds` of real time.
    func timeSkip(_ seconds: Double) {
        model.bornAt = model.bornAt.addingTimeInterval(-seconds)
        model.lastTick = model.lastTick.addingTimeInterval(-seconds)
        if let d = model.diedAt { model.diedAt = d.addingTimeInterval(-seconds) }
        tick()
    }

    // MARK: - Persistence

    func save() { PetStore.save(model) }

    private func autoSave() {
        if now.timeIntervalSince(lastAutoSave) > 30 { save(); lastAutoSave = now }
    }

    func adopt(loaded: PetModel) {
        model = loaded
        if model.lastEaten == nil { model.lastEaten = [] }
        if model.breedName == nil { model.breedName = Breed.random().name }
        if model.everHatched == false, model.eggProgress == nil {
            model.eggProgress = min(max(0, age), PetRates.eggSeconds * 0.5)   // old egg: half credit
        }
        pile = nil
        pileUntil = nil
        poopUntil = nil
    }

    func savePosition(x: Double, y: Double) {
        model.windowX = x
        model.windowY = y
        save()
    }
}