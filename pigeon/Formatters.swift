//
//  Formatters.swift
//  pigeon
//
//  Created by Antigravity on 20/03/2026.
//

import Foundation

protocol BodyFormatter {
    func canFormat(contentType: String?, bodyType: String?) -> Bool
    func format(_ body: String) -> String
}

struct JSONFormatter: BodyFormatter {
    func canFormat(contentType: String?, bodyType: String?) -> Bool {
        if let bodyType = bodyType?.lowercased(), bodyType == "json" {
            return true
        }
        
        guard let contentType = contentType?.lowercased() else { return false }
        return contentType.contains("application/json") || contentType.contains("json")
    }
    
    func format(_ body: String) -> String {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return body }
        guard let data = body.data(using: .utf8) else { return body }
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            let formattedData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
            return String(data: formattedData, encoding: .utf8) ?? body
        } catch {
            return body
        }
    }
}

class FormatterService {
    static let shared = FormatterService()
    
    private let formatters: [BodyFormatter] = [
        JSONFormatter()
    ]
    
    func format(body: String, contentType: String? = nil, bodyType: String? = nil) -> String {
        for formatter in formatters {
            if formatter.canFormat(contentType: contentType, bodyType: bodyType) {
                return formatter.format(body)
            }
        }
        return body
    }
    
    func hasFormatter(contentType: String? = nil, bodyType: String? = nil) -> Bool {
        return formatters.contains { $0.canFormat(contentType: contentType, bodyType: bodyType) }
    }
}
