import Vapor
import Fluent
import JWT

struct AuthenticationService {
    let app: Application
    
    init(_ app: Application) {
        self.app = app
    }
    
    // MARK: - Core Authentication
    func register(request: UserRegistrationRequest, on req: Request) async throws -> AuthResponse {
        // Validate passwords match
        guard request.password == request.confirmPassword else {
            throw Abort(.badRequest, reason: "Passwords do not match")
        }
        
        // Check if user already exists
        let existingUser = try await User.query(on: req.db)
            .filter(\.$email == request.email)
            .first()
        
        if existingUser != nil {
            throw Abort(.conflict, reason: "User with this email already exists")
        }
        
        // Hash password
        let hashedPassword = try Bcrypt.hash(request.password)
        
        // Create user (email verification disabled)
        let user = User(
            email: request.email,
            passwordHash: hashedPassword,
            firstName: request.firstName,
            lastName: request.lastName,
            emailVerified: true  // Email verification disabled
        )
        
        try await user.save(on: req.db)
        
        // Generate tokens
        let sessionID = UUID()
        let (accessToken, refreshToken) = try await generateTokenPair(
            for: user,
            sessionID: sessionID,
            deviceInfo: nil,
            ipAddress: req.remoteAddress?.description,
            on: req
        )
        
        return AuthResponse(
            user: UserResponse(user: user),
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: 86400 // 24 hours
        )
    }
    
    func login(request: UserLoginRequest, on req: Request) async throws -> AuthResponse {
        // Find user by email
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == request.email)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        // Check if account is locked
        if user.isAccountLocked() {
            throw Abort(.locked, reason: "Account is temporarily locked due to too many failed login attempts")
        }
        
        // Verify password
        guard try user.verify(password: request.password) else {
            user.recordFailedLogin()
            try await user.save(on: req.db)
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        // Record successful login
        user.recordSuccessfulLogin()
        try await user.save(on: req.db)
        
        // Generate tokens
        let sessionID = UUID()
        let (accessToken, refreshToken) = try await generateTokenPair(
            for: user,
            sessionID: sessionID,
            deviceInfo: request.deviceInfo,
            ipAddress: req.remoteAddress?.description,
            on: req
        )
        
        return AuthResponse(
            user: UserResponse(user: user),
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: 86400 // 24 hours
        )
    }
    
    func refreshToken(token: String, on req: Request) async throws -> AuthResponse {
        // Find refresh token
        guard let refreshToken = try await RefreshToken.query(on: req.db)
            .filter(\.$token == token)
            .with(\.$user)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid refresh token")
        }
        
        // Validate token
        guard refreshToken.isValid() else {
            throw Abort(.unauthorized, reason: "Refresh token expired or revoked")
        }
        
        // Update last used
        refreshToken.updateLastUsed()
        try await refreshToken.save(on: req.db)
        
        // Generate new access token
        let accessToken = try await generateAccessToken(
            for: refreshToken.user,
            sessionID: refreshToken.sessionID
        )
        
        return AuthResponse(
            user: UserResponse(user: refreshToken.user),
            accessToken: accessToken,
            refreshToken: token, // Keep same refresh token
            expiresIn: 86400 // 24 hours
        )
    }
    
    func logout(user: User, sessionID: UUID?, on req: Request) async throws -> HTTPStatus {
        if let sessionID = sessionID {
            // Revoke specific session
            try await RefreshToken.query(on: req.db)
                .filter(\.$user.$id == user.id!)
                .filter(\.$sessionID == sessionID)
                .set(\.$revoked, to: true)
                .update()
        } else {
            // Revoke current session (fallback)
            if let token = try await RefreshToken.query(on: req.db)
                .filter(\.$user.$id == user.id!)
                .filter(\.$revoked == false)
                .sort("last_used", .descending)
                .first() {
                token.revoke()
                try await token.save(on: req.db)
            }
        }
        
        return .noContent
    }
    
    func logoutAllDevices(user: User, on req: Request) async throws -> HTTPStatus {
        // Revoke all refresh tokens for user
        try await RefreshToken.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .set(\.$revoked, to: true)
            .update()
        
        return .noContent
    }
    
    // MARK: - Password Management
    func requestPasswordReset(email: String, on req: Request) async throws -> HTTPStatus {
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == email)
            .first() else {
            // Don't reveal if email exists
            return .ok
        }
        
        let resetToken = user.generatePasswordResetToken()
        try await user.save(on: req.db)
        
        // Send password reset email
        try await sendPasswordResetEmail(to: email, token: resetToken, on: req)
        
        return .ok
    }
    
    func resetPassword(token: String, newPassword: String, on req: Request) async throws -> HTTPStatus {
        guard let user = try await User.query(on: req.db)
            .filter(\.$passwordResetToken == token)
            .first() else {
            throw Abort(.badRequest, reason: "Invalid or expired reset token")
        }
        
        guard user.isPasswordResetTokenValid(token) else {
            throw Abort(.badRequest, reason: "Invalid or expired reset token")
        }
        
        // Update password
        user.passwordHash = try Bcrypt.hash(newPassword)
        user.clearPasswordResetToken()
        
        // Revoke all existing sessions for security
        try await RefreshToken.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .set(\.$revoked, to: true)
            .update()
        
        try await user.save(on: req.db)
        
        // Send notification email
        try await sendPasswordChangedNotification(to: user.email, on: req)
        
        return .ok
    }
    
    func changePassword(
        user: User,
        currentPassword: String,
        newPassword: String,
        on req: Request
    ) async throws -> HTTPStatus {
        // Verify current password
        guard try user.verify(password: currentPassword) else {
            throw Abort(.unauthorized, reason: "Current password is incorrect")
        }
        
        // Update password
        user.passwordHash = try Bcrypt.hash(newPassword)
        try await user.save(on: req.db)
        
        // Revoke all other sessions for security (keep current session)
        let currentSessionID = try req.auth.require(UserPayload.self).sessionID
        try await RefreshToken.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$sessionID != currentSessionID)
            .set(\.$revoked, to: true)
            .update()
        
        // Send notification email
        try await sendPasswordChangedNotification(to: user.email, on: req)
        
        return .ok
    }
    
    // MARK: - Email Verification
    func verifyEmail(token: String, on req: Request) async throws -> HTTPStatus {
        guard let user = try await User.query(on: req.db)
            .filter(\.$emailVerificationToken == token)
            .first() else {
            throw Abort(.badRequest, reason: "Invalid verification token")
        }
        
        user.emailVerified = true
        user.emailVerificationToken = nil
        try await user.save(on: req.db)
        
        return .ok
    }
    
    func resendVerificationEmail(email: String, on req: Request) async throws -> HTTPStatus {
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == email)
            .first() else {
            // Don't reveal if email exists
            return .ok
        }
        
        guard !user.emailVerified else {
            throw Abort(.badRequest, reason: "Email is already verified")
        }
        
        let verificationToken = user.generateEmailVerificationToken()
        try await user.save(on: req.db)
        
        try await sendVerificationEmail(to: email, token: verificationToken, on: req)
        
        return .ok
    }
    
    // MARK: - Session Management
    func getUserSessions(user: User, currentSessionID: UUID, on req: Request) async throws -> SessionListResponse {
        let refreshTokens = try await RefreshToken.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$revoked == false)
            .filter(\.$expiresAt > Date())
            .all()
        
        let sessions = refreshTokens.map { token in
            SessionResponse(
                sessionID: token.sessionID,
                deviceInfo: token.deviceInfo,
                ipAddress: token.ipAddress,
                createdAt: token.createdAt,
                lastUsed: token.lastUsed,
                isCurrentSession: token.sessionID == currentSessionID
            )
        }
        
        return SessionListResponse(sessions: sessions)
    }
    
    func revokeSession(user: User, sessionID: UUID, on req: Request) async throws -> HTTPStatus {
        try await RefreshToken.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$sessionID == sessionID)
            .set(\.$revoked, to: true)
            .update()
        
        return .noContent
    }
}

// MARK: - Private Helper Methods
extension AuthenticationService {
    private func generateTokenPair(
        for user: User,
        sessionID: UUID,
        deviceInfo: String?,
        ipAddress: String?,
        on req: Request
    ) async throws -> (accessToken: String, refreshToken: String) {
        let accessToken = try await generateAccessToken(for: user, sessionID: sessionID)
        
        // Create refresh token
        let refreshTokenString = RefreshToken.generateToken()
        let refreshToken = RefreshToken(
            userID: user.id!,
            token: refreshTokenString,
            sessionID: sessionID,
            expiresAt: Date().addingTimeInterval(86400 * 30), // 30 days
            deviceInfo: deviceInfo,
            ipAddress: ipAddress
        )
        
        try await refreshToken.save(on: req.db)
        
        return (accessToken, refreshTokenString)
    }
    
    private func generateAccessToken(for user: User, sessionID: UUID) async throws -> String {
        let payload = UserPayload(
            userID: user.id!,
            email: user.email,
            tokenType: .access,
            sessionID: sessionID,
            exp: .init(value: Date().addingTimeInterval(86400)) // 24 hours
        )
        
        return try app.jwt.signers.sign(payload, kid: nil)
    }
    
    // MARK: - Email Methods
    private func sendVerificationEmail(to email: String, token: String, on req: Request) async throws {
        let baseURL = Environment.get("BASE_URL") ?? "http://localhost:8080"
        try await req.emailService.sendVerificationEmail(to: email, token: token, baseURL: baseURL)
    }
    
    private func sendPasswordResetEmail(to email: String, token: String, on req: Request) async throws {
        let baseURL = Environment.get("BASE_URL") ?? "http://localhost:8080"
        try await req.emailService.sendPasswordResetEmail(to: email, token: token, baseURL: baseURL)
    }
    
    private func sendPasswordChangedNotification(to email: String, on req: Request) async throws {
        try await req.emailService.sendPasswordChangedNotification(to: email)
    }
}

// MARK: - Application Extension
extension Application {
    var authService: AuthenticationService {
        .init(self)
    }
}

extension Request {
    var authService: AuthenticationService {
        application.authService
    }
}
