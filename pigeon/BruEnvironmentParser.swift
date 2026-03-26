import Foundation

class BruEnvironmentParser {
    enum ParsingError: Error {
        case invalidFormat
    }
    
    func parse(content: String, name: String, filePath: String? = nil) throws -> Environment {
        var variables: [EnvironmentVariable] = []
        var secretKeys: Set<String> = []
        
        // 1. Parse vars:secret [ token, apiKey ]
        let secretPattern = #"(?s)vars:secret\s*\[\s*(.*?)\s*\]"#
        if let secretMatch = content.range(of: secretPattern, options: .regularExpression) {
            let keysStr = String(content[secretMatch])
            if let firstBracket = keysStr.firstIndex(of: "["), let lastBracket = keysStr.lastIndex(of: "]") {
                let inner = keysStr[keysStr.index(after: firstBracket)..<lastBracket]
                let keys = inner.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                secretKeys = Set(keys)
            }
        }
        
        // 2. Parse vars { baseUrl: http://localhost:3000 }
        let varsPattern = #"(?s)vars\s*\{([\s\S]*?)\}"#
        if let varsMatch = content.range(of: varsPattern, options: .regularExpression) {
            let block = String(content[varsMatch])
            let lines = block.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty && trimmed != "vars {" && trimmed != "}" else { continue }
                
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !key.isEmpty {
                        variables.append(EnvironmentVariable(
                            key: key,
                            value: value,
                            isSecret: secretKeys.contains(key),
                            isEnabled: true
                        ))
                    }
                }
            }
        }
        
        return Environment(name: name, variables: variables, filePath: filePath)
    }
    
    func serialize(_ env: Environment) -> String {
        var output = "vars {\n"
        for v in env.variables {
            output += "  \(v.key): \(v.value)\n"
        }
        output += "}\n"
        
        let secrets = env.variables.filter { $0.isSecret }.map { $0.key }
        if !secrets.isEmpty {
            output += "vars:secret [\n"
            output += "  \(secrets.joined(separator: ",\n  "))\n"
            output += "]\n"
        }
        
        return output
    }
}
