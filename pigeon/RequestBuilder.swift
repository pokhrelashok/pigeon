//
//  RequestBuilder.swift
//  pigeon
//
//  Created by Antigravity on 19/03/2026.
//

import Foundation

struct RequestBuilder {
    private let resolver = VariableResolver()
    
    func build(from request: Request, env: Environment?) -> URLRequest? {
        let activeEnv = env ?? Environment(name: "Default", variables: [])
        var resolvedURLString = resolver.resolve(request.url, env: activeEnv)
        
        // Handle query parameters from the request.query dictionary
        if let queryParams = request.query, !queryParams.isEmpty {
            var components = URLComponents(string: resolvedURLString)
            var queryItems = components?.queryItems ?? []
            
            for (key, value) in queryParams {
                let resolvedKey = resolver.resolve(key, env: activeEnv)
                let resolvedValue = resolver.resolve(value, env: activeEnv)
                queryItems.append(URLQueryItem(name: resolvedKey, value: resolvedValue))
            }
            
            components?.queryItems = queryItems
            if let newURLString = components?.url?.absoluteString {
                resolvedURLString = newURLString
            }
        }
        
        guard let url = URL(string: resolvedURLString) else { return nil }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        
        // Add headers
        if let headers = request.headers {
            for (key, value) in headers {
                let resolvedKey = resolver.resolve(key, env: activeEnv)
                let resolvedValue = resolver.resolve(value, env: activeEnv)
                urlRequest.addValue(resolvedValue, forHTTPHeaderField: resolvedKey)
            }
        }
        
        // Add body
        if let bodyType = request.bodyType {
            let hasContentType = urlRequest.value(forHTTPHeaderField: "Content-Type") != nil
            
            switch bodyType {
            case "json":
                if let b = request.body { urlRequest.httpBody = resolver.resolve(b, env: activeEnv).data(using: .utf8) }
                if !hasContentType { urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type") }
            case "xml":
                if let b = request.body { urlRequest.httpBody = resolver.resolve(b, env: activeEnv).data(using: .utf8) }
                if !hasContentType { urlRequest.setValue("application/xml", forHTTPHeaderField: "Content-Type") }
            case "text":
                if let b = request.body { urlRequest.httpBody = resolver.resolve(b, env: activeEnv).data(using: .utf8) }
                if !hasContentType { urlRequest.setValue("text/plain", forHTTPHeaderField: "Content-Type") }
            case "form-urlencoded":
                if let formVars = request.formUrlEncoded, !formVars.isEmpty {
                    var components = URLComponents()
                    components.queryItems = formVars.map { URLQueryItem(name: resolver.resolve($0.key, env: activeEnv), value: resolver.resolve($0.value, env: activeEnv)) }
                    urlRequest.httpBody = components.query?.data(using: .utf8)
                    if !hasContentType { urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type") }
                }
            case "multipart-form":
                if let multiVars = request.multipartForm, !multiVars.isEmpty {
                    let boundary = "Boundary-\(UUID().uuidString)"
                    // Always set multipart boundary since it must match the runtime UUID
                    urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                    
                    var data = Data()
                    for param in multiVars {
                        let resolvedKey = resolver.resolve(param.key, env: activeEnv)
                        let resolvedValue = resolver.resolve(param.value, env: activeEnv)
                        
                        data.append("--\(boundary)\r\n".data(using: .utf8)!)
                        if param.type == "file" {
                            let fileURL = URL(fileURLWithPath: resolvedValue)
                            let filename = fileURL.lastPathComponent
                            let mimeType = "application/octet-stream"
                            
                            data.append("Content-Disposition: form-data; name=\"\(resolvedKey)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                            data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                            if let fileData = try? Data(contentsOf: fileURL) {
                                data.append(fileData)
                            }
                            data.append("\r\n".data(using: .utf8)!)
                        } else {
                            data.append("Content-Disposition: form-data; name=\"\(resolvedKey)\"\r\n\r\n".data(using: .utf8)!)
                            data.append("\(resolvedValue)\r\n".data(using: .utf8)!)
                        }
                    }
                    data.append("--\(boundary)--\r\n".data(using: .utf8)!)
                    urlRequest.httpBody = data
                }
            default:
                if let b = request.body { urlRequest.httpBody = resolver.resolve(b, env: activeEnv).data(using: .utf8) }
            }
        }
        
        // Add Auth
        if let auth = request.auth {
            switch auth.type {
            case .bearer:
                if let token = auth.token {
                    let resolvedToken = resolver.resolve(token, env: activeEnv)
                    urlRequest.addValue("Bearer \(resolvedToken)", forHTTPHeaderField: "Authorization")
                }
            case .basic:
                if let username = auth.username, let password = auth.password {
                    let resolvedUser = resolver.resolve(username, env: activeEnv)
                    let resolvedPass = resolver.resolve(password, env: activeEnv)
                    let credential = "\(resolvedUser):\(resolvedPass)"
                    if let data = credential.data(using: .utf8) {
                        let base64 = data.base64EncodedString()
                        urlRequest.addValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
                    }
                }
            case .digest:
                // Digest Auth is typically handled by the URLSession delegate or require a multi-step process.
                // For now, we will store the values. In a more complete implementation, 
                // we'd handle the 401 challenge.
                // However, we can add a placeholder or simple header if the server supports it (unlikely for Digest).
                break
            case .apiKey, .inherit:
                break
            case .none:
                break
            }
        }
        
        return urlRequest
    }
}
