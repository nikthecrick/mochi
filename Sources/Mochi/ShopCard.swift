import SwiftUI
import AppKit

/// The Mochi Shop — opened from the right-ear hotspot (unlocks with legs).
/// Two tabs: SHOP (upgrades) and GADGETS (physical items for the desktop).
struct ShopCard: View {
    @ObservedObject var engine: PetEngine
    var onClose: () -> Void
    var onGivePool: () -> Void = {}
    var onRemovePool: () -> Void = {}
    var onGiveBed: () -> Void = {}
    var onRemoveBed: () -> Void = {}
    var onGiveTree: () -> Void = {}
    var onRemoveTree: () -> Void = {}
    var onGiveSandbox: () -> Void = {}
    var onRemoveSandbox: () -> Void = {}

    @State private var tab: ShopTab = .shop

    private let w: CGFloat = 230

    enum ShopTab { case shop, gadgets }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            shopHeader
            tabPicker
            ScrollView(.vertical, showsIndicators: false) {
                switch tab {
                case .shop:    shopContent
                case .gadgets: gadgetsContent
                }
            }
            .frame(maxHeight: 280)
        }
        .padding(14)
        .frame(width: w, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: NSColor(red: 0.09, green: 0.08, blue: 0.16, alpha: 0.82)))
                .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20).stroke(
                LinearGradient(colors: [Color.purple.opacity(0.5), Color.blue.opacity(0.25)],
                               startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    // MARK: – sections

    @ViewBuilder
    private var shopContent: some View {
        section("AVAILABLE") { BrainItem(engine: engine) }
        section("COMING SOON") {
            lockedItem(icon: "globe",    name: "WEB SENSE", desc: "Let \(engine.model.name) browse the web")
            lockedItem(icon: "waveform", name: "VOICE",     desc: "Give \(engine.model.name) a voice")
            lockedItem(icon: "sparkles", name: "SKILLS",    desc: "More abilities, coming soon…")
        }
    }

    @ViewBuilder
    private var gadgetsContent: some View {
        section("GADGETS") {
            PoolItem(engine: engine, onGive: onGivePool, onRemove: onRemovePool)
            BedItem(engine: engine, onGive: onGiveBed, onRemove: onRemoveBed)
            TreeItem(engine: engine, onGive: onGiveTree, onRemove: onRemoveTree)
            SandboxItem(engine: engine, onGive: onGiveSandbox, onRemove: onRemoveSandbox)
        }
    }

    // MARK: – pieces

    private var shopHeader: some View {
        HStack(spacing: 7) {
            Text("✦")
                .font(PixelFont.font(10))
                .foregroundColor(shopPurple)
            Text("MOCHI SHOP")
                .font(PixelFont.font(9))
                .foregroundColor(shopPurple)
                .shadow(color: .purple.opacity(0.6), radius: 4)
            Spacer()
            Text("β")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .padding(.vertical, 2)
    }

    private var tabPicker: some View {
        HStack(spacing: 4) {
            tabButton("SHOP", .shop)
            tabButton("GADGETS", .gadgets)
            Spacer()
        }
    }

    private func tabButton(_ label: String, _ t: ShopTab) -> some View {
        let on = tab == t
        return Button { withAnimation(.easeOut(duration: 0.15)) { tab = t } } label: {
            Text(label)
                .font(PixelFont.font(6))
                .foregroundColor(on ? .black : .white.opacity(0.55))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(on ? shopPurple : Color.white.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(PixelFont.font(6))
                .foregroundColor(.white.opacity(0.38))
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
    }

    private func lockedItem(icon: String, name: String, desc: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.2))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(PixelFont.font(6))
                    .foregroundColor(.white.opacity(0.25))
                Text(desc)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.18))
            }
            Spacer()
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04)))
    }

    private var shopPurple: Color { Color(red: 0.88, green: 0.72, blue: 1.0) }
}

// MARK: – Brain item card

private struct BrainItem: View {
    @ObservedObject var engine: PetEngine
    @State private var flash = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                brainIcon
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("BRAIN")
                            .font(PixelFont.font(8))
                            .foregroundColor(.white)
                        Text("FREE BETA")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Color(red: 0.88, green: 0.72, blue: 1.0))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple.opacity(0.35)))
                    }
                    Text("An autonomous LLM mind for \(engine.model.name).")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            Text("Connects to any OpenAI-compatible LLM. Thinks on its own, writes notes in a private sandbox, and can send you little messages.")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                if engine.model.brainInstalled {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.5, green: 1.0, blue: 0.65))
                            .font(.system(size: 12))
                        Text("Installed — set API key in settings")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.55))
                    }
                } else {
                    Button {
                        withAnimation(.spring(response: 0.3)) { flash = true }
                        engine.model.brainInstalled = true
                        engine.save()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation { flash = false }
                        }
                    } label: {
                        Text(flash ? "✓ INSTALLED!" : "INSTALL")
                            .font(PixelFont.font(7))
                            .foregroundColor(.black)
                            .padding(.horizontal, 18).padding(.vertical, 7)
                            .background(
                                Capsule().fill(flash
                                    ? Color(red: 0.5, green: 1.0, blue: 0.65)
                                    : Color(red: 0.88, green: 0.72, blue: 1.0))
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3), value: flash)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.11)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.32)))
    }

    private var brainIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [Color(red: 0.42, green: 0.28, blue: 0.88),
                             Color(red: 0.6,  green: 0.18, blue: 0.80)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 38, height: 38)
            Image(systemName: "cpu.fill")
                .font(.system(size: 17))
                .foregroundColor(.white)
        }
        .shadow(color: .purple.opacity(0.5), radius: 5)
    }
}

// MARK: – Pool item card

private struct PoolItem: View {
    @ObservedObject var engine: PetEngine
    var onGive: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                poolIcon
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("POOL")
                            .font(PixelFont.font(8))
                            .foregroundColor(.white)
                        if engine.model.poolOwned == true {
                            Text("PLACED")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Color(red: 0.5, green: 0.85, blue: 1.0))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(Color.cyan.opacity(0.25)))
                        }
                    }
                    Text("A pixel pond \(engine.model.name) will visit for a dip.")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            if engine.hasGadget {
                Text("Drag it anywhere on your desktop. \(engine.model.name) will stroll over whenever they feel like a swim.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    if engine.model.poolOwned == true {
                        Button { onRemove() } label: {
                            Text("REMOVE")
                                .font(PixelFont.font(7))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { onGive() } label: {
                            Text("PLACE POOL")
                                .font(PixelFont.font(7))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Capsule().fill(Color(red: 0.5, green: 0.85, blue: 1.0)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("Keep feeding \(engine.model.name) to unlock the gadget stage.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.42))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.cyan.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            engine.hasGadget ? Color.cyan.opacity(0.28) : Color.white.opacity(0.08)))
    }

    private var poolIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [Color(red: 0.22, green: 0.52, blue: 0.88),
                             Color(red: 0.14, green: 0.36, blue: 0.72)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 38, height: 38)
            PixelSpriteView(frame: .pool, scale: 2.0)
        }
        .shadow(color: Color.cyan.opacity(0.4), radius: 5)
    }
}

// MARK: – Cozy Bed item card

private struct BedItem: View {
    @ObservedObject var engine: PetEngine
    var onGive: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                bedIcon
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("COZY BED")
                            .font(PixelFont.font(8))
                            .foregroundColor(.white)
                        if engine.model.bedOwned == true {
                            Text("PLACED")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Color(red: 1.0, green: 0.80, blue: 0.55))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange.opacity(0.25)))
                        }
                    }
                    Text("Drop \(engine.model.name) on it for a deep cozy nap.")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            if engine.hasGadget {
                Text("Drag it anywhere on your desktop. Drop \(engine.model.name) on the bed for a deep nap with big Zzz.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    if engine.model.bedOwned == true {
                        Button { onRemove() } label: {
                            Text("REMOVE")
                                .font(PixelFont.font(7))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { onGive() } label: {
                            Text("PLACE BED")
                                .font(PixelFont.font(7))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Capsule().fill(Color(red: 1.0, green: 0.80, blue: 0.55)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("Keep feeding \(engine.model.name) to unlock the gadget stage.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.42))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            engine.hasGadget ? Color.orange.opacity(0.28) : Color.white.opacity(0.08)))
    }

    private var bedIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [Color(red: 0.84, green: 0.62, blue: 0.42),
                             Color(red: 0.68, green: 0.44, blue: 0.24)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 38, height: 38)
            PixelSpriteView(frame: .bed, scale: 2.0)
        }
        .shadow(color: Color.orange.opacity(0.4), radius: 5)
    }
}

// MARK: – Snack Tree item card

private struct TreeItem: View {
    @ObservedObject var engine: PetEngine
    var onGive: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                treeIcon
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("SNACK TREE")
                            .font(PixelFont.font(8))
                            .foregroundColor(.white)
                        if engine.model.treeOwned == true {
                            Text("PLACED")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Color(red: 0.60, green: 1.0, blue: 0.55))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.25)))
                        }
                    }
                    Text("\(engine.model.name) walks over when hungry for snacks.")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            if engine.hasGadget {
                Text("When \(engine.model.name) is hungry they'll stroll over — snacks fall from the branches right into their mouth.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    if engine.model.treeOwned == true {
                        Button { onRemove() } label: {
                            Text("REMOVE")
                                .font(PixelFont.font(7))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { onGive() } label: {
                            Text("PLACE TREE")
                                .font(PixelFont.font(7))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Capsule().fill(Color(red: 0.60, green: 0.90, blue: 0.55)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("Keep feeding \(engine.model.name) to unlock the gadget stage.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.42))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            engine.hasGadget ? Color.green.opacity(0.28) : Color.white.opacity(0.08)))
    }

    private var treeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [Color(red: 0.30, green: 0.68, blue: 0.28),
                             Color(red: 0.18, green: 0.52, blue: 0.18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 38, height: 38)
            PixelSpriteView(frame: .tree, scale: 2.0)
        }
        .shadow(color: Color.green.opacity(0.4), radius: 5)
    }
}

private struct SandboxItem: View {
    @ObservedObject var engine: PetEngine
    var onGive: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                sandboxIcon
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("SANDBOX")
                            .font(PixelFont.font(8))
                            .foregroundColor(.white)
                        if engine.model.sandboxOwned == true {
                            Text("PLACED")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.40))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(Color.yellow.opacity(0.25)))
                        }
                    }
                    Text("Play with other Mochis nearby via MultipeerConnectivity.")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            if engine.hasGadget {
                Text("Place the sandbox to discover nearby Mochi owners. Tap a friend's icon to share your Mochi — they appear as a guest and yours walks over to play.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    if engine.model.sandboxOwned == true {
                        Button { onRemove() } label: {
                            Text("REMOVE")
                                .font(PixelFont.font(7))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { onGive() } label: {
                            Text("PLACE SANDBOX")
                                .font(PixelFont.font(7))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Capsule().fill(Color(red: 0.98, green: 0.87, blue: 0.42)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("Keep feeding \(engine.model.name) to unlock the gadget stage.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.42))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.yellow.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            engine.hasGadget ? Color.yellow.opacity(0.28) : Color.white.opacity(0.08)))
    }

    private var sandboxIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [Color(red: 0.95, green: 0.82, blue: 0.40),
                             Color(red: 0.80, green: 0.65, blue: 0.25)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 38, height: 38)
            PixelSpriteView(frame: .sandbox, scale: 2.0)
        }
        .shadow(color: Color.yellow.opacity(0.4), radius: 5)
    }
}
