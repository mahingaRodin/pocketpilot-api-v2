import Vapor

struct ValidationService {
    static func validateEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    static func validatePassword(_ password: String) -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []
        
        if password.count < 8 {
            errors.append("Password must be at least 8 characters long")
        }
        
        if !password.contains(where: { $0.isUppercase }) {
            errors.append("Password must contain at least one uppercase letter")
        }
        
        if !password.contains(where: { $0.isLowercase }) {
            errors.append("Password must contain at least one lowercase letter")
        }
        
        if !password.contains(where: { $0.isNumber }) {
            errors.append("Password must contain at least one number")
        }
        
        let specialCharacters = "!@#$%^&*()_+-=[]{}|;:,.<>?"
        if !password.contains(where: { specialCharacters.contains($0) }) {
            errors.append("Password must contain at least one special character")
        }
        
        return (errors.isEmpty, errors)
    }
    
    static func validateAmount(_ amount: Double) -> Bool {
        return amount > 0 && amount <= 999999.99
    }
    
    static func validateDescription(_ description: String) -> Bool {
        return !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && description.count <= 255
    }
    
    static func validateNotes(_ notes: String?) -> Bool {
        guard let notes = notes else { return true }
        return notes.count <= 500
    }
}

// MARK: - Custom Validators
extension Validator where T == String {
    static var strongPassword: Validator<T> {
        .init {
            let validation = ValidationService.validatePassword($0)
            guard validation.isValid else {
                return ValidatorResult.failure(validation.errors.joined(separator: ", "))
            }
            return ValidatorResult.success
        }
    }
}

extension Validator where T == Double {
    static var validAmount: Validator<T> {
        .init {
            guard ValidationService.validateAmount($0) else {
                return ValidatorResult.failure("Amount must be between 0.01 and 999,999.99")
            }
            return ValidatorResult.success
        }
    }
}