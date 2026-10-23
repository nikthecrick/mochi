import Foundation
import AppKit
import SwiftUI
import CoreText

/// Press Start 2P (SIL OFL 1.1) — the retro pixel typeface,
/// shipped in Assets/fonts, bundled into the .app.
enum PixelFont {
    private static var loaded = false

    static func url() -> URL? {
        if let u = Bundle.main.url(forResource: "PressStart2P-Regular", withExtension: "ttf", subdirectory: "fonts") { return u }
        if let u = Bundle.main.url(forResource: "PressStart2P-Regular", withExtension: "ttf") { return u }
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidate = repo.appendingPathComponent("Assets/fonts/PressStart2P-Regular.ttf")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    static func register() {
        guard !loaded, let u = url() else { return }
        CTFontManagerRegisterFontsForURL(u as CFURL, CTFontManagerScope.process, nil)
        loaded = true
    }

    static func font(_ size: CGFloat) -> Font {
        register()
        return Font.custom("Press Start 2P", size: size)
    }
}