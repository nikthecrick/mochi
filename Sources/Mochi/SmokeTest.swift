import Foundation

/// Headless self-test: `Mochi --smoke`
enum SmokeTest {
    static func run() -> String {
        var failures = 0
        func check(_ name: String, _ cond: Bool) {
            print((cond ? "  PASS  " : "  FAIL  ") + name)
            if !cond { failures += 1 }
        }

        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mochi-smoke-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        PetStore.directory = tmp
        DeathNote.directoryOverride = tmp

        // 1) sprites
        for f in Frame.allCases {
            let g = Sprites.grid(f)
            var ink = 0
            for row in g.cells {
                for c in row where c != "." {
                    ink += 1
                    if Pal.rgba[c] == nil { check("sprite \(f.rawValue) unknown color '\(c)'", false) }
                }
            }
            check("sprite \(f.rawValue) renders", ink > 4)
        }

        // 2) engine: decays but survives
        let e = PetEngine()
        var nowT = 100_000.0
        e.clock = { Date(timeIntervalSinceReferenceDate: nowT) }
        e.newPet()
        e.model.everHatched = true
        e.tick()
        nowT += 4 * 3600
        e.tick()
        check("alive after 4h without care", !e.model.dead && e.model.hunger < 90)
        e.feed()
        check("feed fills hunger + eating anim", e.model.hunger > 70 && e.eatUntil != nil)
        e.play(.toss)
        check("play raises happiness", e.model.happiness > e.model.hunger)
        check("play sets toss mode + anim", e.playActive && e.playMode == .toss)
        e.play(.spin)
        check("play spin mode", e.playMode == .spin && e.playActive)
        e.play(.salto)
        check("play salto mode", e.playMode == .salto && e.playActive)
        e.play(.zoom)
        check("play zoom mode", e.playMode == .zoom && e.playActive)
        e.playUntil = e.now.addingTimeInterval(-1)
        check("play ends (phase done)", !e.playActive)
        nowT += 2 * 3600
        e.tick()
        check("alive after 6h total", !e.model.dead)

        // 3) neglect kills (the harsh rule)
        var diedCalled = false
        e.onDeath = { _ in diedCalled = true }
        e.model.hunger = 0
        e.model.happiness = 0
        nowT += 3 * 3600
        e.tick()
        check("neglected pet dies", e.model.dead && diedCalled)
        check("death cause recorded", e.model.deathCause == "starvation")

        // 4) death note
        let note = DeathNote.write(for: e.model)
        check("death note .txt written",
              note.txt.map { FileManager.default.fileExists(atPath: $0.path) } ?? false)
        check("tombstone .png written",
              note.png.map { FileManager.default.fileExists(atPath: $0.path) } ?? false)

        // 5) persistence round trip
        var m = e.model
        m.name = "RoundTrip"
        PetStore.save(m)
        let back = PetStore.load()
        check("pet.json round trip", back?.name == "RoundTrip" && back?.dead == true)

        // 6) borrow-pet round trip (prepared feature)
        let lendURL = tmp.appendingPathComponent("friend.mochi")
        var exported = false
        do { try BorrowManager.export(m, to: lendURL); exported = true } catch {}
        check("export .mochi snapshot", exported)
        let borrowed = try? BorrowManager.importPet(at: lendURL)
        check("import borrowed pet", borrowed?.name == "RoundTrip" && borrowed?.borrowedFrom != nil)

        // 7) self-destruct prepared but OFF by default
        check("self-destruct off by default", !GrimReaper.selfDestructEnabled)

        // 8) fresh pet after death
        e.newPet(name: "Second")
        check("new pet is fresh & alive", !e.model.dead && e.model.name == "Second" && !e.eatActive)

        // 9) file feeding (drag & drop / picker)
        e.model.everHatched = true
        let snack = tmp.appendingPathComponent("snack.bin")
        try? Data(repeating: 7, count: 5 * 1024 * 1024).write(to: snack)   // 5 MB
        var eaten = 0
        e.onEatFile = { _ in eaten += 1 }
        e.model.hunger = 40                              // hungry pet (no 100 cap)
        let h0 = e.model.hunger
        e.feedFile(url: snack)
        check("file feeding raises hunger", e.model.hunger > h0 + 30)
        check("file feeding counts bytes", e.model.bytesEaten > 4 * 1024 * 1024 && e.model.filesEaten == 1)
        check("file feeding glows the ears", (e.glowUntil ?? e.now) > e.now)
        check("file feeding reports to trash hook", eaten == 1)
        let nibble = tmp.appendingPathComponent("nibble.bin")
        try? Data(repeating: 1, count: 2048).write(to: nibble)           // tiny snack
        let gLow = e.model.hunger
        e.feedFile(url: nibble)
        check("tiny file is just a nibble", e.model.hunger - gLow < 25)

        // 10) legs: grow after enough meals, wander across the screen
        check("no legs before enough meals", !e.hasLegs)
        check("happy face is still", Sprites.ascii(.happyA) == Sprites.ascii(.happyB))
        check("stand frames differ", Sprites.ascii(.standA) != Sprites.ascii(.standB))
        check("walk frames differ", Sprites.ascii(.walkLegsA) != Sprites.ascii(.walkLegsB))
        check("dangle frames differ", Sprites.ascii(.dangleA) != Sprites.ascii(.dangleB))
        check("resting face smiles (not sad)",
              Sprites.ascii(.idleA) != Sprites.ascii(.sadA)
              && Sprites.ascii(.lookL) != Sprites.ascii(.lookR)
              && Sprites.ascii(.smug) != Sprites.ascii(.idleA))
        check("strain & poop sprites render",
              Sprites.ascii(.strainA) != Sprites.ascii(.strainB)
              && Sprites.ascii(.poop).contains("M"))
        e.feedFile(url: nibble)                      // 3rd meal -> legs!
        check("grows legs after 3 meals", e.hasLegs && e.growActive)
        e.maybeWalk(probability: 1)
        check("wanders occasionally", e.isWalking)
        var movedWindow = false
        if case .moving(let dx, let dy) = e.stepWander(dt: 0.1), dx != 0 || dy != 0 { movedWindow = true }
        check("wandering moves the window (x or y)", movedWindow)
        e.walkUntil = e.now.addingTimeInterval(-1)   // episode over
        var walkEnded = false
        if case .ended = e.stepWander(dt: 0.1) { walkEnded = true }
        check("wander episode ends (position saved)", walkEnded && !e.isWalking)
        e.dragged = true
        check("dragging cancels walking", !e.isWalking)
        e.dragged = false

        // 11b) screen edges & jumps
        e.walkDirX = 1; e.walkDirY = 0
        e.turnAround()
        check("edge detection turns it around",
              e.walkDirX != 1 || e.walkDirY != 0)   // flipped or switched axis
        e.maybeJump(probability: 1)
        check("rarely jumps (when it feels like it)", e.jumpActive)
        e.jumpUntil = e.now.addingTimeInterval(-1)
        check("jump ends", !e.jumpActive)

        // 11c) evolution: arms (stage 2) and gadget (stage 3)
        check("new sprites differ from stage-1",
              Sprites.ascii(.stand2A) != Sprites.ascii(.standA)
              && Sprites.ascii(.walkLegs2A) != Sprites.ascii(.walkLegsA)
              && Sprites.ascii(.dangle2A) != Sprites.ascii(.dangleA))
        check("wave & cool & swim frames render",
              Sprites.ascii(.wave2).contains("S")
              && Sprites.ascii(.cool2).contains("K")
              && Sprites.ascii(.swimA) != Sprites.ascii(.swimB)
              && Sprites.ascii(.pool).contains("A"))
        e.feedFile(url: nibble)   // meal 4 -> still stage 1
        check("stage stays without enough meals", e.evolution == 1)
        e.feedFile(url: nibble)   // meal 5
        e.feedFile(url: nibble)   // meal 6 -> ARMS
        check("grows arms at 6 meals", e.evolution == 2 && e.growActive)
        // swimming needs a pool
        e.model.poolOwned = true
        e.model.poolX = 500; e.model.poolY = 500
        check("pool point decodes", e.poolPoint() != nil)
        e.petPos = (x: 100, y: 100)
        e.walkUntil = e.now.addingTimeInterval(60)          // strolling: pool trip active
        e.walkToPool = true
        if case .moving(let dx, let dy) = e.stepWander(dt: 0.1) {
            check("heads toward the pool", dx > 0 && dy > 0)
        } else {
            check("heads toward the pool", false)
        }
        e.petPos = (x: 480, y: 480)   // close to the pool -> dive!
        if case .ended = e.stepWander(dt: 0.1) {} else { check("arrives at pool", false) }
        check("arrival starts a swim", e.swimActive && !e.walkToPool)
        e.swimUntil = e.now.addingTimeInterval(-1)
        e.tick()                        // swim over: gets out, walks off a bit
        check("swim ends, carries on", !e.swimActive && e.isWalking)
        e.walkUntil = nil
        e.model.poolOwned = false

        // 11) toilet: poop is a short visual — strain -> pile -> file restored
        e.restoreBase = tmp
        let belly0 = (e.model.lastEaten ?? []).count
        check("belly remembers the meals", belly0 >= 3)
        e.maybePoop(force: true)
        check("starts squeezing", e.poopActive && e.pile != nil)
        var plop = false
        e.model.lastMealAt = e.now                          // keep maybePoop quiet
        e.poopUntil = e.now.addingTimeInterval(-1)   // strain over -> plop
        e.tick()
        plop = !e.poopActive && e.pile != nil
        check("pile pops out, strain ends", plop)
        var vanished = false
        e.model.lastMealAt = e.now                          // keep maybePoop quiet
        e.pileUntil = e.now.addingTimeInterval(-1)   // pile vanishes -> restore
        e.tick()
        vanished = e.pile == nil
        check("pile is short-lived (auto-restore)", vanished)
        check("belly shrinks", (e.model.lastEaten ?? []).count == belly0 - 1)

        // 12) poop timing setting (Soon/Normal/Seldom/Never)
        UserDefaults.standard.set(0.0, forKey: PetRates.digestDefaultsKey)   // Never
        e.model.lastMealAt = e.now.addingTimeInterval(-9999)
        let bellyCount = (e.model.lastEaten ?? []).count
        e.maybePoop()
        check("poop timing 'Never' disables pooping", (e.model.lastEaten ?? []).count == bellyCount)
        UserDefaults.standard.set(1.0, forKey: PetRates.digestDefaultsKey)   // Soon
        var pooped = false
        for _ in 0..<400 {                                   // 2% roll per call
            e.maybePoop()
            if e.pile != nil { pooped = true; break }
        }
        check("poop timing 'Soon' poops after the delay", pooped && (e.model.lastEaten ?? []).count == bellyCount - 1)
        e.pile = nil; e.pileUntil = nil; e.poopUntil = nil   // tidy
        UserDefaults.standard.removeObject(forKey: PetRates.digestDefaultsKey)

        // 13) browser tabs as food (dropped onto the pet: tab or link drag)
        check("web URLs detected",
              BrowserEater.isWebURL(URL(string: "https://x.y/z")!)
              && !BrowserEater.isWebURL(URL(fileURLWithPath: "/tmp/a")))
        check("tab parser filters junk",
              BrowserEater.parse("A\thttps://a\nB\tmissing value\nbadline", browser: "Chrome").count == 1)
        let fe0 = e.model.filesEaten
        e.feedTab(browser: "Google Chrome", title: "Docs", url: "https://example.com/docs?a=1&b=2")
        check("eating a tab feeds the pet",
              e.model.filesEaten == fe0 + 1
              && (e.model.lastEaten ?? []).last?.hasPrefix("tab:https://example.com/docs") == true)
        let tabEntry = e.model.lastEaten!.last!
        e.model.lastEaten = [e.model.lastEaten!.first ?? tabEntry, tabEntry]   // one file + the tab
        e.pile = nil; e.pileUntil = nil; e.poopUntil = nil
        e.maybePoop(force: true)                 // pops the older file entry
        check("file meal still pops as a file pile", e.pile != nil && e.pile?.url == nil)
        e.pile = nil; e.pileUntil = nil; e.poopUntil = nil
        e.maybePoop(force: true)                 // pops the tab entry
        check("tab becomes a link pile",
              e.pile?.url == "https://example.com/docs?a=1&b=2" && e.pile?.fileName == "Docs")
        e.pileUntil = e.now.addingTimeInterval(-1)
        e.tick()                                 // auto-restore -> .webloc on the "Desktop"
        let webloc = tmp.appendingPathComponent("Docs.webloc")
        check("tab poop restores as .webloc link",
              e.pile == nil && FileManager.default.fileExists(atPath: webloc.path))
        if let data = try? String(contentsOf: webloc, encoding: .utf8) {
            check("webloc contains the eaten URL", data.contains("https://example.com/docs?a=1&amp;b=2"))
        } else {
            check("webloc contains the eaten URL", false)
        }

        // 14) size growth by age + chubbiness (fresh pet, separate engine)
        let g = PetEngine()
        var gNow = 2_000_000.0
        g.clock = { Date(timeIntervalSinceReferenceDate: gNow) }
        g.newPet()
        check("egg starts (breed chosen)", !g.model.everHatched && g.model.breedName != nil)
        g.forceHatch()   // hatch instantly for the stats tests
        g.tick()   // growth baseline
        check("starts small", g.ageScale() >= 4.5 && g.ageScale() < 5.05)
        gNow += 6 * 3600
        g.tick()
        check("grows with age", abs(g.ageScale() - 5.5) < 0.05)
        check("growing bounce plays", g.growBounceActive)
        g.growBounceUntil = nil
        let c0 = g.chubValue
        g.feedFile(url: nibble)
        check("eating adds chub", g.chubValue > c0)
        let c1 = g.chubValue
        g.play(.toss)
        check("playing burns chub", g.chubValue < c1)
        g.model.bornAt = g.now.addingTimeInterval(-30 * 3600)
        check("size tops out after a day", g.ageScale() > 6.4)
        check("chub caps at 100", {
            g.model.chub = 250
            return g.chubValue == 100
        }())

        // 15) breeds: random colors, unique pets
        check("8 breeds available", Breed.all.count >= 8)
        var seen = Set<String>()
        for _ in 0..<80 { seen.insert(Breed.random().name) }
        check("breeds vary (random)", seen.count >= 5)
        check("breed colors override sprite palette",
              g.breedOverrides["B"] != nil && g.breedOverrides["S"] != nil)

        // 16) incubation: long egg + CPU temp + H cheat
        let h = PetEngine()
        var hNow = 3_000_000.0
        h.clock = { Date(timeIntervalSinceReferenceDate: hNow) }
        h.newPet()
        check("starts as an egg", h.mood == .egg)
        h.tick()
        check("egg temp is plausible", h.eggTemp > 15 && h.eggTemp < 120)
        hNow += 200
        h.tick()
        check("long incubation: still an egg after 200s", h.mood == .egg)
        check("incubation barely progressed", h.eggProgressValue < 500)
        check("hatch rate scales with warmth", h.hatchRate() >= 0.5 && h.hatchRate() <= 2.0)
        h.forceHatch()
        check("H cheat hatches instantly", h.model.everHatched && h.mood == .hatch)
        hNow += 5
        h.tick()
        check("hatch moment passes", h.mood != .hatch && h.mood != .egg)

        print(failures == 0 ? "\nSMOKE OK" : "\nSMOKE FAILED (\(failures) failures)")
        return failures == 0 ? "SMOKE OK" : "SMOKE FAILED"
    }
}