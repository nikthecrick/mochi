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