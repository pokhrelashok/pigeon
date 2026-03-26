import SwiftUI
import AppKit

struct VariableTextField: NSViewRepresentable {
    @Binding var text: String
    var env: Environment?
    var placeholder: String = ""
    var font: NSFont = .systemFont(ofSize: 13)
    var onVariableUpdate: ((String, String) -> Void)? = nil
    var onCommit: (() -> Void)? = nil
    var onPaste: ((String) -> Bool)? = nil
    
    func makeNSView(context: Context) -> VariableTextView {
        let textView = VariableTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.font = font
        textView.enforceSingleLine = true
        textView.onCommit = onCommit
        
        // Remove link styling so our green color stays
        textView.linkTextAttributes = [:]
        
        // Layout settings for single line
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.maximumNumberOfLines = 1
        textView.textContainer?.lineBreakMode = .byTruncatingTail
        textView.textContainerInset = NSSize(width: 0, height: 2)
        
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // Set fixed height
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return textView
    }
    
    func updateNSView(_ nsView: VariableTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
        }
        
        // Always apply highlighting to reflect any changes in environment variables
        context.coordinator.applyHighlighting(to: nsView)
        
        nsView.placeholderString = placeholder
        context.coordinator.env = env
        context.coordinator.parent = self
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: VariableTextField
        var env: Environment?
        var popover: NSPopover?
        
        init(_ parent: VariableTextField) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyHighlighting(to: textView)
        }
        
        func applyHighlighting(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let string = textStorage.string
            let selectedRange = textView.selectedRange()
            
            let baseFont = textView.font ?? NSFont.systemFont(ofSize: 13)
            let attributed = NSMutableAttributedString(string: string)
            attributed.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: string.utf16.count))
            attributed.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: string.utf16.count))
            
            VariableHighlighter.shared.highlight(in: attributed, font: baseFont)
            
            textStorage.beginEditing()
            textStorage.setAttributedString(attributed)
            textStorage.endEditing()
            
            // Restore selection
            textView.setSelectedRange(selectedRange)
        }
        
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let linkString = link as? String, linkString.hasPrefix("variable://") {
                let variableName = String(linkString.dropFirst("variable://".count))
                showVariablePopover(for: variableName, in: textView, at: charIndex)
                return true
            }
            return false
        }
        
        private func showVariablePopover(for variableName: String, in textView: NSTextView, at charIndex: Int) {
            popover?.performClose(nil)
            
            let popoverView = VariablePopoverView(variableName: variableName, env: env) { [weak self] newValue in
                self?.parent.onVariableUpdate?(variableName, newValue)
            }
            
            let hostingController = NSHostingController(rootView: popoverView)
            
            let newPopover = NSPopover()
            newPopover.contentViewController = hostingController
            newPopover.behavior = .transient
            newPopover.animates = true
            
            // Find the rect for the character index
            if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
                let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
                
                newPopover.show(relativeTo: rect, of: textView, preferredEdge: .maxY)
            }
            
            self.popover = newPopover
        }
    }
}

class VariableTextView: NSTextView {
    var enforceSingleLine: Bool = false
    var onCommit: (() -> Void)? = nil
    var placeholderString: String? {
        didSet {
            self.needsDisplay = true
        }
    }
    
    override func insertNewline(_ sender: Any?) {
        if enforceSingleLine {
            onCommit?()
        } else {
            super.insertNewline(sender)
        }
    }
    
    override func insertTab(_ sender: Any?) {
        self.window?.selectNextKeyView(sender)
    }
    
    override func insertBacktab(_ sender: Any?) {
        self.window?.selectPreviousKeyView(sender)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if string.isEmpty, let placeholder = placeholderString {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.placeholderTextColor
            ]
            let placeholderRect = NSRect(x: textContainerInset.width + 2, y: textContainerInset.height, width: bounds.width, height: bounds.height)
            placeholder.draw(in: placeholderRect, withAttributes: attributes)
        }
    }
    
    // Support CMD+Return or just Return if needed
    override func keyDown(with event: NSEvent) {
        if enforceSingleLine && (event.keyCode == 36 || event.keyCode == 76) { // Return key
            onCommit?()
            return
        }
        super.keyDown(with: event)
    }

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        if let s = pb.string(forType: .string), let onPaste = (delegate as? VariableTextField.Coordinator)?.parent.onPaste, onPaste(s) {
            return
        }
        super.paste(sender)
    }
}
