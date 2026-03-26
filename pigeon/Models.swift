//
//  Models.swift
//  pigeon
//
//  Created by Antigravity on 19/03/2026.
//

import Foundation

struct Workspace: Codable, Identifiable {
    var id: String { path ?? name }
    
    func isID(_ id: String?, descendantOf parentID: String) -> Bool {
        guard let id = id else { return false }
        
        // Find the parent item first
        func findItem(in items: [SidebarItem], id: String) -> SidebarItem? {
            for item in items {
                if item.id == id { return item }
                if let children = item.children, let found = findItem(in: children, id: id) {
                    return found
                }
            }
            return nil
        }
        
        guard let parent = findItem(in: requests, id: parentID), let children = parent.children else {
            return false
        }
        
        // Check if id is in children of parent
        func contains(id: String, in items: [SidebarItem]) -> Bool {
            for item in items {
                if item.id == id { return true }
                if let subChildren = item.children, contains(id: id, in: subChildren) {
                    return true
                }
            }
            return false
        }
        
        return contains(id: id, in: children)
    }
    
    let name: String
    let path: String?
    let version: String
    var requests: [SidebarItem]
    var environments: [Environment]
    
    enum CodingKeys: String, CodingKey {
        case name, version, requests, environments, path
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.path = try? container.decode(String.self, forKey: .path)
        
        if let intVersion = try? container.decode(Int.self, forKey: .version) {
            self.version = "\(intVersion)"
        } else {
            self.version = (try? container.decode(String.self, forKey: .version)) ?? "1"
        }
        
        self.requests = []
        self.environments = (try? container.decode([Environment].self, forKey: .environments)) ?? []
    }
    
    init(name: String, path: String? = nil, version: String, requests: [SidebarItem] = [], environments: [Environment] = []) {
        self.name = name
        self.path = path
        self.version = version
        self.requests = requests
        self.environments = environments
    }
}

struct SidebarItem: Identifiable, Hashable, Codable {
    var id: String { url.path }
    var name: String
    var url: URL
    let isFolder: Bool
    var method: String?
    var children: [SidebarItem]? = nil
    
    enum CodingKeys: String, CodingKey {
        case name, url, isFolder, method, children
    }
    
    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
        lhs.url == rhs.url
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

struct Request: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    let method: String
    let url: String
    let headers: [String: String]?
    let query: [String: String]?
    let pathParams: [String: String]?
    let body: String?
    let auth: Auth?
    let seq: Int?
    let tags: [String]?
    let docs: String?
    let varsPreRequest: [String: String]?
    let varsPostResponse: [String: String]?
    let bodyType: String?
    let multipartForm: [MultipartFormData]?
    let formUrlEncoded: [KeyValuePair]?
    var path: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case name, method, url, headers, query, pathParams, body, auth, seq, tags, docs, varsPreRequest, varsPostResponse, bodyType, multipartForm, formUrlEncoded, path
    }
    
    static func == (lhs: Request, rhs: Request) -> Bool {
        func areEqual<T: Equatable>(_ a: [String: T]?, _ b: [String: T]?) -> Bool {
            let left = a ?? [:]
            let right = b ?? [:]
            return left == right
        }
        
        func areEqual<T: Equatable>(_ a: [T]?, _ b: [T]?) -> Bool {
            let left = a ?? []
            let right = b ?? []
            return left == right
        }
        
        func areStringsEqual(_ a: String?, _ b: String?) -> Bool {
            let left = a ?? ""
            let right = b ?? ""
            return left == right
        }

        return lhs.name == rhs.name &&
               lhs.method == rhs.method &&
               lhs.url == rhs.url &&
               areEqual(lhs.headers, rhs.headers) &&
               areEqual(lhs.query, rhs.query) &&
               areEqual(lhs.pathParams, rhs.pathParams) &&
               areStringsEqual(lhs.body, rhs.body) &&
               areStringsEqual(lhs.docs, rhs.docs) &&
               areEqual(lhs.varsPreRequest, rhs.varsPreRequest) &&
               areEqual(lhs.varsPostResponse, rhs.varsPostResponse) &&
               lhs.bodyType == rhs.bodyType &&
               areEqual(lhs.multipartForm, rhs.multipartForm) &&
               areEqual(lhs.formUrlEncoded, rhs.formUrlEncoded)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

import SwiftUI

extension Color {
    static func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": return .green
        case "POST": return .orange
        case "PUT": return .blue
        case "DELETE": return .red
        case "PATCH": return .purple
        case "HEAD": return .green
        case "OPTIONS": return .gray
        default: return .gray
        }
    }
}

struct KeyValuePair: Identifiable, Hashable, Codable, Equatable {
    var id: UUID = UUID()
    var key: String
    var value: String
    var isEnabled: Bool = true
    
    static func == (lhs: KeyValuePair, rhs: KeyValuePair) -> Bool {
        return lhs.key == rhs.key &&
               lhs.value == rhs.value &&
               lhs.isEnabled == rhs.isEnabled
    }
}

struct MultipartFormData: Identifiable, Hashable, Codable, Equatable {
    var id: UUID = UUID()
    var key: String
    var value: String
    var type: String // "text" or "file"
    var isEnabled: Bool = true
    
    static func == (lhs: MultipartFormData, rhs: MultipartFormData) -> Bool {
        return lhs.key == rhs.key &&
               lhs.value == rhs.value &&
               lhs.type == rhs.type &&
               lhs.isEnabled == rhs.isEnabled
    }
}

enum AuthType: String, Codable, CaseIterable {
    case none = "none"
    case basic = "basic"
    case bearer = "bearer"
    case digest = "digest"
    case apiKey = "apikey"
    case inherit = "inherit"
}

struct Auth: Codable, Equatable {
    var type: AuthType
    var token: String?
    var username: String?
    var password: String?
    
    init(type: AuthType = .none, token: String? = nil, username: String? = nil, password: String? = nil) {
        self.type = type
        self.token = token
        self.username = username
        self.password = password
    }
}

struct EnvironmentVariable: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var key: String
    var value: String
    var isSecret: Bool = false
    var isEnabled: Bool = true
    
    static func == (lhs: EnvironmentVariable, rhs: EnvironmentVariable) -> Bool {
        return lhs.key == rhs.key &&
               lhs.value == rhs.value &&
               lhs.isSecret == rhs.isSecret &&
               lhs.isEnabled == rhs.isEnabled
    }
}

struct Environment: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var variables: [EnvironmentVariable]
    var filePath: String?
    
    enum CodingKeys: String, CodingKey {
        case name, variables, filePath
    }
    
    init(name: String, variables: [EnvironmentVariable] = [], filePath: String? = nil) {
        self.name = name
        self.variables = variables
        self.filePath = filePath
    }
    
    static func == (lhs: Environment, rhs: Environment) -> Bool {
        return lhs.name == rhs.name && lhs.variables == rhs.variables
    }
}

struct Response: Codable {
    let statusCode: Int
    let executionTime: TimeInterval
    let headers: [String: String]
    let body: String
    let size: Int64
    let contentType: String?
}
