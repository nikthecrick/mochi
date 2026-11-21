import AppKit

/// Generates dream images from Pollinations.ai when Mochi sleeps.
/// No API key required — just a URL fetch.
final class DreamEngine {
    weak var pet: PetEngine?

    private var isGenerating = false
    private let sandboxURL: URL

    // Dreamy prompts — varied so each sleep feels different.
    // The brain can override by writing a prompt to sandbox/dream.txt.
    private let themes = [
        "cute pink bunny floating through cosmos with colorful stars and nebulas, dreamy pastel art",
        "tiny fluffy bunny swimming in an ocean made of clouds, magical watercolor illustration",
        "small pink rabbit in an enchanted forest with glowing mushrooms and fireflies, fantasy art",
        "bunny astronaut floating in space with colorful planets and rockets, cute kawaii illustration",
        "fluffy bunny sleeping on a giant crescent moon surrounded by stars, dreamy pastel",
        "cute rabbit running through a field of oversized candy and sweets, vibrant pop art",
        "tiny bunny riding a shooting star through the aurora borealis, watercolor painting",
        "pink bunny floating inside a giant soap bubble with rainbows, magical realism",
        "cute rabbit discovering a tiny glowing door in a tree trunk, whimsical storybook",
        "fluffy bunny dancing with fireflies in a summer meadow at night, dreamy illustration",
        "bunny surfing a giant wave made of cherry blossoms, japanese art style",
        "tiny rabbit in a hot air balloon over a miniature city at sunset, dreamy",
        "cute bunny swimming with gentle glowing jellyfish in deep ocean, bioluminescent",
        "small rabbit building a cozy nest out of stars and moonlight, fantasy illustration",
        "fluffy bunny chasing butterflies through a field of giant flowers, vibrant dreamscape",
    ]

    init(sandboxURL: URL) {
        self.sandboxURL = sandboxURL
    }

    func generateDream() async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        await MainActor.run { pet?.dreamLoading = true }

        let prompt = brainPrompt() ?? themes.randomElement()!
        print("Mochi dream: generating — \(prompt.prefix(60))…")

        let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? prompt
        guard let url = URL(string: "https://image.pollinations.ai/prompt/\(encoded)?width=256&height=256&nologo=true&model=flux") else {
            await MainActor.run { pet?.dreamLoading = false }
            return
        }

        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 90
            config.timeoutIntervalForResource = 90
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(from: url)
            if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
                print("Mochi dream: HTTP \(status)")
                await MainActor.run { pet?.dreamLoading = false }
                return
            }
            guard let image = NSImage(data: data) else {
                print("Mochi dream: could not decode image (\(data.count) bytes)")
                await MainActor.run { pet?.dreamLoading = false }
                return
            }
            await MainActor.run {
                pet?.dreamLoading = false
                pet?.dreamImage = image
            }
            print("Mochi dream: image ready (\(data.count) bytes)")
        } catch {
            print("Mochi dream: failed — \(error.localizedDescription)")
            await MainActor.run { pet?.dreamLoading = false }
        }
    }

    func clearDream() {
        Task { @MainActor in
            pet?.dreamImage = nil
            pet?.dreamLoading = false
        }
    }

    // If the brain wrote a custom dream prompt, use it (then delete so it doesn't repeat)
    private func brainPrompt() -> String? {
        let file = sandboxURL.appendingPathComponent("dream.txt")
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        try? FileManager.default.removeItem(at: file)
        return trimmed
    }
}
