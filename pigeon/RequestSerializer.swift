import Foundation

class RequestSerializer {
    static func toYaml(_ request: Request) -> String {
        var lines: [String] = []
        lines.append("name: \(request.name)")
        lines.append("method: \(request.method)")
        lines.append("url: \(request.url)")
        
        if let headers = request.headers, !headers.isEmpty {
            lines.append("headers:")
            for (key, value) in headers {
                lines.append("  \(key): \(value)")
            }
        }
        
        if let query = request.query, !query.isEmpty {
            lines.append("query:")
            for (key, value) in query {
                lines.append("  \(key): \(value)")
            }
        }
        
        if let body = request.body, !body.isEmpty {
            lines.append("body: |")
            let bodyLines = body.components(separatedBy: .newlines)
            for line in bodyLines {
                lines.append("  \(line)")
            }
        }
        
        if let seq = request.seq {
            lines.append("seq: \(seq)")
        }
        
        if let auth = request.auth, auth.type != .none {
            lines.append("auth:")
            lines.append("  type: \(auth.type.rawValue)")
            if let token = auth.token, !token.isEmpty {
                lines.append("  token: \(token)")
            }
            if let username = auth.username, !username.isEmpty {
                lines.append("  username: \(username)")
            }
            if let password = auth.password, !password.isEmpty {
                lines.append("  password: \(password)")
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    static func toBru(_ request: Request) -> String {
        var lines: [String] = []
        
        lines.append("meta {")
        lines.append("  name: \(request.name)")
        lines.append("  type: http")
        if let seq = request.seq {
            lines.append("  seq: \(seq)")
        }
        lines.append("}")
        lines.append("")
        
        lines.append("\(request.method.lowercased()) {")
        lines.append("  url: \(request.url)")
        if let auth = request.auth, auth.type != .none {
            lines.append("  auth: \(auth.type.rawValue)")
        }
        lines.append("}")
        lines.append("")
        
        if let auth = request.auth, auth.type != .none {
            lines.append("auth:\(auth.type.rawValue) {")
            if let token = auth.token, !token.isEmpty {
                lines.append("  token: \(token)")
            }
            if let username = auth.username, !username.isEmpty {
                lines.append("  username: \(username)")
            }
            if let password = auth.password, !password.isEmpty {
                lines.append("  password: \(password)")
            }
            lines.append("}")
            lines.append("")
        }
        
        if let headers = request.headers, !headers.isEmpty {
            lines.append("headers {")
            for (key, value) in headers {
                lines.append("  \(key): \(value)")
            }
            lines.append("}")
            lines.append("")
        }
        
        if let query = request.query, !query.isEmpty {
            lines.append("query {")
            for (key, value) in query {
                lines.append("  \(key): \(value)")
            }
            lines.append("}")
            lines.append("")
        }
        
        if let body = request.body, !body.isEmpty {
            lines.append("body {")
            lines.append("  \(body)")
            lines.append("}")
            lines.append("")
        }
        
        return lines.joined(separator: "\n")
    }
}
