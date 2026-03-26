import Foundation
import Parsing

enum BruBlockType {
    case dictionary([String: String])
    case text(String)
    case array([String])
}

struct BruBlock {
    let tag: String
    let subType: String?
    let content: BruBlockType
}

struct RoutingError: Error {}

struct BruBlockParser: Parser {
    func parse(_ input: inout Substring) throws -> BruBlock {
        // Skip leading whitespace
        try input.trimPrefix(while: { $0.isWhitespace })
        
        let tagPrefix = input.prefix(while: { $0.isLetter || $0.isNumber || $0 == "-" })
        guard !tagPrefix.isEmpty else { throw RoutingError() }
        let tag = String(tagPrefix)
        input.removeFirst(tagPrefix.count)
        
        var subType: String? = nil
        if input.first == ":" {
            input.removeFirst()
            let subTypePrefix = input.prefix(while: { $0.isLetter || $0.isNumber || $0 == "-" })
            subType = String(subTypePrefix)
            input.removeFirst(subTypePrefix.count)
        }
        
        try input.trimPrefix(while: { $0.isWhitespace })
        guard let firstChar = input.first else { throw RoutingError() }
        
        if firstChar == "{" {
            input.removeFirst()
            var depth = 1
            var currentIndex = input.startIndex
            
            while currentIndex < input.endIndex {
                let char = input[currentIndex]
                if char == "{" { depth += 1 }
                else if char == "}" {
                    depth -= 1
                    if depth == 0 { break }
                }
                currentIndex = input.index(after: currentIndex)
            }
            
            guard depth == 0 else { throw RoutingError() }
            
            let contentStr = String(input[..<currentIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            input = input[input.index(after: currentIndex)...] // consume '}'
            
            let textTags = ["body", "docs", "tests", "script"]
            if textTags.contains(tag) && subType != "multipart-form" && subType != "form-urlencoded" {
                return BruBlock(tag: tag, subType: subType, content: .text(contentStr))
            } else {
                return BruBlock(tag: tag, subType: subType, content: .dictionary(parseDictionary(contentStr)))
            }
        } else if firstChar == "[" {
            input.removeFirst()
            var depth = 1
            var currentIndex = input.startIndex
            
            while currentIndex < input.endIndex {
                let char = input[currentIndex]
                if char == "[" { depth += 1 }
                else if char == "]" {
                    depth -= 1
                    if depth == 0 { break }
                }
                currentIndex = input.index(after: currentIndex)
            }
            
            guard depth == 0 else { throw RoutingError() }
            
            let contentStr = String(input[..<currentIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            input = input[input.index(after: currentIndex)...] // consume ']'
            
            let arrayItems = contentStr.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("~") }
            
            return BruBlock(tag: tag, subType: subType, content: .array(arrayItems))
        } else {
            throw RoutingError()
        }
    }
    
    private func parseDictionary(_ contentStr: String) -> [String: String] {
        var dict: [String: String] = [:]
        let lines = contentStr.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("~") || trimmed.hasPrefix("#") { continue }
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = trimmed[..<colonIndex].trimmingCharacters(in: .whitespaces)
                let value = trimmed[trimmed.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
                dict[key] = value
            }
        }
        return dict
    }
}

class BruParser {
    struct BruRequest {
        var name: String = ""
        var method: String = "GET"
        var url: String = ""
        var headers: [String: String] = [:]
        var query: [String: String] = [:]
        var body: String = ""
        var authType: AuthType = .none
        var authToken: String?
        var authUsername: String?
        var authPassword: String?
        var seq: Int?
        var docs: String?
        var pathParams: [String: String] = [:]
        var varsPreRequest: [String: String] = [:]
        var varsPostResponse: [String: String] = [:]
        var bodyType: String = "none"
        var multipartForm: [MultipartFormData] = []
        var formUrlEncoded: [String: String] = [:]
        var secretVars: [String] = []
    }
    
    func parse(content: String) throws -> BruRequest {
        var request = BruRequest()
        
        let parser = Many {
            BruBlockParser()
        }
        
        var input = content[...]
        var blocks: [BruBlock] = []
        do {
            blocks = try parser.parse(&input)
        } catch {
            print("Parsing error: \(error)")
            // Fallback: If partial parse is fine, or throw. For now we will use what we got or throw.
            // Since `Many` shouldn't fail completely if it stops parsing, we can just use `blocks`.
        }
        
        let methods = ["get", "post", "put", "delete", "patch", "head", "options"]
        
        for block in blocks {
            switch block.content {
            case .dictionary(let dict):
                if block.tag == "meta" {
                    request.name = dict["name"] ?? ""
                    if let seqStr = dict["seq"], let seq = Int(seqStr) {
                        request.seq = seq
                    }
                } else if methods.contains(block.tag.lowercased()) {
                    request.method = block.tag.uppercased()
                    request.url = dict["url"] ?? ""
                    request.authType = AuthType(rawValue: dict["auth"] ?? "none") ?? .none
                } else if block.tag == "headers" {
                    request.headers = dict
                } else if block.tag == "query" {
                    request.query = dict
                } else if block.tag == "params" && block.subType == "path" {
                    request.pathParams = dict
                } else if block.tag == "params" && block.subType == "query" {
                    request.query.merge(dict) { (_, new) in new }
                } else if block.tag == "auth" && block.subType == "bearer" {
                    request.authToken = dict["token"]
                } else if block.tag == "auth" && block.subType == "basic" {
                    request.authUsername = dict["username"]
                    request.authPassword = dict["password"]
                } else if block.tag == "auth" && block.subType == "digest" {
                    request.authUsername = dict["username"]
                    request.authPassword = dict["password"]
                }
 else if block.tag == "vars" && block.subType == "pre-request" {
                    request.varsPreRequest = dict
                } else if block.tag == "vars" && block.subType == "post-response" {
                    request.varsPostResponse = dict
                } else if block.tag == "body" {
                    request.bodyType = block.subType ?? "text"
                    if request.bodyType == "form-urlencoded" {
                        request.formUrlEncoded = dict
                    } else if request.bodyType == "multipart-form" {
                        request.multipartForm = dict.map { (k, v) in
                            if v.hasPrefix("@file(") && v.hasSuffix(")") {
                                let path = String(v.dropFirst(6).dropLast())
                                return MultipartFormData(key: k, value: path, type: "file")
                            } else {
                                return MultipartFormData(key: k, value: v, type: "text")
                            }
                        }
                    }
                }
            case .text(let text):
                if block.tag == "body" {
                    request.bodyType = block.subType ?? "text"
                    request.body = text
                } else if block.tag == "docs" {
                    request.docs = text
                }
            case .array(let items):
                if block.tag == "vars" && block.subType == "secret" {
                    request.secretVars = items
                }
            }
        }
        
        return request
    }
}
