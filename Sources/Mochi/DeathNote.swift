import Foundation
import AppKit

/// When the pet dies it is *really* dead: Mochi leaves a death note
/// (text + a sad little tombstone PNG) on the Desktop.
enum DeathNote {
    static var directoryOverride: URL?   // tests redirect this

    static func targetDirectory() -> URL {
        if let d = directoryOverride { return d }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    static func ageText(seconds: Double) -> String {
        let h = seconds / 3600
        if h >= 48 { return "\(Int(h / 24)) days" }
        if h >= 24 { return "1 day" }
        if h >= 1 { return "\(Int(h)) hours" }
        return "\(max(1, Int(seconds / 60))) minutes"
    }

    static func safeName(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return s.components(separatedBy: bad).joined(separator: "-")
    }

    static func text(for model: PetModel) -> String {
        let ageS = ageText(seconds: (model.diedAt ?? Date()).timeIntervalSince(model.bornAt))
        let cause = model.deathCause ?? "neglect"
        return """
          ________________________________

                     R  I  1  P
                  \(model.name)
                  a desktop tamagotchi

          lived: \(ageS)
          died of: \(cause)

          "I waited for you, and you didn't come.
           It really died. It is not coming back.
           Be there for your next one."
                       -- Mochi

          ________________________________
          This note was left by Mochi on
          \(Date().formatted(date: .long, time: .shortened)).
          """
    }

    @discardableResult
    static func write(for model: PetModel) -> (txt: URL?, png: URL?) {
        let dir = targetDirectory()
        let base = "RIP-\(safeName(model.name))"
        let txtURL = dir.appendingPathComponent(base + ".txt")
        let pngURL = dir.appendingPathComponent(base + ".png")
        var png: URL? = pngURL

        try? text(for: model).data(using: .utf8)?.write(to: txtURL, options: .atomic)
        if let data = PixelArt.pngData(frame: .tomb, pixels: 128, background: nil) {
            try? data.write(to: pngURL, options: .atomic)
        } else {
            png = nil
        }
        print("Mochi: death note written: \(txtURL.path)" + (png != nil ? " + tombstone.png" : ""))
        return (txtURL, png)
    }
}

/// Prepared for later ("death means the app is gone" mode). OFF by default.
/// Flip it later with:
///   defaults write dev.tryouts.retpet.Mochi Mochi.selfDestruct -bool YES
/// Then, on death, the .app bundle moves itself to the Trash.
enum GrimReaper {
    static let selfDestructDefaultsKey = "Mochi.selfDestruct"

    static var selfDestructEnabled: Bool {
        UserDefaults.standard.bool(forKey: selfDestructDefaultsKey)
    }

    static func selfDestruct() {
        guard selfDestructEnabled else { return }
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "app" else {
            print("Mochi: cleanup deferred — not running from a .app bundle.")
            return
        }
        print("Mochi: moving the app bundle to Trash (\(url.path))")
        NSWorkspace.shared.recycle([url]) { _, error in
            if let error = error { print("Mochi: recycle failed: \(error)") }
        }
    }
}