import AppKit
import ObjectiveC

var petMenuBoxKey: UInt8 = 0

/// Right-click menu, built fresh on every popup (states always current).
enum PetMenu {
    final class Box: NSObject { var handlers: [Handler] = [] }
    final class Handler: NSObject {
        let fn: () -> Void
        init(_ fn: @escaping () -> Void) { self.fn = fn }
        @objc func fire() { fn() }
    }
    static var assocKey: UInt8 = 0

    static func make(engine: PetEngine, sound: SoundBank,
                     cleanToilet: @escaping () -> Void = {},
                     givePool: @escaping () -> Void = {},
                     removePool: @escaping () -> Void = {}) -> NSMenu {
        let box = Box()
        func item(_ title: String, fn: @escaping () -> Void) -> NSMenuItem {
            let h = Handler(fn)
            box.handlers.append(h)
            let m = NSMenuItem(title: title, action: #selector(Handler.fire), keyEquivalent: "")
            m.target = h
            return m
        }
        func toggle(_ title: String, isOn: Bool, fn: @escaping () -> Void) -> NSMenuItem {
            let m = item(title, fn: fn)
            m.state = isOn ? .on : .off
            return m
        }

        let menu = NSMenu()
        objc_setAssociatedObject(menu, &petMenuBoxKey, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        let head = NSMenuItem(title: "\(engine.model.name) · age \(ageString(engine.age))",
                              action: nil, keyEquivalent: "")
        head.isEnabled = false
        menu.addItem(head)
        menu.addItem(.separator())

        // Settings: how the glass controls appear
        let modeMenu = NSMenu()
        let current = UserDefaults.standard.string(forKey: "RetroPet.showMode") ?? "hover"
        let hoverItem = item("On hover") {
            UserDefaults.standard.set("hover", forKey: "RetroPet.showMode")
        }
        hoverItem.state = current == "hover" ? .on : .off
        let earItem = item("On left-ear click (toggle)") {
            UserDefaults.standard.set("ear", forKey: "RetroPet.showMode")
        }
        earItem.state = current == "ear" ? .on : .off
        modeMenu.addItem(hoverItem)
        modeMenu.addItem(earItem)
        let modeParent = menu.addItem(withTitle: "Controls appear…", action: nil, keyEquivalent: "")
        modeParent.submenu = modeMenu

        // Settings: poop timing (meal -> poop delay, or never)
        let poopMenu = NSMenu()
        let digestCurrent = PetRates.digestSetting()
        for (label, value) in [("Soon (about 1 min)", 60.0), ("Normal (about 5 min)", 300.0),
                                ("Seldom (about 15 min)", 900.0), ("Never (files stay eaten)", 0.0)] {
            let mi = item(label) {
                UserDefaults.standard.set(value, forKey: PetRates.digestDefaultsKey)
            }
            mi.state = digestCurrent == value ? .on : .off
            poopMenu.addItem(mi)
        }
        let poopParent = menu.addItem(withTitle: "Poop timing…", action: nil, keyEquivalent: "")
        poopParent.submenu = poopMenu

        // Settings: how often it wanders around
        let walkMenu = NSMenu()
        let walkCurrent = PetRates.walkChanceSetting()
        for (label, value) in [("Often (about every 30s)", 0.03), ("Normal (about every 20 min)", PetRates.defaultWalkChance),
                               ("Seldom (about every hour)", 0.000283), ("Never (stays put)", 0.0)] {
            let mi = item(label) {
                UserDefaults.standard.set(value, forKey: PetRates.walkChanceDefaultsKey)
            }
            mi.state = walkCurrent == value ? .on : .off
            walkMenu.addItem(mi)
        }
        let walkParent = menu.addItem(withTitle: "Wandering…", action: nil, keyEquivalent: "")
        walkParent.submenu = walkMenu

        menu.addItem(item("Feed a snack") { engine.feed() })
        menu.addItem(item("Play") { engine.play(.toss) })
        menu.addItem(item(engine.model.asleep ? "Wake up" : "Sleep") { engine.toggleSleep() })
        menu.addItem(.separator())
        menu.addItem(toggle("Ambient music", isOn: sound.musicOn) { sound.musicOn.toggle() })
        menu.addItem(toggle("Mute sound effects", isOn: sound.muted) { sound.muted.toggle() })
        menu.addItem(toggle("Pin controls", isOn: engine.controlsPinned) { engine.controlsPinned.toggle() })
        menu.addItem(.separator())
        menu.addItem(item("Feed with a file… (moved to Trash)") { Dialogs.eatFilePicker(engine) })
        menu.addItem(item("Clean toilet (empty the Trash)…") { cleanToilet() })
        // Pool (gadget stage)
        if engine.hasGadget {
            if engine.model.poolOwned == true {
                menu.addItem(item("Remove the pool…") { removePool() })
            } else {
                menu.addItem(item("Give it a pool…") { givePool() })
            }
        } else {
            let locked = NSMenuItem(title: "Pool: keep feeding to unlock…", action: nil, keyEquivalent: "")
            locked.isEnabled = false
            menu.addItem(locked)
        }
        menu.addItem(item("Rename…") { Dialogs.rename(engine) })
        menu.addItem(item("New pet…") { Dialogs.newPet(engine) })
        menu.addItem(item("Quit RetroPet") { NSApp.terminate(nil) })

        if engine.devMode {
            menu.addItem(.separator())
            let dev = NSMenuItem(title: "Dev — prepared features", action: nil, keyEquivalent: "")
            dev.isEnabled = false
            menu.addItem(dev)
            menu.addItem(item("Lend pet to a friend (export)…") { Dialogs.lend(engine) })
            menu.addItem(item("Borrow a pet (import)…") { Dialogs.borrow(engine) })
            menu.addItem(item("Time skip +1h") { engine.timeSkip(3600) })
            menu.addItem(item("Time skip +6h") { engine.timeSkip(6 * 3600) })
            menu.addItem(item("Starve to death (test)") {
                engine.model.hunger = 0
                engine.model.happiness = 0
                engine.model.everHatched = true
                engine.timeSkip(3 * 3600)
            })
            menu.addItem(toggle(
                "App self-destruct on death (prepared)",
                isOn: UserDefaults.standard.bool(forKey: GrimReaper.selfDestructDefaultsKey)
            ) {
                let key = GrimReaper.selfDestructDefaultsKey
                UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
            })
        }
        return menu
    }
}