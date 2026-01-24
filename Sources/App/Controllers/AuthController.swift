import Vapor
import Fluent
import JWT
import VaporToOpenAPI

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        
        // Public routes
        auth.post("register", use: register)
            .openAPI(
                summary: "Register new user",
                description: "Creates a new user account.",
                body: .type(UserRegistrationRequest.self),
                response: .type(AuthResponse.self)
            )
        
        auth.post("login", use: login)
            .openAPI(
                summary: "Login",
                description: "Authenticates user and returns access token.",
                body: .type(UserLoginRequest.self),
                response: .type(AuthResponse.self)
            )
        
        auth.post("refresh", use: refreshToken)
            .openAPI(
                summary: "Refresh token",
                description: "Refreshes an expired access token using a refresh token.",
                body: .type(RefreshTokenRequest.self),
                response: .type(AuthResponse.self)
            )
            
        auth.post("password", "reset", use: requestPasswordReset)
            .openAPI(
                summary: "Request password reset",
                description: "Sends a password reset email to the user.",
                body: .type(PasswordResetRequest.self)
            )
            
        auth.post("password", "reset", "confirm", use: confirmPasswordReset)
             .openAPI(
                summary: "Confirm password reset",
                description: "Resets the user's password using a token.",
                body: .type(PasswordResetConfirmation.self)
            )

        auth.post("email", "verify", use: verifyEmail)
            .openAPI(
                summary: "Verify email",
                description: "Verifies user email address.",
                body: .type(EmailVerificationRequest.self)
            )
            
        auth.post("email", "resend", use: resendVerificationEmail)
            .openAPI(
                summary: "Resend verification email",
                description: "Resends the email verification link.",
                body: .type(ResendVerificationRequest.self)
            )
        
        // Protected routes
        let protected = auth.grouped(JWTAuthenticator())
        
        protected.get("me", use: getMe)
            .openAPI(
                summary: "Get current user",
                description: "Returns profile information for the authenticated user.",
                response: .type(UserResponse.self),
                auth: .bearer()
            )
            
        protected.post("logout", use: logout)
             .openAPI(
                summary: "Logout",
                description: "Revokes the current session.",
                auth: .bearer()
            )
            
        protected.post("logout", "all", use: logoutAllDevices)
             .openAPI(
                summary: "Logout all devices",
                description: "Revokes all active sessions for the user.",
                auth: .bearer()
            )
            
        protected.post("password", "change", use: changePassword)
             .openAPI(
                summary: "Change password",
                description: "Updates the authenticated user's password.",
                body: .type(ChangePasswordRequest.self),
                auth: .bearer()
            )
            
        protected.get("sessions", use: getSessions)
             .openAPI(
                summary: "Get active sessions",
                description: "Returns a list of all active sessions for the user.",
                response: .type(SessionListResponse.self),
                auth: .bearer()
            )
            
        protected.delete("sessions", ":sessionID", use: revokeSession)
             .openAPI(
                summary: "Revoke session",
                description: "Revokes a specific session by ID.",
                auth: .bearer()
            )
    }
    
    // MARK: - Public Endpoints
    func register(req: Request) async throws -> AuthResponse {
        try UserRegistrationRequest.validate(content: req)
        let userRequest = try req.content.decode(UserRegistrationRequest.self)
        
        return try await req.authService.register(request: userRequest, on: req)
    }
    
    func login(req: Request) async throws -> AuthResponse {
        try UserLoginRequest.validate(content: req)
        let loginRequest = try req.content.decode(UserLoginRequest.self)
        
        return try await req.authService.login(request: loginRequest, on: req)
    }
    
    func getMe(req: Request) async throws -> UserResponse {
        let user = try req.auth.require(User.self)
        return UserResponse(user: user)
    }
    
    func refreshToken(req: Request) async throws -> AuthResponse {
        let refreshRequest = try req.content.decode(RefreshTokenRequest.self)
        
        return try await req.authService.refreshToken(token: refreshRequest.refreshToken, on: req)
    }
    
    func requestPasswordReset(req: Request) async throws -> HTTPStatus {
        try PasswordResetRequest.validate(content: req)
        let resetRequest = try req.content.decode(PasswordResetRequest.self)
        
        return try await req.authService.requestPasswordReset(email: resetRequest.email, on: req)
    }
    
    func confirmPasswordReset(req: Request) async throws -> HTTPStatus {
        try PasswordResetConfirmation.validate(content: req)
        let confirmation = try req.content.decode(PasswordResetConfirmation.self)
        
        guard confirmation.newPassword == confirmation.confirmPassword else {
            throw Abort(.badRequest, reason: "Passwords do not match")
        }
        
        return try await req.authService.resetPassword(
            token: confirmation.token,
            newPassword: confirmation.newPassword,
            on: req
        )
    }
    
    func verifyEmail(req: Request) async throws -> HTTPStatus {
        let verificationRequest = try req.content.decode(EmailVerificationRequest.self)
        
        return try await req.authService.verifyEmail(token: verificationRequest.token, on: req)
    }
    
    func resendVerificationEmail(req: Request) async throws -> HTTPStatus {
        try ResendVerificationRequest.validate(content: req)
        let resendRequest = try req.content.decode(ResendVerificationRequest.self)
        
        return try await req.authService.resendVerificationEmail(email: resendRequest.email, on: req)
    }
    
    // MARK: - Protected Endpoints
    func logout(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let payload = try req.auth.require(UserPayload.self)
        
        return try await req.authService.logout(user: user, sessionID: payload.sessionID, on: req)
    }
    
    func logoutAllDevices(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        return try await req.authService.logoutAllDevices(user: user, on: req)
    }
    
    func changePassword(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        try ChangePasswordRequest.validate(content: req)
        let changeRequest = try req.content.decode(ChangePasswordRequest.self)
        
        guard changeRequest.newPassword == changeRequest.confirmPassword else {
            throw Abort(.badRequest, reason: "Passwords do not match")
        }
        
        return try await req.authService.changePassword(
            user: user,
            currentPassword: changeRequest.currentPassword,
            newPassword: changeRequest.newPassword,
            on: req
        )
    }
    
    func getSessions(req: Request) async throws -> SessionListResponse {
        let user = try req.auth.require(User.self)
        let payload = try req.auth.require(UserPayload.self)
        
        return try await req.authService.getUserSessions(
            user: user,
            currentSessionID: payload.sessionID,
            on: req
        )
    }
    
    func revokeSession(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        guard let sessionIDString = req.parameters.get("sessionID"),
              let sessionID = UUID(uuidString: sessionIDString) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }
        
        return try await req.authService.revokeSession(user: user, sessionID: sessionID, on: req)
    }
}