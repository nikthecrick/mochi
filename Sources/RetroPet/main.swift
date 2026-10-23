import Foundation
import AppKit

// RetroPet — a tiny desktop tamagotchi.
// Flags: --smoke (headless self-test), --dump-sprites (ASCII sprite preview),
//        --make-icon <out.png> [size], --dev (enables prepared/experimental menu).

let args = CommandLine.arguments
let flags = Set(args.dropFirst())

if flags.contains("--smoke") {
    let result = SmokeTest.run()
    exit(result == "SMOKE OK" ? 0 : 1)
}

if flags.contains("--dump-sprites") {
    print("palette: " + Pal.rgba.keys.sorted().map(String.init).joined(separator: " "))
    for f in Frame.allCases {
        print("\n== \(f.rawValue) ==")
        print(Sprites.ascii(f))
    }
    exit(0)
}

if let idx = args.firstIndex(of: "--make-icon") {
    let out = idx + 1 < args.count ? args[idx + 1] : "icon.png"
    let size = idx + 2 < args.count ? Int(args[idx + 2]) ?? 512 : 512
    if let data = IconMaker.pngData(size: size) {
        try! data.write(to: URL(fileURLWithPath: out))
        print("wrote \(out) (\(size)x\(size))")
        exit(0)
    }
    print("icon render failed")
    exit(1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()