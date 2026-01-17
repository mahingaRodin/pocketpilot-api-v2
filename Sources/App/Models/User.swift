import Vapor
import Fluent
import JWT

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "password_hash")
    var passwordHash: String
    
    @Field(key: "first_name")
    var firstName: String
    
    @Field(key: "last_name")
    var lastName: String
    
    @Field(key: "email_verified")
    var emailVerified: Bool
    
    @OptionalField(key: "email_verification_token")
    var emailVerificationToken: String?
    
    @OptionalField(key: "password_reset_token")
    var passwordResetToken: String?
    
    @OptionalField(key: "password_reset_expires")
    var passwordResetExpires: Date?
    
    @Field(key: "failed_login_attempts")
    var failedLoginAttempts: Int
    
    @OptionalField(key: "locked_until")
    var lockedUntil: Date?
    
    @OptionalField(key: "last_login")
    var lastLogin: Date?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @OptionalField(key: "profile_picture_url")
    var profilePictureURL: String?
    
    @Children(for: \.$user)
    var expenses: [Expense]
    
    @Children(for: \.$user)
    var refreshTokens: [RefreshToken]
    
    init() { }
    
    init(
        id: UUID? = nil,
        email: String,
        passwordHash: String,
        firstName: String,
        lastName: String,
        emailVerified: Bool = false
    ) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.firstName = firstName
        self.lastName = lastName
        self.emailVerified = emailVerified
        self.failedLoginAttempts = 0
    }
}

// MARK: - Authentication
extension User: ModelAuthenticatable {
    static var usernameKey: KeyPath<User, FieldProperty<User, String>> {
        \User.$email
    }
    static var passwordHashKey: KeyPath<User, FieldProperty<User, String>> {
        \User.$passwordHash
    }
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

// MARK: - Security Methods
extension User {
    func isAccountLocked() -> Bool {
        guard let lockedUntil = lockedUntil else { return false }
        return Date() < lockedUntil
    }
    
    func shouldLockAccount() -> Bool {
        return failedLoginAttempts >= 5 // Lock after 5 failed attempts
    }
    
    func lockAccount(for duration: TimeInterval = 900) { // 15 minutes default
        self.lockedUntil = Date().addingTimeInterval(duration)
    }
    
    func unlockAccount() {
        self.failedLoginAttempts = 0
        self.lockedUntil = nil
    }
    
    func recordFailedLogin() {
        self.failedLoginAttempts += 1
        if shouldLockAccount() {
            lockAccount()
        }
    }
    
    func recordSuccessfulLogin() {
        self.failedLoginAttempts = 0
        self.lockedUntil = nil
        self.lastLogin = Date()
    }
    
    func generateEmailVerificationToken() -> String {
        let token = UUID().uuidString
        self.emailVerificationToken = token
        return token
    }
    
    func generatePasswordResetToken() -> String {
        let token = UUID().uuidString
        self.passwordResetToken = token
        self.passwordResetExpires = Date().addingTimeInterval(3600) // 1 hour
        return token
    }
    
    func isPasswordResetTokenValid(_ token: String) -> Bool {
        guard let storedToken = passwordResetToken,
              let expires = passwordResetExpires else {
            return false
        }
        return storedToken == token && Date() < expires
    }
    
    func clearPasswordResetToken() {
        self.passwordResetToken = nil
        self.passwordResetExpires = nil
    }
}

// MARK: - JWT Payload
struct UserPayload: JWTPayload , Authenticatable{
    var userID: UUID
    var email: String
    var tokenType: TokenType
    var sessionID: UUID
    var exp: ExpirationClaim
    
    enum TokenType: String, Codable {
        case access = "access"
        case refresh = "refresh"
    }
    
    func verify(using signer: JWTSigner) throws {
        try self.exp.verifyNotExpired()
    }
}
