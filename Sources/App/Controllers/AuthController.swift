import Vapor
import Fluent
import JWT

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
    }
    
    func register(req: Request) async throws -> AuthResponse {
        try UserRegistrationRequest.validate(content: req)
        let userRequest = try req.content.decode(UserRegistrationRequest.self)
        
        // Check if passwords match
        guard userRequest.password == userRequest.confirmPassword else {
            throw Abort(.badRequest, reason: "Passwords do not match")
        }
        
        // Check if user already exists
        let existingUser = try await User.query(on: req.db)
            .filter(\.$email == userRequest.email)
            .first()
        
        if existingUser != nil {
            throw Abort(.conflict, reason: "User with this email already exists")
        }
        
        // Hash password
        let hashedPassword = try Bcrypt.hash(userRequest.password)
        
        // Create user
        let user = User(
            email: userRequest.email,
            passwordHash: hashedPassword,
            firstName: userRequest.firstName,
            lastName: userRequest.lastName
        )
        
        try await user.save(on: req.db)
        
        // Generate JWT token
        let token = try await generateToken(for: user, on: req)
        
        return AuthResponse(
            user: UserResponse(user: user),
            token: token
        )
    }
    
    func login(req: Request) async throws -> AuthResponse {
        try UserLoginRequest.validate(content: req)
        let loginRequest = try req.content.decode(UserLoginRequest.self)
        
        // Find user by email
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == loginRequest.email)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        // Verify password
        guard try user.verify(password: loginRequest.password) else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        // Generate JWT token
        let token = try await generateToken(for: user, on: req)
        
        return AuthResponse(
            user: UserResponse(user: user),
            token: token
        )
    }
    
    private func generateToken(for user: User, on req: Request) async throws -> String {
        let payload = UserPayload(
            userID: user.id!,
            email: user.email,
            exp: .init(value: Date().addingTimeInterval(86400 * 7)) // 7 days
        )
        
        return try await req.jwt.sign(payload)
    }
}