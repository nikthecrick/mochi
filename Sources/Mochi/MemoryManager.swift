import Foundation

// Lightweight persistent memory for the brain.
// Design: two tools the brain writes (remember / update_identity) +
// automatic Swift-side care history. Injected as a compact ~120-token
// snippet into every system prompt; full file available via read_file.

struct CareReading: Codable {
    let date: Date
    let hunger: Double
    let happiness: Double
    let energy: Double
}

final class MemoryManager {
    private let memoryFile: URL
    private let careFile: URL

    private var careHistory: [CareReading] = []
    private var lastCareRecording: Date = .distantPast

    // Rolling note window and hourly care sampling
    private static let maxNotes    = 25
    private static let careEvery: TimeInterval = 3600   // 1 h
    private static let careWindow: TimeInterval = 7 * 24 * 3600  // 7 days

    init(sandboxURL: URL) {
        memoryFile = sandboxURL.appendingPathComponent("memory.md")
        careFile   = sandboxURL.appendingPathComponent(".care.json")
        loadCare()
        if !FileManager.default.fileExists(atPath: memoryFile.path) {
            initMemoryFile()
        }
    }

    // MARK: - Compact context snippet injected into every system prompt

    /// Returns a short multi-line string (~120 tokens max) summarising
    /// who the brain is, its recent notes, and how it's been treated.
    func contextSnippet(hunger: Double, happiness: Double, energy: Double) -> String {
        let (identity, notes) = readMemoryFile()
        var lines: [String] = []

        // Self-description (1 line, capped at 120 chars)
        let id = identity.isEmpty ? "(still figuring out who I am)" : identity
        lines.append("Self: \(String(id.prefix(120)))")

        // Last 5 notes (each capped at 60 chars)
        let recent = notes.suffix(5).map { String($0.prefix(60)) }
        if !recent.isEmpty {
            lines.append("Recent: " + recent.joined(separator: " · "))
        }

        // Care quality over last 24 h (auto-computed, not written by brain)
        lines.append("Care: " + careQuality(currentHunger: hunger, currentHappiness: happiness))

        return lines.joined(separator: "\n")
    }

    // MARK: - Tools the brain can call

    /// Append a brief timestamped note to the memory log.
    func appendNote(_ note: String) {
        let (identity, notes) = readMemoryFile()
        let fmt = DateFormatter(); fmt.dateFormat = "MM-dd HH:mm"
        var updated = notes + ["\(fmt.string(from: Date())) \(note.trimmingCharacters(in: .whitespaces))"]
        if updated.count > Self.maxNotes { updated = Array(updated.suffix(Self.maxNotes)) }
        writeMemoryFile(identity: identity, notes: updated)
    }

    /// Replace the brain's one-sentence self-description.
    func updateIdentity(_ text: String) {
        let (_, notes) = readMemoryFile()
        writeMemoryFile(identity: text.trimmingCharacters(in: .whitespaces), notes: notes)
    }

    // MARK: - Care history (Swift-managed, automatic)

    func recordCareIfNeeded(hunger: Double, happiness: Double, energy: Double) {
        guard Date().timeIntervalSince(lastCareRecording) >= Self.careEvery else { return }
        lastCareRecording = Date()
        careHistory.append(CareReading(date: Date(), hunger: hunger,
                                       happiness: happiness, energy: energy))
        let cutoff = Date().addingTimeInterval(-Self.careWindow)
        careHistory = careHistory.filter { $0.date > cutoff }
        saveCare()
    }

    // MARK: - Private helpers

    private func careQuality(currentHunger: Double, currentHappiness: Double) -> String {
        let readings = careHistory.suffix(24)
        guard !readings.isEmpty else { return "just getting started" }
        let avgH  = readings.map(\.hunger).reduce(0, +)    / Double(readings.count)
        let avgHp = readings.map(\.happiness).reduce(0, +) / Double(readings.count)
        var parts: [String] = []
        if avgH  < 35 { parts.append("often hungry") }
        else if avgH > 72 { parts.append("well-fed") }
        if avgHp < 35 { parts.append("often sad") }
        else if avgHp > 72 { parts.append("usually happy") }
        return parts.isEmpty ? "doing okay" : parts.joined(separator: ", ")
    }

    private func readMemoryFile() -> (identity: String, notes: [String]) {
        guard let content = try? String(contentsOf: memoryFile, encoding: .utf8) else {
            return ("", [])
        }
        var identity = ""
        var notes: [String] = []
        var inSection = ""
        for line in content.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t == "## Identity" { inSection = "identity"; continue }
            if t == "## Notes"    { inSection = "notes";    continue }
            if t.hasPrefix("##") { inSection = "";          continue }
            if inSection == "identity" && !t.isEmpty { identity = t }
            if inSection == "notes"    && !t.isEmpty { notes.append(t) }
        }
        return (identity, notes)
    }

    private func writeMemoryFile(identity: String, notes: [String]) {
        var out  = "# Mochi Memory\n\n"
        out += "## Identity\n"
        out += (identity.isEmpty ? "(still figuring out who I am)" : identity) + "\n\n"
        out += "## Notes\n"
        out += notes.joined(separator: "\n") + "\n"
        try? out.write(to: memoryFile, atomically: true, encoding: .utf8)
    }

    private func initMemoryFile() {
        writeMemoryFile(identity: "", notes: [])
    }

    private func loadCare() {
        guard let data = try? Data(contentsOf: careFile),
              let h = try? JSONDecoder().decode([CareReading].self, from: data) else { return }
        careHistory = h
    }

    private func saveCare() {
        guard let data = try? JSONEncoder().encode(careHistory) else { return }
        try? data.write(to: careFile)
    }
}
