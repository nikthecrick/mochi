import SwiftUI
import AppKit

/// NSTextField/NSSecureTextField wrapper that works reliably in floating panels:
/// paste (Cmd+V), copy, cut, and select-all all go through AppKit's native
/// text-editing infrastructure and do not depend on SwiftUI's focus system.
struct PasteableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSTextField {
        let field: NSTextField = isSecure ? NSSecureTextField() : NSTextField()
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.font = .systemFont(ofSize: 10)
        field.textColor = NSColor.white.withAlphaComponent(0.9)
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Avoid overwriting while the user is typing (cursor would jump)
        if nsView.stringValue != text { nsView.stringValue = text }
        nsView.placeholderString = placeholder
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }
        func controlTextDidChange(_ obj: Notification) {
            if let f = obj.object as? NSTextField { text = f.stringValue }
        }
    }
}
