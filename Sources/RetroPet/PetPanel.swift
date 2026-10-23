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

    static func make() -> PetPanel {
        let p = PetPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 240),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.title = "RetroPet"
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.hasShadow = false               // the sprite draws its own soft shadow
        p.hidesOnDeactivate = false
        p.isMovable = false
        p.isMovableByWindowBackground = false
        p.animationBehavior = .utilityWindow
        return p
    }
}