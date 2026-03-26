import Foundation
import Parsing

protocol RequestParser {
    func canHandle(fileExtension: String) -> Bool
    func parse(content: String, url: URL) throws -> Request
}

class RequestParserRegistry {
    static let shared = RequestParserRegistry()
    
    let parsers: [RequestParser] = [
        JSONRequestParser(),
        BruRequestParser(),
        BrunoYamlRequestParser()
    ]
    
    func parser(for fileExtension: String) -> RequestParser? {
        parsers.first { $0.canHandle(fileExtension: fileExtension.lowercased()) }
    }
}

struct CurlParser {
    static let shared = CurlParser()
    
    func parse(_ curl: String) -> Request? {
        var input = curl.trimmingCharacters(in: .whitespacesAndNewlines)[...]
        
        // Skip "curl" prefix
        guard input.lowercased().hasPrefix("curl") else { return nil }
        input.removeFirst(4)
        
        let tokens = tokenize(&input)
        var method = "GET"
        var url: String?
        var headers: [String: String] = [:]
        var body: String?
        var bodyType = "none"
        
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            
            switch token {
            case "-X", "--request":
                if i + 1 < tokens.count {
                    method = tokens[i+1].uppercased()
                    i += 2
                } else { i += 1 }
                
            case "-H", "--header":
                if i + 1 < tokens.count {
                    let header = tokens[i+1]
                    let parts = header.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                    if parts.count == 2 {
                        headers[parts[0]] = parts[1]
                    }
                    i += 2
                } else { i += 1 }
                
            case "-u", "--user":
                if i + 1 < tokens.count {
                    let userPass = tokens[i+1]
                    let parts = userPass.split(separator: ":", maxSplits: 1).map { String($0) }
                    if parts.count == 2 {
                        // We'll handle this in the Auth object return
                    }
                    i += 2
                } else { i += 1 }
                
            case "-d", "--data", "--data-raw", "--data-binary", "--data-ascii", "--data-urlencode":
                if i + 1 < tokens.count {
                    body = tokens[i+1]
                    if method == "GET" { method = "POST" }
                    if bodyType == "none" { bodyType = "json" }
                    i += 2
                } else { i += 1 }
                
            case "-b", "--cookie":
                if i + 1 < tokens.count {
                    let cookieValue = tokens[i+1]
                    if let existing = headers["Cookie"] {
                        headers["Cookie"] = "\(existing); \(cookieValue)"
                    } else {
                        headers["Cookie"] = cookieValue
                    }
                    i += 2
                } else { i += 1 }
                
            case "--url":
                if i + 1 < tokens.count {
                    url = tokens[i+1]
                    i += 2
                } else { i += 1 }
                
            default:
                if !token.hasPrefix("-") && url == nil {
                    url = token
                }
                i += 1
            }
        }
        
        var auth: Auth? = nil
        // Check for Bearer token in headers
        for (key, value) in headers {
            if key.lowercased() == "authorization" && value.lowercased().hasPrefix("bearer ") {
                let token = String(value.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                auth = Auth(type: .bearer, token: token)
                headers.removeValue(forKey: key)
                break
            } else if key.lowercased() == "authorization" && value.lowercased().hasPrefix("basic ") {
                let base64 = String(value.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                if let data = Data(base64Encoded: base64), let decoded = String(data: data, encoding: .utf8) {
                    let parts = decoded.split(separator: ":", maxSplits: 1).map { String($0) }
                    if parts.count == 2 {
                        auth = Auth(type: .basic, username: parts[0], password: parts[1])
                        headers.removeValue(forKey: key)
                        break
                    }
                }
            }
        }
        
        guard let finalUrl = url?.trimmingCharacters(in: CharacterSet(charactersIn: "'\"")) else { return nil }
        
        if let body = body {
            let trimmedBody = body.trimmingCharacters(in: .whitespaces)
            if trimmedBody.hasPrefix("{") || trimmedBody.hasPrefix("[") {
                bodyType = "json"
            } else if trimmedBody.hasPrefix("<") {
                bodyType = "xml"
            } else {
                bodyType = "text"
            }
        }
        
        return Request(
            name: "Pasted Curl",
            method: method,
            url: finalUrl,
            headers: headers.isEmpty ? nil : headers,
            query: nil,
            pathParams: nil,
            body: body,
            auth: auth,
            seq: 1,
            tags: nil,
            docs: nil,
            varsPreRequest: nil,
            varsPostResponse: nil,
            bodyType: bodyType,
            multipartForm: nil,
            formUrlEncoded: nil,
            path: nil
        )
}
    
    private func tokenize(_ input: inout Substring) -> [String] {
        var tokens: [String] = []
        
        while !input.isEmpty {
            // Skip whitespace and line continuations
            while let first = input.first, first.isWhitespace || first == "\\" {
                if first == "\\" {
                    input.removeFirst()
                    if input.first == "\n" || input.first == "\r" {
                        if input.first == "\r" {
                            input.removeFirst()
                            if input.first == "\n" { input.removeFirst() }
                        } else {
                            input.removeFirst()
                        }
                    } else {
                        break 
                    }
                } else {
                    input.removeFirst()
                }
            }
            
            if input.isEmpty { break }
            
            if let token = try? CurlTokenParser().parse(&input) {
                tokens.append(token)
            } else {
                input.removeFirst()
            }
        }
        
        return tokens
    }
}

private struct CurlTokenParser: Parser {
    func parse(_ input: inout Substring) throws -> String {
        while let first = input.first, first.isWhitespace {
            input.removeFirst()
        }
        
        if input.isEmpty { throw RoutingError() }
        
        var result = ""
        var inQuotes = false
        var quoteChar: Character?
        
        func quotesMatch(_ open: Character, _ close: Character) -> Bool {
            if open == close { return true }
            if (open == "'" || open == "‘") && (close == "'" || close == "’") { return true }
            if (open == "\"" || open == "“") && (close == "\"" || close == "”") { return true }
            if "'‘".contains(open) && "'’".contains(close) { return true }
            if "\"“".contains(open) && "\"”".contains(close) { return true }
            return false
        }
        
        func isQuote(_ c: Character) -> Bool {
            return c == "'" || c == "\"" || c == "‘" || c == "’" || c == "“" || c == "”"
        }
        
        while !input.isEmpty {
            let c = input.first!
            
            if c == "\\" && !inQuotes {
                input.removeFirst()
                if let next = input.first {
                    if next == "\n" || next == "\r" {
                        if next == "\r" {
                            input.removeFirst()
                            if input.first == "\n" { input.removeFirst() }
                        } else {
                            input.removeFirst()
                        }
                        while let ws = input.first, ws.isWhitespace {
                            input.removeFirst()
                        }
                        continue
                    } else {
                        result.append(next)
                        input.removeFirst()
                    }
                }
                continue
            }
            
            if inQuotes {
                input.removeFirst()
                if quotesMatch(quoteChar!, c) {
                    inQuotes = false
                    quoteChar = nil
                } else {
                    result.append(c)
                }
            } else {
                if isQuote(c) {
                    inQuotes = true
                    quoteChar = c
                    input.removeFirst()
                } else if c.isWhitespace {
                    break
                } else if c == "\\" && input.count > 1 {
                    break
                } else {
                    result.append(c)
                    input.removeFirst()
                }
            }
        }
        
        return result
    }
}
