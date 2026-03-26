import XCTest
@testable import pigeon

final class PigeonParserTests: XCTestCase {
    
    func testBruParserBasic() throws {
        let content = """
        meta {
          name: Get Todos
          type: http
          seq: 1
        }

        get {
          url: https://jsonplaceholder.typicode.com/todos/1
        }

        headers {
          Content-Type: application/json
          Authorization: Bearer test-token
        }
        """
        
        let parser = BruParser()
        let request = try parser.parse(content: content)
        
        XCTAssertEqual(request.name, "Get Todos")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.url, "https://jsonplaceholder.typicode.com/todos/1")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(request.headers["Authorization"], "Bearer test-token")
        XCTAssertEqual(request.seq, 1)
    }
    
    func testBruParserWithBody() throws {
        let content = """
        meta {
          name: Create Todo
          type: http
        }

        post {
          url: https://jsonplaceholder.typicode.com/todos
        }

        body {
          {
            "title": "test",
            "completed": false
          }
        }
        """
        
        let parser = BruParser()
        let request = try parser.parse(content: content)
        
        XCTAssertEqual(request.method, "POST")
        XCTAssertTrue(request.body.contains("\"title\": \"test\""))
    }
    
    func testYamlParserBasic() throws {
        let yaml = """
        name: Get User
        method: GET
        url: https://api.example.com/user
        headers:
          Authorization: Bearer token123
          Accept: application/json
        seq: 5
        """
        
        let data = YamlParser.parse(yaml)
        
        XCTAssertEqual(data["name"] as? String, "Get User")
        XCTAssertEqual(data["method"] as? String, "GET")
        XCTAssertEqual(data["seq"] as? Int, 5) // Yams correctly parses integers
        
        if let headers = data["headers"] as? [String: Any] {
            XCTAssertEqual(headers["Authorization"] as? String, "Bearer token123")
            XCTAssertEqual(headers["Accept"] as? String, "application/json")
        } else {
            XCTFail("Headers should be a dictionary")
        }
    }
    
    func testYamlParserNested() throws {
        let yaml = """
        info:
          name: Login
          version: 1.0
        auth:
          type: basic
          credentials:
            user: admin
            pass: secret
        """
        
        let data = YamlParser.parse(yaml)
        
        if let info = data["info"] as? [String: Any] {
            XCTAssertEqual(info["name"] as? String, "Login")
        }
        
        if let auth = data["auth"] as? [String: Any],
           let creds = auth["credentials"] as? [String: Any] {
            XCTAssertEqual(creds["user"] as? String, "admin")
            XCTAssertEqual(creds["pass"] as? String, "secret")
        } else {
            XCTFail("Auth should have nested credentials")
        }
    }
    
    func testBruParserAdvancedUserCase() throws {
        let content = """
        meta {
          name: Add Transaction
          type: http
          seq: 3
        }

        post {
          url: {{baseUrl}}/api/portfolios/:id/transactions
          body: json
          auth: bearer
        }

        headers {
          x-api-key: {{apiKey}}
        }

        params:path {
          id: portfolio-uuid
        }

        auth:bearer {
          token: {{token}}
        }

        body:json {
          {
            "id": "optional-uuid-v4",
            "stock_symbol": "NABIL",
            "type": "SECONDARY_BUY",
            "quantity": 100
          }
        }

        docs {
          ## API Key Usage
          This endpoint requires an API Key.
        }
        """
        
        let parser = BruParser()
        let request = try parser.parse(content: content)
        
        XCTAssertEqual(request.name, "Add Transaction")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url, "{{baseUrl}}/api/portfolios/:id/transactions")
        XCTAssertEqual(request.headers["x-api-key"], "{{apiKey}}")
        XCTAssertEqual(request.pathParams["id"], "portfolio-uuid")
        XCTAssertEqual(request.authType, .bearer)
        XCTAssertEqual(request.authToken, "{{token}}")
        XCTAssertTrue(request.body.contains("\"stock_symbol\": \"NABIL\""))
        XCTAssertTrue(request.docs!.contains("## API Key Usage"))
    }
    
    func testBruParserMultipartAndForms() throws {
        let content = """
        meta {
          name: Upload
          type: http
        }

        post {
          url: https://api.example.com/upload
          body: multipart-form
        }

        body:multipart-form {
          username: testuser
          profile_pic: @file(path/to/image.png)
        }
        """
        
        let parser = BruParser()
        let request = try parser.parse(content: content)
        
        XCTAssertEqual(request.bodyType, "multipart-form")
        XCTAssertEqual(request.multipartForm.count, 2)
        
        // Sort to ensure deterministic index access
        let sorted = request.multipartForm.sorted(by: { $0.key < $1.key })
        
        XCTAssertEqual(sorted[0].key, "profile_pic")
        XCTAssertEqual(sorted[0].value, "path/to/image.png")
        XCTAssertEqual(sorted[0].type, "file")
        
        XCTAssertEqual(sorted[1].key, "username")
        XCTAssertEqual(sorted[1].value, "testuser")
        XCTAssertEqual(sorted[1].type, "text")
    }
    
    func testBruParserFormUrlEncoded() throws {
        let content = """
        post {
          url: https://api.example.com/oauth
          body: form-urlencoded
        }

        body:form-urlencoded {
          client_id: 1234
          client_secret: secret
        }
        """
        
        let parser = BruParser()
        let request = try parser.parse(content: content)
        
        XCTAssertEqual(request.bodyType, "form-urlencoded")
        XCTAssertEqual(request.formUrlEncoded["client_id"], "1234")
        XCTAssertEqual(request.formUrlEncoded["client_secret"], "secret")
    }
    
    func testBruParserFailingJsonBody() throws {
        let content = """
        post {
          url: https://api.example.com
        }

        body:json {
          {
            "symbols": ["NABIL", "AHPC", "NICA", "UPPER"]
          }
        }
        """
        
        let parser = BruParser()
        let request = try parser.parse(content: content)
        
        XCTAssertTrue(request.body.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("}"))
        XCTAssertTrue(request.body.contains("UPPER"))
    }
    
    func testBruParserVariablesInUrl() throws {
        let content = """
        get {
          url: {{protocol}}://{{host}}:{{port}}/api/{{version}}/resource
        }
        """
        let parser = BruParser()
        let request = try parser.parse(content: content)
        XCTAssertEqual(request.url, "{{protocol}}://{{host}}:{{port}}/api/{{version}}/resource")
    }
    
    func testBrunoYamlParser() throws {
        let yaml = """
        http:
          method: post
          url: https://api.example.com/login
          headers:
            Content-Type: application/json
            Authorization: Bearer test-token
        """
        
        let parser = BrunoYamlRequestParser()
        let request = try parser.parse(content: yaml, url: URL(fileURLWithPath: "/test.yaml"))
        
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url, "https://api.example.com/login")
        XCTAssertEqual(request.headers?["Content-Type"], "application/json")
        XCTAssertEqual(request.headers?["Authorization"], "Bearer test-token")
    }
    func testBruParserBasicAndDigestAuth() throws {
        let basicContent = """
        post {
          url: https://api.example.com/basic
          auth: basic
        }
        auth:basic {
          username: user123
          password: pass123
        }
        """
        
        let parser = BruParser()
        let basicRequest = try parser.parse(content: basicContent)
        XCTAssertEqual(basicRequest.authType, .basic)
        XCTAssertEqual(basicRequest.authUsername, "user123")
        XCTAssertEqual(basicRequest.authPassword, "pass123")
        
        let digestContent = """
        post {
          url: https://api.example.com/digest
          auth: digest
        }
        auth:digest {
          username: digestUser
          password: digestPassword
        }
        """
        
        let digestRequest = try parser.parse(content: digestContent)
        XCTAssertEqual(digestRequest.authType, .digest)
        XCTAssertEqual(digestRequest.authUsername, "digestUser")
        XCTAssertEqual(digestRequest.authPassword, "digestPassword")
    }
    
    // MARK: - Curl Parser Tests
    
    func testCurlParserSimpleGet() throws {
        let curl = "curl https://api.example.com/users"
        guard let request = CurlParser.shared.parse(curl) else {
            XCTFail("Failed to parse simple GET")
            return
        }
        
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.url, "https://api.example.com/users")
    }
    
    func testCurlParserGetWithHeaders() throws {
        let curl = "curl https://api.example.com -H 'Accept: application/json' -H 'X-Header: value'"
        guard let request = CurlParser.shared.parse(curl) else {
            XCTFail("Failed to parse GET with headers")
            return
        }
        
        XCTAssertEqual(request.headers?["Accept"], "application/json")
        XCTAssertEqual(request.headers?["X-Header"], "value")
    }
    
    func testCurlParserPostWithData() throws {
        let curl = "curl -X POST https://api.example.com/login -d '{\"user\":\"test\"}'"
        guard let request = CurlParser.shared.parse(curl) else {
            XCTFail("Failed to parse POST with data")
            return
        }
        
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.body, "{\"user\":\"test\"}")
        XCTAssertEqual(request.bodyType, "json")
    }
    
    func testCurlParserBearerAuthExtraction() throws {
        let curl = "curl https://api.example.com -H 'Authorization: Bearer my-token-123'"
        guard let request = CurlParser.shared.parse(curl) else {
            XCTFail("Failed to parse Bearer auth")
            return
        }
        
        // Should be extracted to auth property
        XCTAssertNotNil(request.auth)
        XCTAssertEqual(request.auth?.type, .bearer)
        XCTAssertEqual(request.auth?.token, "my-token-123")
        
        // Should be removed from headers
        XCTAssertNil(request.headers?["Authorization"])
        XCTAssertNil(request.headers?["authorization"])
    }
    
    func testCurlParserBasicAuthExtraction() throws {
        // user:pass -> dXNlcjpwYXNz
        let curl = "curl https://api.example.com -H 'Authorization: Basic dXNlcjpwYXNz'"
        guard let request = CurlParser.shared.parse(curl) else {
            XCTFail("Failed to parse Basic auth")
            return
        }
        
        XCTAssertNotNil(request.auth)
        XCTAssertEqual(request.auth?.type, .basic)
        XCTAssertEqual(request.auth?.username, "user")
        XCTAssertEqual(request.auth?.password, "pass")
        
        XCTAssertNil(request.headers?["Authorization"])
    }
    
    func testCurlParserCurlyQuotes() throws {
        let curl = "curl ‘https://api.example.com’ -H “Authorization: Bearer my-token-123”"
        guard let request = CurlParser.shared.parse(curl) else {
            XCTFail("Failed to parse curl with curly quotes")
            return
        }
        
        XCTAssertEqual(request.url, "https://api.example.com")
        XCTAssertEqual(request.auth?.token, "my-token-123")
    }
    
    func testCurlParserLineContinuations() throws {
        let curl = """
curl 'https://api.example.com' \\
  -H 'Accept: application/json' \\
  -d '{"key": "value"}'
"""
        guard let request = CurlParser.shared.parse(curl) else {
            XCTFail("Failed to parse curl with line continuations")
            return
        }
        
        XCTAssertEqual(request.url, "https://api.example.com")
        XCTAssertEqual(request.headers?["Accept"], "application/json")
        XCTAssertEqual(request.body, "{\"key\": \"value\"}")
    }
    
    func testCurlParserCookies() throws {
        let curl = "curl https://api.example.com -b 'session=123' -b 'prefs=dark'"
        guard let request = CurlParser.shared.parse(curl) else {
            XCTFail("Failed to parse curl with cookies")
            return
        }
        
        XCTAssertTrue(request.headers?["Cookie"]?.contains("session=123") ?? false)
        XCTAssertTrue(request.headers?["Cookie"]?.contains("prefs=dark") ?? false)
    }
}
