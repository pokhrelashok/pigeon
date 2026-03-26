import Foundation

class JSONRequestParser: RequestParser {
    func canHandle(fileExtension: String) -> Bool {
        return fileExtension == "json"
    }
    
    func parse(content: String, url: URL) throws -> Request {
        guard let data = content.data(using: .utf8) else {
            throw NSError(domain: "JSONRequestParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert content to data"])
        }
        var request = try JSONDecoder().decode(Request.self, from: data)
        request.path = url.path
        return request
    }
}
