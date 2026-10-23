import AppKit

/// Browser tabs as pet food. macOS has no cross-app *window* drag, but tabs
/// (and the address-bar icon, and links) drag as URLs: drop one on the pet
/// and it eats it — the matching open tab is closed in the browser (via
/// AppleScript; macOS asks for Automation permission on first use).
/// Supported: Chrome, Safari, Edge, Brave, Chromium.
enum BrowserEater {
    static let supported: [String] = [
        "Google Chrome", "Safari", "Microsoft Edge", "Brave Browser", "Chromium",
    ]

    // MARK: - AppleScript plumbing

    private static func run(_ source: String) -> (text: String?, error: String?) {
        var err: NSDictionary?
        let desc = NSAppleScript(source: source)?.executeAndReturnError(&err)
        if let err = err {
            let msg = err[NSAppleScript.errorMessage] as? String ?? String(describing: err)
            return (nil, msg)
        }
        return (desc?.stringValue, nil)
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func runningBrowsers() -> [String] {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        let map = ["Google Chrome": "com.google.Chrome", "Safari": "com.apple.Safari",
                   "Microsoft Edge": "com.microsoft.edgemac", "Brave Browser": "com.brave.Browser",
                   "Chromium": "org.chromium.Chromium"]
        return supported.filter { running.contains(map[$0] ?? "") }
    }

    /// "title<TAB>url" lines -> tabs. Pure (tested headless).
    static func parse(_ raw: String, browser: String) -> [BrowserTab] {
        raw.split(separator: "\n").compactMap { line -> BrowserTab? in
            let parts = line.split(separator: "\t",
                                   maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            let title = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let url = String(parts[1]).trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty, !url.isEmpty,
                  url != "missing value", url != "«data »" else { return nil }
            return BrowserTab(browser: browser, title: title, url: url)
        }
    }

    struct BrowserTab {
        let browser: String
        let title: String
        let url: String
    }

    static func isWebURL(_ url: URL) -> Bool {
        let s = url.scheme?.lowercased() ?? ""
        return s == "http" || s == "https"
    }

    /// Drop path: given a web URL dragged onto the pet (a browser tab, the
    /// address-bar icon, a link), find the open tab with that URL, close it,
    /// and return which browser + tab title it came from.
    /// Returns nil if no open tab matches (then it's eaten as a plain snack).
    static func closeTab(url: String) -> (browser: String, title: String)? {
        for name in runningBrowsers() {
            let nameProp = name == "Safari" ? "name" : "title"
            let src = """
            tell application "\(escape(name))"
                repeat with w in windows
                    repeat with t in tabs of w
                        if (URL of t) = "\(escape(url))" then
                            set tTitle to (\(nameProp) of t) as text
                            close t
                            return tTitle
                        end if
                    end repeat
                end repeat
                return ""
            end tell
            """
            let (text, error) = run(src)
            if let error = error {
                print("RetroPet: closing a \(name) tab failed: \(error)")
                continue
            }
            let title = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                return (name, title)
            }
        }
        return nil
    }
}