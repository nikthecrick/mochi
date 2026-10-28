import AppKit
import UniformTypeIdentifiers

/// AppKit dialogs (SwiftUI context menu can't do text fields / save panels).
enum Dialogs {
    @discardableResult
    static func confirm(_ message: String, button: String = "OK") -> Bool {
        let a = NSAlert()
        a.messageText = message
        a.addButton(withTitle: button)
        a.addButton(withTitle: "Cancel")
        return a.runModal() == .alertFirstButtonReturn
    }

    static func fail(_ error: Error) {
        let a = NSAlert(error: error)
        a.runModal()
    }

    static func rename(_ engine: PetEngine) {
        let a = NSAlert()
        a.messageText = "Rename your pet"
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Cancel")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        tf.stringValue = engine.model.name
        a.accessoryView = tf
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let name = tf.stringValue.trimmingCharacters(in: .whitespaces)
        engine.rename(name)
    }

    static func newPet(_ engine: PetEngine) {
        guard confirm("Say goodbye to \(engine.model.name) and start a new pet?", button: "New Pet") else { return }
        engine.newPet()
    }

    /// Feed the pet real files: they get eaten (moved to the Trash).
    static func eatFilePicker(_ engine: PetEngine) {
        let p = NSOpenPanel()
        p.canChooseFiles = true
        p.canChooseDirectories = true
        p.allowsMultipleSelection = true
        p.message = "\(engine.model.name) will eat these — they are moved to the Trash."
        guard p.runModal() == .OK, !p.urls.isEmpty else { return }
        for u in p.urls { engine.feedFile(url: u) }
    }

    // Prepared: borrow-pet file dialogs (visible under --dev for now)
    static func lend(_ engine: PetEngine) {
        let p = NSSavePanel()
        p.nameFieldStringValue = "\(DeathNote.safeName(engine.model.name)).\(BorrowManager.fileExtension)"
        p.allowedContentTypes = [BorrowManager.contentType]
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            try BorrowManager.export(engine.model, to: url)
            print("Mochi: lent \(engine.model.name) -> \(url.path)")
        } catch { fail(error) }
    }

    static func borrow(_ engine: PetEngine) {
        let p = NSOpenPanel()
        p.allowedContentTypes = [BorrowManager.contentType]
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            let pet = try BorrowManager.importPet(at: url)
            engine.adopt(loaded: pet)
            engine.tick()   // catch up decay since export
        } catch { fail(error) }
    }
}