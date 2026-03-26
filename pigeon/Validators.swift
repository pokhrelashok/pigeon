//
//  Validators.swift
//  pigeon
//
//  Created by Antigravity on 20/03/2026.
//

import Foundation

protocol BodyValidator {
    func canValidate(contentType: String?, bodyType: String?) -> Bool
    func validate(_ body: String) -> ValidationResult
}

struct ValidationResult {
    let isValid: Bool
    let errorMessage: String?
}

struct JSONValidator: BodyValidator {
    func canValidate(contentType: String?, bodyType: String?) -> Bool {
        return contentType?.contains("application/json") == true || bodyType == "json"
    }
    
    func validate(_ body: String) -> ValidationResult {
        guard !body.isEmpty else { return ValidationResult(isValid: true, errorMessage: nil) }
        guard let data = body.data(using: .utf8) else {
            return ValidationResult(isValid: false, errorMessage: "Invalid encoding")
        }
        do {
            try JSONSerialization.jsonObject(with: data, options: [])
            return ValidationResult(isValid: true, errorMessage: nil)
        } catch {
            return ValidationResult(isValid: false, errorMessage: error.localizedDescription)
        }
    }
}

class ValidatorService {
    static let shared = ValidatorService()
    
    private let validators: [BodyValidator] = [
        JSONValidator()
    ]
    
    func validate(body: String, contentType: String? = nil, bodyType: String? = nil) -> ValidationResult {
        guard let validator = validators.first(where: { $0.canValidate(contentType: contentType, bodyType: bodyType) }) else {
            return ValidationResult(isValid: true, errorMessage: nil)
        }
        return validator.validate(body)
    }
    
    func hasValidator(contentType: String? = nil, bodyType: String? = nil) -> Bool {
        return validators.contains(where: { $0.canValidate(contentType: contentType, bodyType: bodyType) })
    }
}
