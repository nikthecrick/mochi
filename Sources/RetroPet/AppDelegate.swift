import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = PetEngine()
    private let sound = SoundBank()
    private var panel: PetPanel?
    private var poolPanel: PetPanel?
    private var settingsPanel: PetPanel?
    private var activity: NSObjectProtocol?
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PixelFont.register()

        // H key (egg visible): instant hatch — the testing cheat.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let self,
               event.charactersIgnoringModifiers?.lowercased() == "h",
               !self.engine.model.everHatched,
               !self.engine.model.dead {
                self.engine.forceHatch()
            }
            return event
        }

        engine.sound = sound
        engine.devMode = Set(CommandLine.arguments.dropFirst()).contains("--dev")
        engine.onDeath = { [weak self] model in
            self?.sound.play(.death)
            self?.sound.setAmbient(false)          // sad moment: no jingles
            DeathNote.write(for: model)           // txt + tombstone png on Desktop
            GrimReaper.selfDestruct()              // prepared, off by default
        }
        engine.onEatFile = { [weak self] url in
            self?.trashFile(url)
        }

        if let loaded = PetStore.load() {
            engine.adopt(loaded: loaded)          // catch up decay while away (may die here)
        } else {
            engine.newPet()                       // first launch: egg
        }
        engine.tick()

        let p = PetPanel.make()
        panel = p
        p.onRightClick = { [weak self] in self?.popupMenu() }   // right-click anywhere on the panel
        p.contentView = NSHostingView(rootView: PetRootView(
            engine: engine,
            sound: sound,
            dragDelta: { [weak self] dx, dy in self?.dragWindow(dx: dx, dy: dy) },
            settle: { [weak self] in self?.settleWindow() },
            popMenu: { [weak self] in self?.popupMenu() },
            moveWindow: { [weak self] dx, dy in self?.movePetWindow(dx: dx, dy: dy) }
        ))
        p.setFrame(defaultWindowFrame(), display: true)
        p.orderFrontRegardless()
        engine.petPos = centre(of: p.frame)

        engine.start()
        if sound.musicOn { sound.applyMusic() }   // didSet doesn't fire during init

        // restore a previously placed pool
        if engine.model.poolOwned == true { givePool(restore: true) }

        // Don't let App Nap pause the pet's heartbeat.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "RetroPet keeps ticking so the pet ages in real time")
    }

    private func defaultWindowFrame() -> NSRect {
        let size = NSSize(width: 280, height: 240)
        var origin = NSPoint(x: engine.model.windowX, y: engine.model.windowY)
        if origin.x < 0 || origin.y < 0 {
            let vis = NSScreen.main?.visibleFrame ?? NSRect(x: 120, y: 120, width: 1280, height: 800)
            origin = NSPoint(x: vis.midX - size.width / 2, y: vis.midY + vis.height * 0.08)
        }
        let candidate = NSRect(origin: origin, size: size)
        var onScreen = false
        for s in NSScreen.screens where NSIntersectsRect(s.frame, candidate) { onScreen = true; break }
        if !onScreen {
            let vis = NSScreen.main?.visibleFrame ?? candidate
            origin = NSPoint(x: vis.midX - size.width / 2, y: vis.midY - size.height / 2)
        }
        return NSRect(origin: origin, size: size)
    }

    // Native drag: screen-space deltas, direct setFrameOrigin -> no flicker.
    private func dragWindow(dx: CGFloat, dy: CGFloat) {
        guard let p = panel else { return }
        var o = p.frame.origin
        o.x += dx
        o.y += dy
        p.setFrameOrigin(o)
        engine.petPos = centre(of: p.frame)
    }

    private func settleWindow() {
        guard let p = panel else { return }
        engine.savePosition(x: p.frame.origin.x, y: p.frame.origin.y)
    }

    private func popupMenu() {
        showSettings()
    }

    // MARK: - settings card

    /// The designed settings: a glass card in its own little window,
    /// placed just right of the pet. Toggles closed when open.
    private func showSettings() {
        if let p = settingsPanel {
            if p.isVisible { p.orderOut(nil); return }
            placeSettings(p)
            p.orderFrontRegardless()
            return
        }
        let hosting = NSHostingView(rootView: SettingsCard(
            engine: engine,
            sound: sound,
            onClose: { [weak self] in self?.settingsPanel?.orderOut(nil) },
            onFeedFile: { [weak self] in
                self?.settingsPanel?.orderOut(nil)
                Dialogs.eatFilePicker(self?.engine ?? PetEngine())
            },
            onCleanToilet: { [weak self] in
                self?.settingsPanel?.orderOut(nil)
                self?.emptyTrash()
            },
            onGivePool: { [weak self] in
                self?.settingsPanel?.orderOut(nil)
                self?.givePool()
            },
            onRemovePool: { [weak self] in
                self?.settingsPanel?.orderOut(nil)
                self?.removePool()
            },
            onLend: engine.devMode ? { [weak self] in
                self?.settingsPanel?.orderOut(nil)
                Dialogs.lend(self?.engine ?? PetEngine())
            } : nil,
            onBorrow: engine.devMode ? { [weak self] in
                self?.settingsPanel?.orderOut(nil)
                Dialogs.borrow(self?.engine ?? PetEngine())
            } : nil
        ))
        let p = PetPanel.make()
        p.contentView = hosting
        settingsPanel = p
        placeSettings(p)
        p.orderFrontRegardless()
    }

    private func placeSettings(_ p: PetPanel) {
        guard let pet = panel,
              let hosting = p.contentView as? NSHostingView<SettingsCard> else { return }
        hosting.invalidateIntrinsicContentSize()
        let size = hosting.fittingSize.width > 10 ? hosting.fittingSize : NSSize(width: 248, height: 420)
        var o = NSPoint(x: pet.frame.maxX + 14, y: pet.frame.maxY - size.height)
        if let vis = NSScreen.main?.visibleFrame {
            o.x = min(max(vis.minX, o.x), vis.maxX - size.width)
            o.y = min(max(vis.minY, o.y), vis.maxY - size.height)
        }
        p.setFrame(NSRect(origin: o, size: size), display: true)
    }

    /// Wander: the pet's window really walks across the screen (both axes),
    /// clamped to the visible area; hitting an edge turns it around.
    private func movePetWindow(dx: Double, dy: Double) {
        guard let p = panel, dx != 0 || dy != 0 else { return }
        var o = p.frame.origin
        o.x += CGFloat(dx)
        o.y += CGFloat(dy)
        var clamped = false
        if let vis = NSScreen.main?.visibleFrame {
            let minX = vis.minX, maxX = vis.maxX - p.frame.width
            let minY = vis.minY, maxY = vis.maxY - p.frame.height
            if o.x < minX { o.x = minX; clamped = true }
            if o.x > maxX { o.x = maxX; clamped = true }
            if o.y < minY { o.y = minY; clamped = true }
            if o.y > maxY { o.y = maxY; clamped = true }
        }
        p.setFrameOrigin(o)
        engine.petPos = centre(of: p.frame)
        if clamped { engine.turnAround() }   // sniffed the edge, strolls back
    }

    private func centre(of f: NSRect) -> (x: Double, y: Double) {
        (Double(f.midX), Double(f.midY))
    }

    // MARK: - pool

    /// Place the pixel pool (its own little draggable window).
    func givePool(restore: Bool = false) {
        guard poolPanel == nil, engine.hasGadget else { return }
        let size = NSSize(width: 110, height: 110)
        let p = PetPanel.make()
        p.setFrame(poolFrame(size: size), display: true)
        p.contentView = NSHostingView(rootView: PoolRootView(
            engine: engine,
            dragDelta: { [weak self] dx, dy in self?.dragPool(dx: dx, dy: dy) },
            settle: { [weak self] in self?.settlePool() },
            popMenu: { [weak self] in self?.popupPoolMenu() }
        ))
        p.orderFrontRegardless()
        poolPanel = p
        engine.model.poolOwned = true
        engine.petPos = centre(of: panel?.frame ?? .zero)
        engine.save()
        if !restore { print("RetroPet: pool placed — drag it anywhere; the pet will find it") }
    }

    private func poolFrame(size: NSSize) -> NSRect {
        if engine.model.poolX >= 0, engine.model.poolY >= 0 {
            return NSRect(x: engine.model.poolX - size.width / 2,
                          y: engine.model.poolY - size.height / 2,
                          width: size.width, height: size.height)
        }
        // default: right next to the pet
        let pet = panel?.frame ?? NSRect(x: 200, y: 400, width: 280, height: 240)
        var o = NSPoint(x: pet.maxX + 20, y: pet.minY + 60)
        if let vis = NSScreen.main?.visibleFrame {
            o.x = min(max(vis.minX, o.x), vis.maxX - size.width)
            o.y = min(max(vis.minY, o.y), vis.maxY - size.height)
        }
        return NSRect(origin: o, size: size)
    }

    private func dragPool(dx: CGFloat, dy: CGFloat) {
        guard let p = poolPanel else { return }
        var o = p.frame.origin
        o.x += dx
        o.y += dy
        p.setFrameOrigin(o)
    }

    private func settlePool() {
        guard let p = poolPanel else { return }
        engine.model.poolX = Double(p.frame.midX)
        engine.model.poolY = Double(p.frame.midY)
        engine.save()
    }

    private func popupPoolMenu() {
        let menu = NSMenu()
        let remove = NSMenuItem(title: "Remove the pool", action: nil, keyEquivalent: "")
        let h = PetMenu.Handler { [weak self] in self?.removePool() }
        objc_setAssociatedObject(menu, &PetMenu.assocKey, h, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        remove.target = h
        remove.action = #selector(PetMenu.Handler.fire)
        menu.addItem(remove)
        menu.addItem(NSMenuItem(title: "Never mind", action: nil, keyEquivalent: ""))
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func removePool() {
        poolPanel?.close()
        poolPanel = nil
        engine.model.poolOwned = false
        engine.save()
        print("RetroPet: pool removed")
    }

    /// Clean the toilet = empty the Trash (the pet refills it as it eats).
    private func emptyTrash() {
        let script = NSAppleScript(source: "tell application \"Finder\" to empty trash")
        var err: NSDictionary?
        script?.executeAndReturnError(&err)
        if err == nil {
            sound.play(.poop)
            print("RetroPet: toilet flushed — Trash emptied")
        } else {
            print("RetroPet: emptying the Trash failed: \(String(describing: err))")
            Dialogs.fail(NSError(domain: "RetroPet", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Couldn't empty the Trash (allow Finder automation when asked, or empty it manually)."
            ]))
        }
    }

    /// Fed files go to the Trash (recoverable), not /dev/null.
    private func trashFile(_ url: URL) {
        NSWorkspace.shared.recycle([url]) { trashed, error in
            if let error = error {
                print("RetroPet: couldn't trash \(url.lastPathComponent): \(error)")
            } else {
                print("RetroPet: \(url.lastPathComponent) -> Trash")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.save()
    }
}