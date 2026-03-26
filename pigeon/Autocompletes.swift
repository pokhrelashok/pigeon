//
//  Autocompletes.swift
//  pigeon
//
//  Created by Antigravity on 20/03/2026.
//

import AppKit

protocol TextAutocomplete {
    func handle(textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String) -> Bool
}

struct BracketAutocomplete: TextAutocomplete {
    func handle(textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String) -> Bool {
        let pairs: [String: String] = ["{": "}", "[": "]", "(": ")"]
        guard let closing = pairs[replacementString] else { return false }
        
        let newString = "\(replacementString)\(closing)"
        if textView.shouldChangeText(in: range, replacementString: newString) {
            textView.textStorage?.replaceCharacters(in: range, with: newString)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: range.location + 1, length: 0))
        }
        return true
    }
}

struct QuoteAutocomplete: TextAutocomplete {
    func handle(textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String) -> Bool {
        let quotes = ["\"", "'"]
        guard quotes.contains(replacementString) else { return false }
        
        // Don't auto-close if the previous character is a backslash (escaping)
        guard let nsString = textView.textStorage?.string as NSString? else { return false }
        if range.location > 0 {
            let prevChar = nsString.substring(with: NSRange(location: range.location - 1, length: 1))
            if prevChar == "\\" { return false }
        }
        
        let newString = "\(replacementString)\(replacementString)"
        if textView.shouldChangeText(in: range, replacementString: newString) {
            textView.textStorage?.replaceCharacters(in: range, with: newString)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: range.location + 1, length: 0))
        }
        return true
    }
}

struct IndentationAutocomplete: TextAutocomplete {
    func handle(textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String) -> Bool {
        guard replacementString == "\n" else { return false }
        
        guard let textStorage = textView.textStorage else { return false }
        let nsString = textStorage.string as NSString
        let length = nsString.length
        
        guard range.location <= length else { return false }
        
        let lineRange = nsString.lineRange(for: NSRange(location: range.location, length: 0))
        let safeLocation = max(0, min(lineRange.location, length))
        let safeLength = min(lineRange.length, length - safeLocation)
        let line = nsString.substring(with: NSRange(location: safeLocation, length: safeLength))
        
        var indentation = ""
        for char in line {
            if char == " " || char == "\t" {
                indentation.append(char)
            } else {
                break
            }
        }
        
        let prefix = nsString.substring(with: NSRange(location: safeLocation, length: range.location - safeLocation))
        let trimmedPrefix = prefix.trimmingCharacters(in: .whitespaces)
        
        var extraIndentation = ""
        if trimmedPrefix.hasSuffix("{") || trimmedPrefix.hasSuffix("[") || trimmedPrefix.hasSuffix("(") {
            extraIndentation = "  "
        }
        
        var combinedText = "\n" + indentation + extraIndentation
        let cursorOffset = combinedText.count
        
        // Handle auto-closing brace on next line
        if !extraIndentation.isEmpty && range.location < length {
            let nextChar = nsString.substring(with: NSRange(location: range.location, length: 1))
            if nextChar == "}" || nextChar == "]" || nextChar == ")" {
                combinedText += "\n" + indentation
            }
        }
        
        if textView.shouldChangeText(in: range, replacementString: combinedText) {
            textView.textStorage?.replaceCharacters(in: range, with: combinedText)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: range.location + cursorOffset, length: 0))
        }
        
        return true
    }
}

class AutocompleteService {
    static let shared = AutocompleteService()
    
    private let handlers: [TextAutocomplete] = [
        BracketAutocomplete(),
        QuoteAutocomplete(),
        IndentationAutocomplete()
    ]
    
    func process(textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String) -> Bool {
        for handler in handlers {
            if handler.handle(textView: textView, shouldChangeTextIn: range, replacementString: replacementString) {
                return false // Handled manually
            }
        }
        return true // Let the text view handle it normally
    }
}
