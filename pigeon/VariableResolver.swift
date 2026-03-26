//
//  VariableResolver.swift
//  pigeon
//
//  Created by Antigravity on 19/03/2026.
//

import Foundation

struct VariableResolver {
    func resolve(_ input: String, env: Environment) -> String {
        var result = input
        var previousResult: String
        var iterations = 0
        let maxIterations = 10 // Prevent infinite loops for circular references
        
        repeat {
            previousResult = result
            for v in env.variables where v.isEnabled {
                let placeholder = "{{\(v.key)}}"
                result = result.replacingOccurrences(of: placeholder, with: v.value)
            }
            iterations += 1
        } while result != previousResult && iterations < maxIterations
        
        return result
    }
    
    /// Returns a dictionary of variable keys and their resolved values for all placeholders found in the input.
    func resolveMapping(in input: String, env: Environment) -> [String: String] {
        var result: [String: String] = [:]
        let pattern = #"\{\{(.*?)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [:] }
        
        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = regex.matches(in: input, options: [], range: nsRange)
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: input) {
                let key = String(input[range])
                // Find the variable in the environment
                if let v = env.variables.first(where: { $0.key == key && $0.isEnabled }) {
                    result[key] = v.value
                }
            }
        }
        return result
    }
}
