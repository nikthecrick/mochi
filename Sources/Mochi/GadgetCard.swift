import SwiftUI
import WebKit

// MARK: - Gadget card: retro 8-bit floating window hosting a brain-generated HTML file

struct GadgetCard: View {
    let url: URL
    var onClose: () -> Void

    private let w: CGFloat = 220
    private let contentH: CGFloat = 170
    private let accent = Color(red: 0.55, green: 0.25, blue: 1.0)
    private let bg    = Color(red: 0.04, green: 0.03, blue: 0.10)
    private let bgBar = Color(red: 0.09, green: 0.06, blue: 0.18)

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            // 1-px divider line in accent colour
            accent.opacity(0.5).frame(height: 1)
            GadgetWebView(url: url)
                .frame(width: w, height: contentH)
        }
        .frame(width: w)
        .background(bg)
        // pixel-style double border
        .overlay(
            ZStack {
                Rectangle().stroke(accent, lineWidth: 2)
                Rectangle().inset(by: 3).stroke(accent.opacity(0.25), lineWidth: 1)
            }
        )
        // bright corner squares for that 8-bit chrome feel
        .overlay(
            GeometryReader { g in
                let dot: CGFloat = 4
                Group {
                    cornerDot.position(x: dot / 2, y: dot / 2)
                    cornerDot.position(x: g.size.width - dot / 2, y: dot / 2)
                    cornerDot.position(x: dot / 2, y: g.size.height - dot / 2)
                    cornerDot.position(x: g.size.width - dot / 2, y: g.size.height - dot / 2)
                }
            }
        )
        .shadow(color: accent.opacity(0.35), radius: 10, y: 4)
    }

    private var titleBar: some View {
        HStack(spacing: 0) {
            // Blinking-pixel style decorations
            Text("■ ")
                .font(PixelFont.font(5))
                .foregroundColor(accent.opacity(0.6))
            Text("GADGET")
                .font(PixelFont.font(6))
                .foregroundColor(accent)
            Spacer()
            Button(action: onClose) {
                Text("[×]")
                    .font(PixelFont.font(6))
                    .foregroundColor(accent.opacity(0.75))
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(bgBar)
    }

    private var cornerDot: some View {
        Rectangle()
            .fill(accent)
            .frame(width: 4, height: 4)
    }
}

// MARK: - WKWebView wrapper — loads local sandbox HTML files

struct GadgetWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.setValue(false, forKey: "drawsBackground")
        load(wv)
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        if wv.url != url { load(wv) }
    }

    private func load(_ wv: WKWebView) {
        wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}
