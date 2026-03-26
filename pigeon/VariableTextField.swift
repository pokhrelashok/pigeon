import SwiftUI
import AppKit

struct VariableTextField: NSViewRepresentable {
    @Binding var text: String
    var env: PigeonEnvironment?
    var placeholder: String = ""
    var font: NSFont = .systemFont(ofSize: 13)
    var onVariableUpdate: ((String, String) -> Void)? = nil
    var onCommit: (() -> Void)? = nil
    var onPaste: ((String) -> Bool)? = nil
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = CustomTextField()
        textField.delegate = context.coordinator
        textField.font = font
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.cell?.lineBreakMode = .byClipping
        textField.cell?.usesSingleLineMode = true
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        
        textField.onCommit = onCommit
        textField.onPaste = onPaste
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        nsView.placeholderString = placeholder
        context.coordinator.env = env
        context.coordinator.parent = self
        
        // Apply highlighting to the attributed string
        context.coordinator.applyHighlighting(to: nsView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: VariableTextField
        var env: PigeonEnvironment?
        var popover: NSPopover?
        
        init(_ parent: VariableTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
            applyHighlighting(to: textField)
        }
        
        func applyHighlighting(to textField: NSTextField) {
            let string = textField.stringValue
            let baseFont = textField.font ?? NSFont.systemFont(ofSize: 13)
            
            // Get current selection (insertion point)
            var selectedRange: NSRange? = nil
            if let editor = textField.currentEditor() {
                selectedRange = editor.selectedRange
            }
            
            let attributed = NSMutableAttributedString(string: string)
            attributed.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: string.utf16.count))
            attributed.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: string.utf16.count))
            
            VariableHighlighter.shared.highlight(in: attributed, font: baseFont)
            
            textField.attributedStringValue = attributed
            
            // Restore selection if it was active
            if let range = selectedRange, let editor = textField.currentEditor() {
                editor.selectedRange = range
            }
        }
        
        // Link clicking in NSTextField is more complex, so we'll use a gesture recognizer if needed later.
        // For now, let's focus on the typing and scrolling.
    }
}

class CustomTextField: NSTextField {
    var onCommit: (() -> Void)? = nil
    var onPaste: ((String) -> Bool)? = nil
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown && (event.keyCode == 36 || event.keyCode == 76) { // Return key
            onCommit?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            // When becoming first responder, ensure we're using single line mode correctly
            self.cell?.usesSingleLineMode = true
        }
        return result
    }
}
