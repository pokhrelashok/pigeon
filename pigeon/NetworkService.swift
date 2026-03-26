//
//  NetworkService.swift
//  pigeon
//
//  Created by Antigravity on 19/03/2026.
//

import Foundation

class NetworkService: ObservableObject {
    func execute(request: URLRequest) async throws -> Response {
        let start = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let executionTime = Date().timeIntervalSince(start)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, element in
            if let key = element.key as? String, let value = element.value as? String {
                result[key] = value
            }
        }
        
        let body = String(data: data, encoding: .utf8) ?? ""
        
        let size = Int64(data.count)
        let contentType = httpResponse.mimeType
        
        return Response(
            statusCode: httpResponse.statusCode,
            executionTime: executionTime,
            headers: headers,
            body: body,
            size: size,
            contentType: contentType
        )
    }
}
