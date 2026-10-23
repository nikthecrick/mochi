import Foundation
import AVFoundation
import Combine

/// All audio is CC0 from Kenney (kenney.nl):
///   - "Interface Sounds", "Digital Audio", "RPG Audio", "Music Jingles (8-Bit)"
/// converted to WAV (16-bit PCM) in Assets/sounds.
final class SoundBank: ObservableObject {
    enum Sfx: String, CaseIterable {
        case feed, play, pat, sleep, wake, death, hatch, click, poop, jump
    }

    @Published var musicOn: Bool {
        didSet {
            UserDefaults.standard.set(musicOn, forKey: "RetroPet.musicOn")
            applyMusic()
        }
    }
    @Published var muted: Bool {
        didSet {
            UserDefaults.standard.set(muted, forKey: "RetroPet.muted")
            if muted { stopAmbient() }
        }
    }
    /// No ambient music while the pet is dead. Sad moment.
    var ambientAllowed = true

    private var sfx: [Sfx: AVAudioPlayer] = [:]
    private var jingles: [AVAudioPlayer] = []
    private var jingleTimer: Timer?

    init() {
        // (assignments in init do not fire didSet)
        musicOn = (UserDefaults.standard.object(forKey: "RetroPet.musicOn") as? Bool) ?? true
        muted = (UserDefaults.standard.object(forKey: "RetroPet.muted") as? Bool) ?? false

        for s in Sfx.allCases {
            if let u = SoundBank.soundURL(s.rawValue), let p = try? AVAudioPlayer(contentsOf: u) {
                p.volume = 0.55
                p.prepareToPlay()
                sfx[s] = p
            }
        }
        for name in ["jingle00", "jingle01", "jingle05", "jingle07", "jingle12", "jingle13"] {
            if let u = SoundBank.soundURL(name), let p = try? AVAudioPlayer(contentsOf: u) {
                p.volume = 0.22
                p.prepareToPlay()
                jingles.append(p)
            }
        }
    }

    func play(_ s: Sfx) {
        guard !muted, let p = sfx[s] else { return }
        p.currentTime = 0
        p.volume = 0.55
        p.play()
    }

    // Ambient: a random 8-bit j every 10-20s (Animal-Crossing-ish, not a tight loop)
    func setAmbient(_ allowed: Bool) {
        ambientAllowed = allowed
        applyMusic()
    }

    func applyMusic() {
        if musicOn, !muted, ambientAllowed, !jingles.isEmpty {
            playNextJingle()
        } else {
            stopAmbient()
        }
    }

    private func playNextJingle() {
        jingleTimer?.invalidate()
        guard let p = jingles.randomElement() else { return }
        p.currentTime = 0
        p.volume = 0.22
        p.play()
        let next = p.duration + Double.random(in: 9...18)
        jingleTimer = Timer.scheduledTimer(withTimeInterval: next, repeats: false) { [weak self] _ in
            self?.playNextJingle()
        }
    }

    private func stopAmbient() {
        jingleTimer?.invalidate()
        jingleTimer = nil
        jingles.forEach { $0.stop() }
    }

    // Resource lookup: bundled .app first, then repo Assets/ (for `swift run`).
    static func soundURL(_ name: String) -> URL? {
        if let u = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "sounds") { return u }
        if let u = Bundle.main.url(forResource: name, withExtension: "wav") { return u }
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidate = repo.appendingPathComponent("Assets/sounds/\(name).wav")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}