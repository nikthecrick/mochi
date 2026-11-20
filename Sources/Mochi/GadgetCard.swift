import SwiftUI
import WebKit

// MARK: - Gadget card: floating window that hosts an HTML file from the brain sandbox

struct GadgetCard: View {
    let url: URL
    var onClose: () -> Void

    private let w: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            header
            GadgetWebView(url: url)
                .frame(width: w, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
        }
        .frame(width: w)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: NSColor(red: 0.10, green: 0.09, blue: 0.14, alpha: 0.92)))
                .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.13)))
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
            .help("Close gadget")
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.purple)
            Text("MOCHI GADGET")
                .font(PixelFont.font(6))
                .foregroundColor(.white.opacity(0.45))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
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
        // Reload only when the URL actually changed
        if wv.url != url { load(wv) }
    }

    private func load(_ wv: WKWebView) {
        // allowingReadAccessTo: sandbox dir so relative CSS/JS imports work
        wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}
