import SwiftUI
import AppKit

/// The real settings: a designed glass card in its own little window
/// next to the pet (not a right-click menu).
/// Retro (pixel headers) x modern (glass, pills, switches).
struct SettingsCard: View {
    @ObservedObject var engine: PetEngine
    @ObservedObject var brain: BrainEngine
    @ObservedObject var sound: SoundBank
    var onClose: () -> Void
    var onFeedFile: () -> Void
    var onCleanToilet: () -> Void
    var onLend: (() -> Void)? = nil
    var onBorrow: (() -> Void)? = nil
    var onPlay: () -> Void = {}

    @AppStorage(PetRates.digestDefaultsKey) private var digest: Double = 300
    @AppStorage(PetRates.walkChanceDefaultsKey) private var walkChance: Double = PetRates.defaultWalkChance
    @AppStorage("Mochi.showMode") private var showMode = "ear"   // hover | ear

    // Brain config (read by BrainEngine at think-time via the same UserDefaults keys)
    @AppStorage(BrainKeys.apiKey)         private var brainApiKey    = ""
    @AppStorage(BrainKeys.endpoint)       private var brainEndpoint  = ""
    @AppStorage(BrainKeys.modelID)        private var brainModel     = ""
    @AppStorage(BrainKeys.intervalMin)    private var brainInterval  = BrainEngine.defaultInterval
    @AppStorage(BrainKeys.bubbleFontSize) private var bubbleFontSize = 14.0
    @State private var showKey = false

    private let w: CGFloat = 248

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            section("CARE") {
                row("carrot.fill", "Feed a snack", color: .orange) { engine.feed() }
                row("gamecontroller.fill", "Play", color: .pink) { onPlay() }
                row("zzz", engine.model.asleep ? "Wake up" : "Sleep", color: .indigo) { engine.toggleSleep() }
            }

            section("CONTROLS APPEAR") {
                pillStrings([("On hover", "hover"), ("On left ear", "ear")], $showMode)
                if showMode == "ear" {
                    Text("click the pet's left ear to show / hide the controls")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            section("SOUND & CONTROLS") {
                switcher("Music on", isOn: Binding<Bool>(
                    get: { sound.musicOn },
                    set: { sound.musicOn = $0 }))
                switcher("Sound effects on", isOn: Binding<Bool>(
                    get: { !sound.muted },
                    set: { sound.muted = !$0 }))
            }

            section("POOP TIMING") {
                pills([("Soon", 60), ("Normal", 300), ("Seldom", 900), ("Never", 0)], $digest)
            }

            section("WANDERING") {
                pills([("Often", 0.03), ("Normal", PetRates.defaultWalkChance),
                       ("Seldom", 0.000283), ("Never", 0)], $walkChance)
            }

            section("FILES") {
                row("doc.on.doc.fill", "Feed with a file…", color: .teal) { onFeedFile() }
                row("trash.fill", "Clean toilet (empty Trash)…", color: .gray) { onCleanToilet() }
            }

            if engine.model.brainInstalled { brainSection }

            section("PET") {
                row("pencil", "Rename…", color: .gray) { Dialogs.rename(engine) }
                row("sparkles", "New pet…", color: .pink) { Dialogs.newPet(engine) }
                row("power", "Quit Mochi", color: .red) { NSApp.terminate(nil) }
            }

            if engine.devMode {
                section("DEV — PREPARED") {
                    row("arrow.up.arrow.down", "Lend pet to a friend…", color: .purple) { onLend?() }
                    row("arrow.down.arrow.up", "Borrow a pet…", color: .purple) { onBorrow?() }
                    row("clock.arrow.circlepath", "Time skip +1h", color: .gray) { engine.timeSkip(3600) }
                    row("clock.badge.xmark", "Time skip +6h", color: .gray) { engine.timeSkip(6 * 3600) }
                    row("flame", "Starve to death (test)", color: .red) {
                        engine.model.hunger = 0
                        engine.model.happiness = 0
                        engine.model.everHatched = true
                        engine.timeSkip(3 * 3600)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: w, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: NSColor(red: 0.13, green: 0.12, blue: 0.17, alpha: 0.72)))
                .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.14)))
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .padding(10)
            .help("Close")
        }
    }

    // MARK: pieces

    @ViewBuilder
    private var brainSection: some View {
        section("BRAIN") {
            // API key — uses native NSTextField so paste (Cmd+V) works in the floating panel
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.purple)
                    .frame(width: 16)
                PasteableTextField(
                    text: $brainApiKey,
                    placeholder: "API key (openrouter.ai / local)",
                    isSecure: !showKey
                )
                .frame(maxWidth: .infinity)
                Button { showKey.toggle() } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))

            // Endpoint
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 16)
                PasteableTextField(
                    text: $brainEndpoint,
                    placeholder: BrainEngine.defaultEndpoint
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))

            // Model
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.yellow)
                    .frame(width: 16)
                PasteableTextField(
                    text: $brainModel,
                    placeholder: BrainEngine.defaultModel
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))

            // Think interval
            HStack(spacing: 0) {
                Text("Think every")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.trailing, 7)
                pills([("2 min", 2.0), ("5 min", 5.0), ("15 min", 15.0), ("30 min", 30.0)],
                      $brainInterval)
            }

            // Speech bubble font size
            HStack(spacing: 0) {
                Text("Bubble text")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.trailing, 7)
                pills([("S", 10.0), ("M", 14.0), ("L", 18.0), ("XL", 22.0)], $bubbleFontSize)
            }

            // Connection status + test button
            HStack(spacing: 7) {
                connectionDot
                connectionLabel
                Spacer()
                Button {
                    Task { await brain.testConnection() }
                } label: {
                    Text(brain.connectionStatus == .testing ? "Testing…" : "Test")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .disabled(brain.connectionStatus == .testing || brainApiKey.isEmpty)
            }

            Text("Get a free key at openrouter.ai · or point to a local server")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.3))
        }
    }

    @ViewBuilder
    private var connectionDot: some View {
        switch brain.connectionStatus {
        case .unknown:
            Circle().fill(Color.white.opacity(0.2)).frame(width: 7, height: 7)
        case .testing:
            Circle().fill(Color.yellow).frame(width: 7, height: 7)
                .opacity(1)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                           value: brain.connectionStatus)
        case .ok:
            Circle().fill(Color.green).frame(width: 7, height: 7)
        case .failed:
            Circle().fill(Color.red).frame(width: 7, height: 7)
        }
    }

    @ViewBuilder
    private var connectionLabel: some View {
        switch brain.connectionStatus {
        case .unknown:
            Text("Not tested")
                .font(.system(size: 9)).foregroundColor(.white.opacity(0.3))
        case .testing:
            Text("Connecting…")
                .font(.system(size: 9)).foregroundColor(.yellow.opacity(0.8))
        case .ok(let model):
            Text(model)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.green.opacity(0.9))
                .lineLimit(1).truncationMode(.middle)
        case .failed(let msg):
            Text(msg)
                .font(.system(size: 9)).foregroundColor(.red.opacity(0.85))
                .lineLimit(2)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            PixelSpriteView(frame: .idleA, scale: 2.2, overrides: engine.breedOverrides)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(engine.model.name)
                    .font(PixelFont.font(8))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                Text("the \(engine.breed.name.lowercased()) · age \(ageString(engine.age))")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer(minLength: 26)
        }
        .padding(.vertical, 2)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(PixelFont.font(6))
                .foregroundColor(.white.opacity(0.42))
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
    }

    private func row(_ icon: String, _ title: String, color: Color,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.92))
                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.05)))
        }
        .buttonStyle(HoverPress())
    }

    private func switcher(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.92))
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
    }

    private func pills(_ options: [(String, Double)], _ value: Binding<Double>) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { pair in
                let on = abs(value.wrappedValue - pair.element.1) < 0.000001
                Button {
                    value.wrappedValue = pair.element.1
                } label: {
                    Text(pair.element.0)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(on ? .black : .white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(on ? Color.white : Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pillStrings(_ options: [(String, String)], _ value: Binding<String>) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { pair in
                let on = value.wrappedValue == pair.element.1
                Button {
                    value.wrappedValue = pair.element.1
                } label: {
                    Text(pair.element.0)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(on ? .black : .white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(on ? Color.white : Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Rows brighten on hover, press down a touch.
struct HoverPress: ButtonStyle {
    @State private var hot = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.white.opacity(hot ? 0.13 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.white.opacity(hot ? 0.14 : 0.05))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .onHover { hot = $0 }
    }
}