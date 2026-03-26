import Foundation
import AppKit
import SwiftUI

class JSONHighlighter {
    struct Theme {
        let key: NSColor
        let string: NSColor
        let number: NSColor
        let boolean: NSColor
        let null: NSColor
        let background: NSColor
        let foreground: NSColor
        
        static let proDark = Theme(
            key: NSColor(deviceRed: 0.33, green: 0.61, blue: 0.84, alpha: 1.0), // #569CD6
            string: NSColor(deviceRed: 0.81, green: 0.57, blue: 0.47, alpha: 1.0), // #CE9178
            number: NSColor(deviceRed: 0.73, green: 0.47, blue: 0.77, alpha: 1.0), // #BA79C6
            boolean: NSColor(deviceRed: 0.85, green: 0.30, blue: 0.25, alpha: 1.0), // #D94C40
            null: NSColor(deviceRed: 0.85, green: 0.30, blue: 0.25, alpha: 1.0),
            background: NSColor(deviceRed: 0.12, green: 0.12, blue: 0.12, alpha: 1.0),
            foreground: .white
        )
        
        static let proLight = Theme(
            key: NSColor(deviceRed: 0.0, green: 0.0, blue: 1.0, alpha: 1.0), // Blue
            string: NSColor(deviceRed: 0.64, green: 0.08, blue: 0.08, alpha: 1.0), // Dark Red
            number: NSColor(deviceRed: 0.05, green: 0.49, blue: 0.49, alpha: 1.0), // Teal
            boolean: NSColor(deviceRed: 1.0, green: 0.5, blue: 0.0, alpha: 1.0), // Orange
            null: NSColor(deviceRed: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),
            background: .white,
            foreground: .black
        )
    }
    
    func highlight(_ text: String, colorScheme: ColorScheme) -> NSAttributedString {
        let theme = colorScheme == .dark ? Theme.proDark : Theme.proLight
        return highlight(text, theme: theme)
    }
    
    func highlight(_ text: String, theme: Theme) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        
        attributedString.addAttribute(.foregroundColor, value: theme.foreground, range: fullRange)
        attributedString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: fullRange)
        
        // Match numbers
        highlight(pattern: "\\b-?(?:0|[1-9]\\d*)(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b", color: theme.number, in: attributedString, text: text)
        
        // Match Booleans/Null
        highlight(pattern: "\\b(?:true|false|null)\\b", color: theme.boolean, in: attributedString, text: text)
        
        // Match all strings first
        highlight(pattern: "\"(?:\\\\.|[^\"\\\\])*\"", color: theme.string, in: attributedString, text: text)
        
        // Overwrite Keys (strings followed by colon)
        highlight(pattern: "\"(?:\\\\.|[^\"\\\\])*\"(?=\\s*:)", color: theme.key, in: attributedString, text: text)
        
        // Match Variables
        let baseFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        VariableHighlighter.shared.highlight(in: attributedString, font: baseFont)
        
        return attributedString
    }
    
    private func highlight(pattern: String, color: NSColor, in attributedString: NSMutableAttributedString, text: String) {
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let fullRange = NSRange(location: 0, length: text.utf16.count)
            regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                if let range = match?.range {
                    attributedString.addAttribute(.foregroundColor, value: color, range: range)
                }
            }
        }
    }
}
