import Foundation

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
