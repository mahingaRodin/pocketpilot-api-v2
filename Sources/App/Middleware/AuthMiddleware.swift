import Vapor
import JWT
import Fluent

struct JWTAuthenticator: AsyncJWTAuthenticator {
    typealias Payload = UserPayload
    
    func authenticate(jwt: UserPayload, for request: Request) async throws {
        // Find user by ID from JWT payload
        guard let user = try await User.find(jwt.userID, on: request.db) else {
            throw Abort(.unauthorized, reason: "User not found")
        }
        
        request.auth.login(user)
    }
}

struct AuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Skip auth for public routes
        let publicPaths = [
            "/health",
            "/api/v1/auth/register",
            "/api/v1/auth/login"
        ]
        
        if publicPaths.contains(request.url.path) {
            return try await next.respond(to: request)
        }
        
        // For protected routes, ensure user is authenticated
        if request.url.path.hasPrefix("/api/v1/") && !publicPaths.contains(request.url.path) {
            guard request.auth.has(User.self) else {
                throw Abort(.unauthorized, reason: "Authentication required")
            }
        }
        
        return try await next.respond(to: request)
    }
}