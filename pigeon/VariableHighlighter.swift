import Foundation
import AppKit

class VariableHighlighter {
    static let shared = VariableHighlighter()
    
    // Bruno-like green
    static let variableForegroundColor = NSColor(deviceRed: 0.15, green: 0.88, blue: 0.57, alpha: 1.0)
    
    func highlight(in attributedString: NSMutableAttributedString, font: NSFont? = nil) {
        let text = attributedString.string
        let pattern = #"\{\{(.*?)\}\}"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        
        let variableFont: NSFont
        if let baseFont = font {
            variableFont = baseFont
        } else {
            variableFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        }
        
        regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let range = match?.range {
                attributedString.addAttribute(.foregroundColor, value: VariableHighlighter.variableForegroundColor, range: range)
                attributedString.addAttribute(.font, value: variableFont, range: range)
                
                // Add a custom attribute to identify variables for click detection later
                let variableName = (text as NSString).substring(with: NSRange(location: range.location + 2, length: range.length - 4))
                attributedString.addAttribute(.link, value: "variable://\(variableName)", range: range)
            }
        }
    }
    
    func highlightText(_ text: String, font: NSFont? = nil) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        highlight(in: attributed, font: font)
        return attributed
    }
}
