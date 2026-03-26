import SwiftUI
import AppKit

struct JSONCodeView: View {
    let json: String
    var isRaw: Bool = false
    var contentType: String? = nil
    
    // Search parameters
    var searchText: String = ""
    @Binding var currentSearchIndex: Int
    @Binding var totalResults: Int
    
    @SwiftUI.Environment(\.colorScheme) var scheme
    private let highlighter = JSONHighlighter()
    
    var body: some View {
        let theme = scheme == .dark ? JSONHighlighter.Theme.proDark : JSONHighlighter.Theme.proLight
        let displayJSON = isRaw ? json : FormatterService.shared.format(body: json, contentType: contentType ?? "application/json")
        CodeView(
            attributedString: highlighter.highlight(displayJSON, colorScheme: scheme),
            backgroundColor: Color(nsColor: theme.background),
            searchText: searchText,
            currentSearchIndex: $currentSearchIndex,
            totalResults: $totalResults
        )
    }
}

private extension Color {
    init(deviceRed red: Double, green: Double, blue: Double) {
        self.init(nsColor: NSColor(deviceRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0))
    }
}

struct CodeView: NSViewRepresentable {
    let attributedString: NSAttributedString
    let backgroundColor: Color
    
    var searchText: String
    @Binding var currentSearchIndex: Int
    @Binding var totalResults: Int
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.backgroundColor = NSColor(backgroundColor)
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.drawsBackground = true
        
        // Setup Line Numbers
        scrollView.hasHorizontalRuler = false
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        
        let lineNumberView = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = lineNumberView
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            textView.backgroundColor = NSColor(backgroundColor)
            
            // Only update text if it changed to avoid resetting search highlights
            if textView.attributedString() != attributedString {
                textView.textStorage?.setAttributedString(attributedString)
            }
            
            if let ruler = nsView.verticalRulerView as? LineNumberRulerView {
                ruler.needsDisplay = true
            }
            
            
            // Handle Search
            performSearch(in: textView)
        }
    }
    
    class Coordinator: NSObject {
    }
    
    private func performSearch(in textView: NSTextView) {
        guard !searchText.isEmpty else {
            textView.layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: NSRange(location: 0, length: textView.string.count))
            textView.layoutManager?.removeTemporaryAttribute(.foregroundColor, forCharacterRange: NSRange(location: 0, length: textView.string.count))
            if totalResults != 0 {
                DispatchQueue.main.async {
                    totalResults = 0
                    currentSearchIndex = 0
                }
            }
            return
        }
        
        let string = textView.string as NSString
        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: string.length)
        
        while searchRange.location < string.length {
            let foundRange = string.range(of: searchText, options: .caseInsensitive, range: searchRange)
            if foundRange.location != NSNotFound {
                ranges.append(foundRange)
                searchRange.location = foundRange.location + foundRange.length
                searchRange.length = string.length - searchRange.location
            } else {
                break
            }
        }
        
        // Update total results count
        if totalResults != ranges.count {
            DispatchQueue.main.async {
                totalResults = ranges.count
                if currentSearchIndex >= ranges.count {
                    currentSearchIndex = 0
                }
            }
        }
        
        // Apply temporary highlights
        textView.layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: NSRange(location: 0, length: string.length))
        textView.layoutManager?.removeTemporaryAttribute(.foregroundColor, forCharacterRange: NSRange(location: 0, length: string.length))
        
        for (index, range) in ranges.enumerated() {
            let isCurrent = (index == currentSearchIndex)
            let color = isCurrent ? NSColor.systemOrange : NSColor.systemYellow.withAlphaComponent(0.3)
            textView.layoutManager?.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
            
            if isCurrent {
                textView.layoutManager?.addTemporaryAttribute(.foregroundColor, value: NSColor.white, forCharacterRange: range)
                textView.scrollRangeToVisible(range)
            }
        }
    }
}

class LineNumberRulerView: NSRulerView {
    var textView: NSTextView?
    
    init(textView: NSTextView) {
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.textView = textView
        self.clientView = textView
        self.ruleThickness = 40
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView, let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
        
        let visibleRect = self.scrollView?.contentView.bounds ?? .zero
        let textString = textView.string as NSString
        
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        var visibleLineNumber = 1
        // Calculate initial line number
        textString.enumerateSubstrings(in: NSRange(location: 0, length: charRange.location), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            visibleLineNumber += 1
        }
        
        textString.enumerateSubstrings(in: charRange, options: .byLines) { _, lineRange, _, _ in
            let index = lineRange.location
            let rect = layoutManager.lineFragmentRect(forGlyphAt: layoutManager.glyphIndexForCharacter(at: index), effectiveRange: nil)
            
            let y = rect.origin.y - visibleRect.origin.y + textView.textContainerInset.height
            let actualLineNumber = visibleLineNumber
            let label = "\(actualLineNumber)" as NSString
            let labelSize = label.size(withAttributes: attributes)
            
            label.draw(at: NSPoint(x: self.ruleThickness - labelSize.width - 12, y: y + (rect.height - labelSize.height) / 2), withAttributes: attributes)
            
            visibleLineNumber += 1
        }
    }
}

struct EditableJSONCodeView: NSViewRepresentable {
    @Binding var text: String
    var env: PigeonEnvironment?
    var onVariableUpdate: ((String, String) -> Void)? = nil
    @SwiftUI.Environment(\.colorScheme) var scheme
    private let highlighter = JSONHighlighter()

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.isVerticallyResizable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = true
        let theme = scheme == .dark ? JSONHighlighter.Theme.proDark : JSONHighlighter.Theme.proLight
        textView.backgroundColor = theme.background
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.delegate = context.coordinator
        
        // Remove link styling so our green color stays
        textView.linkTextAttributes = [:]
        
        // Setup Line Numbers
        scrollView.hasHorizontalRuler = false
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        
        let lineNumberView = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = lineNumberView
        scrollView.documentView = textView
        
        textView.string = text
        context.coordinator.highlight(textView.textStorage)
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            context.coordinator.env = env
            context.coordinator.scheme = scheme
            
            let theme = scheme == .dark ? JSONHighlighter.Theme.proDark : JSONHighlighter.Theme.proLight
            textView.backgroundColor = theme.background
            
            if textView.string != text {
                textView.string = text
                context.coordinator.highlight(textView.textStorage)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditableJSONCodeView
        var env: PigeonEnvironment?
        var scheme: ColorScheme
        var popover: NSPopover?
        
        init(_ parent: EditableJSONCodeView) {
            self.parent = parent
            self.scheme = parent.scheme
        }
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let replacementString = replacementString else { return true }
            // AutocompleteService.shared.process will return false if it handles the text change internally
            // and performs the replacement itself, preventing the default NSTextView behavior.
            return AutocompleteService.shared.process(textView: textView, shouldChangeTextIn: affectedCharRange, replacementString: replacementString)
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
            highlight(textView.textStorage)
            
            if let scrollView = textView.enclosingScrollView, let ruler = scrollView.verticalRulerView as? LineNumberRulerView {
                ruler.needsDisplay = true
            }
        }
        
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let linkString: String?
            if let url = link as? URL {
                linkString = url.absoluteString
            } else if let str = link as? String {
                linkString = str
            } else {
                linkString = nil
            }
            
            if let str = linkString, str.hasPrefix("variable://") {
                let variableName = String(str.dropFirst("variable://".count))
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
            
            if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
                let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
                
                newPopover.show(relativeTo: rect, of: textView, preferredEdge: .maxY)
            }
            
            self.popover = newPopover
        }
        
        func highlight(_ textStorage: NSTextStorage?) {
            guard let textStorage = textStorage else { return }
            let string = textStorage.string
            let highlighted = parent.highlighter.highlight(string, colorScheme: scheme)
            
            textStorage.beginEditing()
            let fullRange = NSRange(location: 0, length: textStorage.length)
            textStorage.setAttributes([:], range: fullRange)
            highlighted.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
                textStorage.addAttributes(attrs, range: range)
            }
            textStorage.endEditing()
        }
    }
}
