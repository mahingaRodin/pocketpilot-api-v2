import Vapor

// MARK: - Registration
struct UserRegistrationRequest: Content, Validatable {
    let email: String
    let password: String
    let confirmPassword: String
    let firstName: String
    let lastName: String
    
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(8...))
        validations.add("firstName", as: String.self, is: !.empty)
        validations.add("lastName", as: String.self, is: !.empty)
    }
}

// MARK: - Login
struct UserLoginRequest: Content, Validatable {
    let email: String
    let password: String
    
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: !.empty)
    }
}

// MARK: - Response
struct UserResponse: Content {
    let id: UUID
    let email: String
    let firstName: String
    let lastName: String
    let createdAt: Date?
    
    init(user: User) {
        self.id = user.id!
        self.email = user.email
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.createdAt = user.createdAt
    }
}

// MARK: - Authentication Response
struct AuthResponse: Content {
    let user: UserResponse
    let token: String
}

// MARK: - Profile Update
struct UserUpdateRequest: Content, Validatable {
    let firstName: String?
    let lastName: String?
    
    static func validations(_ validations: inout Validations) {
        validations.add("firstName", as: String?.self, is: .nil || !.empty, required: false)
        validations.add("lastName", as: String?.self, is: .nil || !.empty, required: false)
    }
}