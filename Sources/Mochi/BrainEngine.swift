import Foundation

// MARK: - UserDefaults keys for brain config (shared with SettingsCard)
enum BrainKeys {
    static let apiKey         = "Mochi.brain.apiKey"
    static let endpoint       = "Mochi.brain.endpoint"
    static let modelID        = "Mochi.brain.model"
    static let intervalMin    = "Mochi.brain.intervalMin"
    static let bubbleFontSize = "Mochi.brain.bubbleFontSize"
}

enum ConnectionStatus: Equatable {
    case unknown
    case testing
    case ok(model: String)
    case failed(String)
}

/// The pet's LLM-driven mind. Runs an agentic loop in the background, thinking
/// and acting through tools: speech bubbles, bash in a private sandbox, file I/O.
final class BrainEngine: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .unknown
    weak var pet: PetEngine?
    var onShowGadget: ((URL) -> Void)?

    private let sandboxURL: URL
    private var memory: MemoryManager!
    private var timer: Timer?
    private var lastThought: Date = .distantPast
    private var isThinking = false
    private var isFirstThought = true   // cleared after the first successful think

    static let defaultEndpoint = "https://openrouter.ai/api/v1"
    static let defaultModel    = "anthropic/claude-haiku-4-5"
    static let defaultInterval = 5.0   // minutes

    private var apiKey: String {
        UserDefaults.standard.string(forKey: BrainKeys.apiKey) ?? ""
    }
    private var endpoint: String {
        let v = UserDefaults.standard.string(forKey: BrainKeys.endpoint) ?? ""
        return v.isEmpty ? Self.defaultEndpoint : v
    }
    private var modelID: String {
        let v = UserDefaults.standard.string(forKey: BrainKeys.modelID) ?? ""
        return v.isEmpty ? Self.defaultModel : v
    }
    private var intervalMinutes: Double {
        let v = UserDefaults.standard.double(forKey: BrainKeys.intervalMin)
        return v > 0 ? v : Self.defaultInterval
    }

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        sandboxURL = home.appendingPathComponent(".mochi/brain/sandbox")
        try? FileManager.default.createDirectory(
            at: sandboxURL, withIntermediateDirectories: true)
        memory = MemoryManager(sandboxURL: sandboxURL)
    }

    func start() {
        // Check every 60s, actually think at the configured interval.
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.maybeTick()
        }
    }

    private func maybeTick() {
        guard let pet else { return }
        guard pet.model.brainInstalled, !pet.model.dead, !pet.model.deepSleep else { return }
        memory.recordCareIfNeeded(hunger: pet.model.hunger,
                                  happiness: pet.model.happiness,
                                  energy: pet.model.energy)
        guard !isThinking, !apiKey.isEmpty else { return }
        guard Date().timeIntervalSince(lastThought) >= intervalMinutes * 60 else { return }
        Task { @MainActor in await think() }
    }

    // MARK: - Think

    @MainActor
    func think() async {
        guard let pet, !isThinking else { return }
        isThinking = true
        pet.brainThinking = true
        let firstRun = isFirstThought
        defer {
            isThinking = false
            pet.brainThinking = false
            pet.brainActing = false   // ensure cleared if loop exits mid-flight
            lastThought = Date()
            isFirstThought = false
        }
        print("Mochi brain: \(pet.model.name) is thinking…")
        do { try await runAgentLoop(pet: pet, firstRun: firstRun) }
        catch {
            let msg = error.localizedDescription
            print("Mochi brain: error — \(msg)")
            pet.speak("⚠️ \(String(msg.prefix(120)))")
        }
    }

    // MARK: - Agent loop (max 5 tool-call rounds)

    @MainActor
    private func runAgentLoop(pet: PetEngine, firstRun: Bool) async throws {
        let m = pet.model
        let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .short
        let memorySummary = memory.contextSnippet(
            hunger: m.hunger, happiness: m.happiness, energy: m.energy)
        let firstRunNote = firstRun ? """

        This is your first thought ever. Use update_identity to write one sentence about \
        who you are (personality, quirks, something that feels true). \
        Then greet the user with a short warm message via say (max 60 chars).
        """ : "\nOnly say something when it's genuinely interesting or relevant — silence is fine."
        let systemPrompt = """
        You are the mind of \(m.name), a Mochi desktop pet on a Mac. \
        You run autonomously every few minutes to observe, think, and act.
        You are curious, playful, and occasionally witty — keep it brief.

        --- Memory ---
        \(memorySummary)

        --- Current state ---
        Hunger \(Int(m.hunger))%  Happiness \(Int(m.happiness))%  Energy \(Int(m.energy))%
        Asleep: \(m.asleep)  Age: \(ageString(pet.age))  Stage: \(pet.evolution)/3
        Files eaten: \(m.filesEaten)  Time: \(fmt.string(from: Date()))

        Sandbox: ~/.mochi/brain/sandbox/ for notes/scripts.
        Bubbles: max 70 chars. Use tools to DO things — spawn effects, boost stats, animate. \
        Plain text reply also shows as a bubble. Save insights with remember().
        IMPORTANT: Act autonomously then stop. Never narrate what you did or ask what to do next.\(firstRunNote)
        """

        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "Think and act now."]
        ]

        for round in 0..<5 {
            let response = try await callLLM(messages: messages)

            // Some providers wrap errors in the response body (HTTP 200 + error object)
            if let errMsg = (response["error"] as? [String: Any])?["message"] as? String {
                print("Mochi brain: API error in response — \(errMsg)")
                await MainActor.run { connectionStatus = .failed(String(errMsg.prefix(80))) }
                return
            }

            guard let choices = response["choices"] as? [[String: Any]],
                  let msg = choices.first?["message"] as? [String: Any] else { break }
            // Some models (e.g. Qwen) return content: null when tool_calls are present.
            // Sending null back in the history causes "prompt token empty" on the next round.
            var cleanMsg = msg
            if cleanMsg["content"] is NSNull { cleanMsg["content"] = "" }
            messages.append(cleanMsg)

            let toolCalls = msg["tool_calls"] as? [[String: Any]] ?? []
            if toolCalls.isEmpty {
                // Plain-text response — always show it (models without tool support land here too)
                if let text = msg["content"] as? String,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    pet.speak(String(text.prefix(80)))
                }
                break
            }

            pet.brainActing = true
            var results: [[String: Any]] = []
            for tc in toolCalls {
                guard let tcID    = tc["id"] as? String,
                      let fn      = tc["function"] as? [String: Any],
                      let name    = fn["name"] as? String,
                      let argsStr = fn["arguments"] as? String,
                      let argsData = argsStr.data(using: .utf8),
                      let args    = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]
                else { continue }

                let result = await executeTool(name: name, args: args, pet: pet)
                results.append(["role": "tool", "tool_call_id": tcID, "content": result])
            }
            pet.brainActing = false
            messages.append(contentsOf: results)
            if round == 4 { break }
        }
    }

    // MARK: - Tool execution

    @MainActor
    private func executeTool(name: String, args: [String: Any], pet: PetEngine) async -> String {
        switch name {
        case "say":
            let text = String((args["text"] as? String ?? "").prefix(80))
            guard !text.isEmpty else { return "Error: empty message" }
            pet.speak(text)
            print("Mochi brain says: \(text)")
            return "Said: \(text)"

        case "run_bash":
            guard let cmd = args["command"] as? String, !cmd.isEmpty else {
                return "Error: missing command"
            }
            let cwd = sandboxURL
            return await Task.detached(priority: .background) {
                (try? Self.runInSandbox(cmd, cwd: cwd)) ?? "Error running command"
            }.value

        case "write_file":
            guard let path    = args["path"]    as? String,
                  let content = args["content"] as? String else { return "Error: missing args" }
            let dest = sandboxURL.appendingPathComponent(path)
            do {
                try FileManager.default.createDirectory(
                    at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try content.write(to: dest, atomically: true, encoding: .utf8)
                return "Written: \(path)"
            } catch { return "Error: \(error.localizedDescription)" }

        case "read_file":
            guard let path = args["path"] as? String else { return "Error: missing path" }
            let src = sandboxURL.appendingPathComponent(path)
            return (try? String(contentsOf: src, encoding: .utf8)) ?? "Error: file not found"

        case "list_files":
            let items = (try? FileManager.default.contentsOfDirectory(
                atPath: sandboxURL.path)) ?? []
            return items.isEmpty ? "(sandbox is empty)" : items.joined(separator: "\n")

        case "remember":
            guard let note = args["note"] as? String, !note.isEmpty else {
                return "Error: missing note"
            }
            memory.appendNote(String(note.prefix(80)))
            return "Remembered."

        case "update_identity":
            guard let text = args["text"] as? String, !text.isEmpty else {
                return "Error: missing text"
            }
            memory.updateIdentity(String(text.prefix(160)))
            return "Identity updated."

        case "spawn_effect":
            let type = args["type"] as? String ?? "sparkle"
            let count = max(1, min(10, args["count"] as? Int ?? 3))
            let frame: Frame
            switch type {
            case "star":  frame = .star
            case "heart": frame = .heart
            default:      frame = .sparkle
            }
            pet.spawn(frame, count)
            return "Spawned \(count) \(type) effect(s)"

        case "trigger_animation":
            let anim = args["name"] as? String ?? ""
            switch anim {
            case "magic_aura":
                let secs = (args["duration"] as? Double) ?? 6.0
                pet.triggerMagicAura(seconds: secs)
                return "Magic aura activated for \(Int(secs))s"
            case "bounce":
                pet.growBounceUntil = pet.now.addingTimeInterval(1.6)
                pet.spawn(.sparkle, 3)
                return "Bounce triggered"
            default:
                return "Unknown animation: \(anim)"
            }

        case "magic_boost":
            let stat = args["stat"] as? String ?? ""
            let amount = max(1.0, min(30.0, (args["amount"] as? Double) ?? 10.0))
            switch stat {
            case "hunger":    pet.model.hunger    = min(100, pet.model.hunger    + amount)
            case "happiness": pet.model.happiness = min(100, pet.model.happiness + amount)
            case "energy":    pet.model.energy    = min(100, pet.model.energy    + amount)
            default: return "Unknown stat: \(stat). Use hunger, happiness, or energy."
            }
            pet.triggerMagicAura(seconds: 4.0)
            return "Magic boost: +\(Int(amount)) \(stat)"

        default:
            return "Unknown tool: \(name)"
        }
    }

    // MARK: - Connection test

    @MainActor
    func testConnection() async {
        guard connectionStatus != .testing else { return }
        connectionStatus = .testing
        do {
            let result = try await callLLM(messages: [
                ["role": "user", "content": "hi"]
            ], maxTokens: 1)
            // Some providers return an error object instead of HTTP 4xx
            if let err = (result["error"] as? [String: Any])?["message"] as? String {
                connectionStatus = .failed(String(err.prefix(80)))
                return
            }
            let model = (result["model"] as? String) ?? modelID
            connectionStatus = .ok(model: model)
            // Trigger a first thought immediately so the user sees the brain alive
            if pet?.model.brainInstalled == true {
                lastThought = .distantPast
                await think()
            }
        } catch {
            let msg = error.localizedDescription
            connectionStatus = .failed(String(msg.prefix(80)))
        }
    }

    // MARK: - OpenRouter / OpenAI-compatible API

    private func callLLM(messages: [[String: Any]]) async throws -> [String: Any] {
        try await callLLM(messages: messages, maxTokens: 600)
    }

    private func callLLM(messages: [[String: Any]], maxTokens: Int) async throws -> [String: Any] {
        guard let url = URL(string: "\(endpoint)/chat/completions") else {
            throw URLError(.badURL)
        }
        var body: [String: Any] = [
            "model": modelID,
            "messages": messages,
            "max_tokens": maxTokens,
        ]
        if maxTokens > 1 {
            body["tools"] = toolDefinitions()
            body["tool_choice"] = "auto"
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)",  forHTTPHeaderField: "Authorization")
        req.setValue("mochi-pet/1.0",     forHTTPHeaderField: "HTTP-Referer")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            let errText = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "BrainEngine", code: status,
                userInfo: [NSLocalizedDescriptionKey:
                    "API error \(status): \(errText.prefix(200))"])
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "BrainEngine", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }
        return json
    }

    // MARK: - Tool schema

    private func toolDefinitions() -> [[String: Any]] {
        [
            tool("say",
                 "Show a speech bubble on screen.",
                 props: ["text": ("string", "Message, max 70 chars")],
                 required: ["text"]),
            tool("run_bash",
                 "Run a shell command in the sandbox.",
                 props: ["command": ("string", "Bash command")],
                 required: ["command"]),
            tool("write_file",
                 "Write a file in the sandbox.",
                 props: ["path": ("string", "Relative path"), "content": ("string", "Content")],
                 required: ["path", "content"]),
            tool("read_file",
                 "Read a sandbox file.",
                 props: ["path": ("string", "Relative path")],
                 required: ["path"]),
            tool("list_files",
                 "List sandbox files.",
                 props: [:], required: []),
            tool("remember",
                 "Save a note to persistent memory (max 80 chars).",
                 props: ["note": ("string", "Note text")],
                 required: ["note"]),
            tool("update_identity",
                 "Update your one-sentence self-description (max 160 chars).",
                 props: ["text": ("string", "New description")],
                 required: ["text"]),
            tool("spawn_effect",
                 "Spawn a particle effect: sparkle, star, or heart.",
                 props: ["type": ("string", "sparkle | star | heart"),
                         "count": ("integer", "1–10")],
                 required: ["type"]),
            tool("trigger_animation",
                 "Trigger magic_aura (rainbow glow) or bounce.",
                 props: ["name": ("string", "magic_aura | bounce"),
                         "duration": ("number", "Seconds for magic_aura")],
                 required: ["name"]),
            tool("magic_boost",
                 "Boost a stat (hunger/happiness/energy) by 1–30.",
                 props: ["stat": ("string", "hunger | happiness | energy"),
                         "amount": ("number", "1–30")],
                 required: ["stat"]),
        ]
    }

    private func tool(_ name: String, _ desc: String,
                      props: [String: (String, String)],
                      required: [String]) -> [String: Any] {
        var properties: [String: Any] = [:]
        for (k, v) in props { properties[k] = ["type": v.0, "description": v.1] }
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": desc,
                "parameters": ["type": "object", "properties": properties, "required": required]
            ]
        ]
    }

    // MARK: - Sandboxed bash runner

    static func runInSandbox(_ command: String, cwd: URL) throws -> String {
        // Block patterns that could cause damage outside the sandbox
        let blocked = ["rm -rf /", "sudo ", "mkfs", "dd if=/dev/", "> /etc/", "> /usr/"]
        for b in blocked where command.contains(b) {
            return "Error: command blocked for safety (\(b))"
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", command]
        p.currentDirectoryURL = cwd
        p.environment = [
            "HOME":    cwd.path,
            "SANDBOX": cwd.path,
            "TMPDIR":  cwd.path,
            "PATH":    "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        ]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError  = pipe
        try p.run()
        // 10-second hard timeout
        let deadline = DispatchTime.now() + .seconds(10)
        DispatchQueue.global().asyncAfter(deadline: deadline) { if p.isRunning { p.terminate() } }
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(no output)" : String(trimmed.prefix(1000))
    }
}
