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
        validations.add("password", as: String.self, is: .strongPassword)
        validations.add("firstName", as: String.self, is: !.empty)
        validations.add("lastName", as: String.self, is: !.empty)
    }
}

// MARK: - Login
struct UserLoginRequest: Content, Validatable {
    let email: String
    let password: String
    let deviceInfo: String?
    
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: !.empty)
    }
}

// MARK: - Password Reset
struct PasswordResetRequest: Content, Validatable {
    let email: String
    
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
    }
}

struct PasswordResetConfirmation: Content, Validatable {
    let token: String
    let newPassword: String
    let confirmPassword: String
    
    static func validations(_ validations: inout Validations) {
        validations.add("token", as: String.self, is: !.empty)
        validations.add("newPassword", as: String.self, is: .strongPassword)
    }
}

// MARK: - Change Password
struct ChangePasswordRequest: Content, Validatable {
    let currentPassword: String
    let newPassword: String
    let confirmPassword: String
    
    static func validations(_ validations: inout Validations) {
        validations.add("currentPassword", as: String.self, is: !.empty)
        validations.add("newPassword", as: String.self, is: .strongPassword)
    }
}

// MARK: - Refresh Token
struct RefreshTokenRequest: Content {
    let refreshToken: String
}

// MARK: - Email Verification
struct EmailVerificationRequest: Content {
    let token: String
}

struct ResendVerificationRequest: Content, Validatable {
    let email: String
    
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
    }
}

// MARK: - Response
struct UserResponse: Content {
    let id: UUID
    let email: String
    let firstName: String
    let lastName: String
    let emailVerified: Bool
    let profilePictureURL: String?
    let lastLogin: Date?
    let createdAt: Date?
    
    init(user: User) {
        self.id = user.id!
        self.email = user.email
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.emailVerified = user.emailVerified
        self.profilePictureURL = user.profilePictureURL
        self.lastLogin = user.lastLogin
        self.createdAt = user.createdAt
    }
}

// MARK: - Authentication Response
struct AuthResponse: Content {
    let user: UserResponse
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval
}

// MARK: - Session Response
struct SessionResponse: Content {
    let sessionID: UUID
    let deviceInfo: String?
    let ipAddress: String?
    let createdAt: Date?
    let lastUsed: Date?
    let isCurrentSession: Bool
}

struct SessionListResponse: Content {
    let sessions: [SessionResponse]
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