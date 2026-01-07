import Vapor
import Fluent

final class RefreshToken: Model, Content, @unchecked Sendable {
    static let schema = "refresh_tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "token")
    var token: String
    
    @Field(key: "session_id")
    var sessionID: UUID
    
    @Field(key: "expires_at")
    var expiresAt: Date
    
    @Field(key: "revoked")
    var revoked: Bool
    
    @OptionalField(key: "device_info")
    var deviceInfo: String?
    
    @OptionalField(key: "ip_address")
    var ipAddress: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "last_used")
    var lastUsed: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        userID: UUID,
        token: String,
        sessionID: UUID,
        expiresAt: Date,
        deviceInfo: String? = nil,
        ipAddress: String? = nil
    ) {
        self.id = id
        self.$user.id = userID
        self.token = token
        self.sessionID = sessionID
        self.expiresAt = expiresAt
        self.revoked = false
        self.deviceInfo = deviceInfo
        self.ipAddress = ipAddress
    }
}

// MARK: - Token Management
extension RefreshToken {
    func isValid() -> Bool {
        return !revoked && Date() < expiresAt
    }
    
    func revoke() {
        self.revoked = true
    }
    
    func updateLastUsed() {
        self.lastUsed = Date()
    }
    
    static func generateToken() -> String {
        return UUID().uuidString + "-" + UUID().uuidString
    }
}