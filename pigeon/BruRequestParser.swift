import Foundation

class BruRequestParser: RequestParser {
    func canHandle(fileExtension: String) -> Bool {
        return fileExtension == "bru"
    }
    
    func parse(content: String, url: URL) throws -> Request {
        let bruParser = BruParser()
        let bruRequest = try bruParser.parse(content: content)
        
        var auth: Auth? = nil
        if bruRequest.authType != .none {
            auth = Auth(
                type: bruRequest.authType,
                token: bruRequest.authToken,
                username: bruRequest.authUsername,
                password: bruRequest.authPassword
            )
        }
        
        var request = Request(
            name: bruRequest.name,
            method: bruRequest.method,
            url: bruRequest.url,
            headers: bruRequest.headers,
            query: bruRequest.query,
            pathParams: bruRequest.pathParams,
            body: bruRequest.body,
            auth: auth,
            seq: bruRequest.seq,
            tags: nil,
            docs: bruRequest.docs,
            varsPreRequest: bruRequest.varsPreRequest,
            varsPostResponse: bruRequest.varsPostResponse,
            bodyType: bruRequest.bodyType,
            multipartForm: bruRequest.multipartForm.isEmpty ? nil : bruRequest.multipartForm,
            formUrlEncoded: bruRequest.formUrlEncoded.isEmpty ? nil : bruRequest.formUrlEncoded.map { KeyValuePair(key: $0.key, value: $0.value) }
        )
        request.path = url.path
        return request
    }
}
