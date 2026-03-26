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
        
        let cell = CenteredTextFieldCell(textCell: "")
        cell.isEditable = true
        cell.isScrollable = true
        cell.usesSingleLineMode = true
        cell.lineBreakMode = .byClipping
        cell.wraps = false
        textField.cell = cell
        
        textField.delegate = context.coordinator
        textField.font = font
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        
        textField.onCommit = onCommit
        textField.onPaste = onPaste
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
            // Apply highlighting when updated from SwiftUI
            context.coordinator.applyHighlighting(to: nsView)
        }
        
        nsView.placeholderString = placeholder
        context.coordinator.env = env
        context.coordinator.parent = self
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
            
            // Only update if the attributed string is different to preserve undo stack and cursor
            if textField.attributedStringValue != attributed {
                textField.attributedStringValue = attributed
                
                // Restore selection IMMEDIATELY after setting value
                if let range = selectedRange, let editor = textField.currentEditor() {
                    editor.selectedRange = range
                }
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
    
    override var undoManager: UndoManager? {
        return super.undoManager ?? NSApplication.shared.keyWindow?.undoManager
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

class CenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let rect = super.drawingRect(forBounds: rect)
        let size = self.cellSize(forBounds: rect)
        let delta = rect.height - size.height
        if delta > 0 {
            return NSRect(x: rect.origin.x, y: rect.origin.y + delta / 2, width: rect.width, height: size.height)
        }
        return rect
    }
    
    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
    
    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }
}
