import SwiftUI
import AppKit

/// The real settings: a designed glass card in its own little window
/// next to the pet (not a right-click menu).
/// Retro (pixel headers) x modern (glass, pills, switches).
struct SettingsCard: View {
    @ObservedObject var engine: PetEngine
    @ObservedObject var sound: SoundBank
    var onClose: () -> Void
    var onFeedFile: () -> Void
    var onCleanToilet: () -> Void
    var onGivePool: () -> Void
    var onRemovePool: () -> Void
    var onLend: (() -> Void)? = nil
    var onBorrow: (() -> Void)? = nil

    @AppStorage(PetRates.digestDefaultsKey) private var digest: Double = 300
    @AppStorage(PetRates.walkChanceDefaultsKey) private var walkChance: Double = PetRates.defaultWalkChance

    private let w: CGFloat = 248

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            section("CARE") {
                row("carrot.fill", "Feed a snack", color: .orange) { engine.feed() }
                row("gamecontroller.fill", "Play", color: .pink) { engine.play() }
                row("zzz", engine.model.asleep ? "Wake up" : "Sleep", color: .indigo) { engine.toggleSleep() }
            }

            section("SOUND & CONTROLS") {
                switcher("Ambient music", isOn: $sound.musicOn)
                switcher("Sound effects", isOn: Binding(
                    get: { !sound.muted }, set: { sound.muted = !$0 }))
                switcher("Pin controls", isOn: $engine.controlsPinned)
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
                poolRow
            }

            section("PET") {
                row("pencil", "Rename…", color: .gray) { Dialogs.rename(engine) }
                row("sparkles", "New pet…", color: .pink) { Dialogs.newPet(engine) }
                row("power", "Quit RetroPet", color: .red) { NSApp.terminate(nil) }
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

    @ViewBuilder
    private var poolRow: some View {
        if engine.hasGadget {
            if engine.model.poolOwned == true {
                row("water.waves", "Remove the pool…", color: .blue) { onRemovePool() }
            } else {
                row("water.waves", "Give it a pool…", color: .blue) { onGivePool() }
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 16)
                Text("Pool: keep feeding to unlock…")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.38))
                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.clear))
        }
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