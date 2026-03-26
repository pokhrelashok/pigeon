//
//  pigeonTests.swift
//  pigeonTests
//
//  Created by Antigravity on 19/03/2026.
//

import Testing
import Foundation
@testable import pigeon

struct pigeonTests {
    @Test func variableResolver_resolvesPlaceholders() async throws {
        let resolver = VariableResolver()
        let vars = [
            EnvironmentVariable(key: "baseUrl", value: "https://api.example.com"),
            EnvironmentVariable(key: "token", value: "secret")
        ]
        let env = Environment(name: "Test", variables: vars)
        
        let input = "{{baseUrl}}/users?token={{token}}"
        let resolved = resolver.resolve(input, env: env)
        
        #expect(resolved == "https://api.example.com/users?token=secret")
    }
    
    @Test func variableResolver_handlesMissingVariables() async throws {
        let resolver = VariableResolver()
        let env = Environment(name: "Empty", variables: [])
        
        let input = "Hello {{name}}"
        let resolved = resolver.resolve(input, env: env)
        
        #expect(resolved == "Hello {{name}}")
    }

    @Test func requestBuilder_buildsURLRequest() async throws {
        let builder = RequestBuilder()
        let request = Request(
            name: "Get User",
            method: "GET",
            url: "{{baseUrl}}/user",
            headers: ["Authorization": "Bearer {{token}}"],
            query: nil,
            pathParams: nil,
            body: nil,
            auth: nil,
            seq: nil,
            tags: nil,
            docs: nil,
            varsPreRequest: nil,
            varsPostResponse: nil,
            bodyType: "none",
            multipartForm: nil,
            formUrlEncoded: nil
        )
        let vars = [
            EnvironmentVariable(key: "baseUrl", value: "https://api.com"),
            EnvironmentVariable(key: "token", value: "t123")
        ]
        let env = Environment(name: "Prod", variables: vars)
        
        let urlRequest = builder.build(from: request, env: env)
        
        #expect(urlRequest != nil)
        #expect(urlRequest?.url?.absoluteString == "https://api.com/user")
        #expect(urlRequest?.httpMethod == "GET")
        #expect(urlRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer t123")
    }
    
    @Test func requestBuilder_handlesBearerAuth() async throws {
        let builder = RequestBuilder()
        let request = Request(
            name: "Secure",
            method: "POST",
            url: "https://api.com",
            headers: nil,
            query: nil,
            pathParams: nil,
            body: "{\"key\": \"{{value}}\"}",
            auth: Auth(type: .bearer, token: "{{token}}", username: nil, password: nil),
            seq: nil,
            tags: nil,
            docs: nil,
            varsPreRequest: nil,
            varsPostResponse: nil,
            bodyType: "json",
            multipartForm: nil,
            formUrlEncoded: nil
        )
        let vars = [
            EnvironmentVariable(key: "token", value: "abc"),
            EnvironmentVariable(key: "value", value: "123")
        ]
        let env = Environment(name: "AuthTest", variables: vars)
        
        let urlRequest = builder.build(from: request, env: env)
        
        #expect(urlRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
        let bodyData = urlRequest?.httpBody
        let bodyString = String(data: bodyData!, encoding: .utf8)
        #expect(bodyString == "{\"key\": \"123\"}")
    }
    
    @Test func variableResolver_respectsIsEnabled() async throws {
        let resolver = VariableResolver()
        let vars = [
            EnvironmentVariable(key: "baseUrl", value: "https://api.com", isEnabled: false),
            EnvironmentVariable(key: "token", value: "secret", isEnabled: true)
        ]
        let env = Environment(name: "Test", variables: vars)
        
        let input = "{{baseUrl}}/{{token}}"
        let resolved = resolver.resolve(input, env: env)
        
        #expect(resolved == "{{baseUrl}}/secret")
    }
    
    @Test func variableResolver_handlesCRLF() async throws {
        let resolver = VariableResolver()
        // Simulate a value that might have been parsed with a trailing \r
        let vars = [
            EnvironmentVariable(key: "baseUrl", value: "https://api.com\r")
        ]
        let env = Environment(name: "Test", variables: vars)
        
        let input = "{{baseUrl}}/path"
        let resolved = resolver.resolve(input, env: env)
        
        #expect(resolved == "https://api.com\r/path")
        // This test shows that VariableResolver DOES preserve \r if it's in the value.
        // My fix in BruEnvironmentParser should have removed it.
    }
    
    @Test func bruEnvironmentParser_removesCRLF() async throws {
        let parser = BruEnvironmentParser()
        let content = "vars {\n  baseUrl: https://api.com\r\n}"
        let env = try parser.parse(content: content, name: "Test")
        
        #expect(env.variables.count == 1)
        #expect(env.variables[0].key == "baseUrl")
        #expect(env.variables[0].value == "https://api.com") // Should NOT have \r
    }
    
    @Test func variableResolver_resolvesRecursively() async throws {
        let resolver = VariableResolver()
        let vars = [
            EnvironmentVariable(key: "domain", value: "example.com"),
            EnvironmentVariable(key: "baseUrl", value: "https://{{domain}}")
        ]
        let env = Environment(name: "Test", variables: vars)
        
        let input = "{{baseUrl}}/path"
        let resolved = resolver.resolve(input, env: env)
        
        #expect(resolved == "https://example.com/path")
    }
    
    @Test func yamlEnvironmentParser_parsesCorrectly() async throws {
        let parser = YamlEnvironmentParser()
        let content = """
        name: local
        variables:
          - name: base_url
            value: https://toolost.test
          - secret: true
            name: auth_token
        """
        
        let env = parser.parse(content: content, name: "Fallback")
        
        #expect(env.name == "local") // This is where the user says it's failng (getting "auth_token")
        #expect(env.variables.count == 2)
        
        let baseUrl = env.variables.first { $0.key == "base_url" }
        #expect(baseUrl?.value == "https://toolost.test")
        
        let authToken = env.variables.first { $0.key == "auth_token" }
        #expect(authToken?.key == "auth_token")
        #expect(authToken?.isSecret == true)
    }
}
