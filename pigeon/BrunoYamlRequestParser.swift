import Foundation

class BrunoYamlRequestParser: RequestParser {
    func canHandle(fileExtension: String) -> Bool {
        return fileExtension == "yml" || fileExtension == "yaml"
    }
    
    func parse(content: String, url: URL) throws -> Request {
        let yamlData = YamlParser.parse(content)
        
        let info = yamlData["info"] as? [String: Any]
        let http = yamlData["http"] as? [String: Any]
        
        let name = (info?["name"] as? String) ?? (yamlData["name"] as? String) ?? url.deletingPathExtension().lastPathComponent
        let method = (http?["method"] as? String) ?? (yamlData["method"] as? String) ?? "GET"
        let requestUrl = (http?["url"] as? String) ?? (yamlData["url"] as? String) ?? ""
        
        let headers = parseKeyValueList(http?["headers"])
        let queryParams = parseKeyValueList(http?["params"], filterType: "query")
        let pathParams = parseKeyValueList(http?["params"], filterType: "path")
        
        // Body mapping
        var body: String? = nil
        var bodyType: String = "none"
        if let bodyData = http?["body"] as? [String: Any] {
            bodyType = (bodyData["type"] as? String) ?? "none"
            body = bodyData["data"] as? String
        }
        
        // Auth mapping
        var auth: Auth? = nil
        if let authData = http?["auth"] {
            if let authDict = authData as? [String: Any] {
                let typeStr = (authDict["type"] as? String) ?? "none"
                let type = AuthType(rawValue: typeStr) ?? .none
                
                switch type {
                case .bearer:
                    auth = Auth(type: .bearer, token: authDict["token"] as? String)
                case .basic:
                    auth = Auth(type: .basic, username: authDict["username"] as? String, password: authDict["password"] as? String)
                case .digest:
                    auth = Auth(type: .digest, username: authDict["username"] as? String, password: authDict["password"] as? String)
                case .apiKey:
                    auth = Auth(type: .apiKey, token: authDict["value"] as? String, username: authDict["key"] as? String)
                case .inherit:
                    auth = Auth(type: .inherit)
                case .none:
                    auth = Auth(type: .none)
                }
            } else if let authStr = authData as? String, authStr == "inherit" {
                auth = Auth(type: .inherit)
            }
        }
        
        var request = Request(
            name: name,
            method: method.uppercased(),
            url: requestUrl,
            headers: headers,
            query: queryParams,
            pathParams: pathParams,
            body: body,
            auth: auth,
            seq: info?["seq"] as? Int,
            tags: info?["tags"] as? [String],
            docs: yamlData["docs"] as? String,
            varsPreRequest: nil,
            varsPostResponse: nil,
            bodyType: bodyType,
            multipartForm: nil, // TODO: Implement if needed
            formUrlEncoded: nil  // TODO: Implement if needed
        )
        request.path = url.path
        return request
    }
    
    private func parseKeyValueList(_ data: Any?, filterType: String? = nil) -> [String: String]? {
        var result: [String: String] = [:]
        
        if let list = data as? [[String: Any]] {
            for item in list {
                let name = (item["name"] as? String) ?? (item["key"] as? String)
                let value = item["value"] as? String
                
                if let name = name, let value = value {
                    // Check if type matches if requested
                    if let filterType = filterType {
                        let type = (item["type"] as? String) ?? "query"
                        if type != filterType { continue }
                    }
                    result[name] = value
                }
            }
        } else if let dict = data as? [String: Any] {
            for (key, val) in dict {
                if let stringVal = val as? String {
                    result[key] = stringVal
                } else {
                    result[key] = String(describing: val)
                }
            }
        }
        
        return result.isEmpty ? nil : result
    }
}
