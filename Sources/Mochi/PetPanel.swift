import AppKit

/// The pet's home: a borderless, transparent, always-on-top panel that
/// floats above everything on every Space. Clicks on empty (transparent)
/// areas fall through to the desktop.
final class PetPanel: NSPanel {
    var onRightClick: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func rightMouseDown(with event: NSEvent) {
        if let fn = onRightClick { fn() } else { super.rightMouseDown(with: event) }
    }

    /// macOS normally keeps windows from crossing the menu-bar line
    /// (constrainFrameRect), which felt like an invisible wall ~70px
    /// above the pet (the sprite is centered in a 240px window with
    /// transparent headroom). No constraint here: dragging may push the
    /// window partially off-screen so the pet itself can reach the top.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    // Mochi runs as an .accessory app with no menu bar and no Edit menu.
    // Without a Paste menu item, Cmd+V never reaches the first responder
    // through the standard menu dispatch path and the system beeps.
    // We intercept the common text-editing shortcuts here and send them
    // directly into the responder chain so text fields work normally.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let ch = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }
        switch ch {
        case "v": if NSApp.sendAction(#selector(NSText.paste(_:)),      to: nil, from: nil) { return true }
        case "c": if NSApp.sendAction(#selector(NSText.copy(_:)),       to: nil, from: nil) { return true }
        case "x": if NSApp.sendAction(#selector(NSText.cut(_:)),        to: nil, from: nil) { return true }
        case "a": if NSApp.sendAction(#selector(NSText.selectAll(_:)),  to: nil, from: nil) { return true }
        default:  break
        }
        return super.performKeyEquivalent(with: event)
    }

    static func make() -> PetPanel {
        let p = PetPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 240),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.title = "Mochi"
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        // ^ one above the menu bar's status level: the pet can then be
        // dragged right to the top edge (the menu bar would otherwise
        // occlude it and feel like an invisible wall).
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.hasShadow = false               // the sprite draws its own soft shadow
        p.hidesOnDeactivate = false
        p.isMovable = false
        p.isMovableByWindowBackground = false
        p.animationBehavior = .utilityWindow
        return p
    }
}