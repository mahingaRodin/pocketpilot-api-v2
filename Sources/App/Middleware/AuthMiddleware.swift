import Vapor
import JWT
import Fluent

struct JWTAuthenticator: AsyncJWTAuthenticator {
    typealias Payload = UserPayload
    
    func authenticate(jwt: UserPayload, for request: Request) async throws {
        // Only allow access tokens for authentication
        guard jwt.tokenType == .access else {
            throw Abort(.unauthorized, reason: "Invalid token type")
        }
        
        // Find user by ID from JWT payload
        guard let user = try await User.find(jwt.userID, on: request.db) else {
            throw Abort(.unauthorized, reason: "User not found")
        }
        
        // Check if user account is locked
        if user.isAccountLocked() {
            throw Abort(.locked, reason: "Account is temporarily locked")
        }
        
        // Email verification disabled
        // if !user.emailVerified && requiresEmailVerification(request.url.path) {
        //     throw Abort(.forbidden, reason: "Email verification required")
        // }
        
        request.auth.login(user)
//        request.auth.login(jwt) // Also store the JWT payload for session info
    }
    
    private func requiresEmailVerification(_ path: String) -> Bool {
        let sensitiveEndpoints = [
            "/api/v1/user/profile",
            "/api/v1/expenses"
        ]
        return sensitiveEndpoints.contains { path.hasPrefix($0) }
    }
}

struct AuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Skip auth for public routes
        let publicPaths = [
            "/health",
            "/api/v1/auth/register",
            "/api/v1/auth/login",
            "/api/v1/auth/refresh",
            "/api/v1/auth/password/reset",
            "/api/v1/auth/password/reset/confirm",
            "/api/v1/auth/email/verify",
            "/api/v1/auth/email/resend"
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

// MARK: - Rate Limiting Middleware
struct RateLimitMiddleware: AsyncMiddleware {
    private let maxAttempts: Int
    private let timeWindow: TimeInterval
    private let storage: MemoryStorage
    
    init(maxAttempts: Int = 5, timeWindow: TimeInterval = 900) { // 5 attempts per 15 minutes
        self.maxAttempts = maxAttempts
        self.timeWindow = timeWindow
        self.storage = MemoryStorage()
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Only apply rate limiting to auth endpoints
        let rateLimitedPaths = [
            "/api/v1/auth/login",
            "/api/v1/auth/password/reset"
        ]
        
        guard rateLimitedPaths.contains(request.url.path) else {
            return try await next.respond(to: request)
        }
        
        let clientIP = request.remoteAddress?.description ?? "unknown"
        let key = "rate_limit:\(clientIP):\(request.url.path)"
        
        // Get current attempt count
        let currentAttempts = storage.get(Int.self, forKey: key) ?? 0
        
        if currentAttempts >= maxAttempts {
            throw Abort(.tooManyRequests, reason: "Too many attempts. Please try again later.")
        }
        
        // Process request
        let response = try await next.respond(to: request)
        
        // Increment counter on failed attempts (4xx responses)
        if response.status.code >= 400 && response.status.code < 500 {
            storage.set(currentAttempts + 1, forKey: key, expiresIn: timeWindow)
        }
        
        return response
    }
}

// MARK: - Simple Memory Storage for Rate Limiting
private final class MemoryStorage: @unchecked Sendable {
    private var storage: [String: (value: Any, expiry: Date)] = [:]
    private let queue = DispatchQueue(label: "memory-storage", attributes: .concurrent)
    
    func get<T>(_ type: T.Type, forKey key: String) -> T? {
        return queue.sync {
            guard let item = storage[key], item.expiry > Date() else {
                storage.removeValue(forKey: key)
                return nil
            }
            return item.value as? T
        }
    }
    
    func set<T>(_ value: T, forKey key: String, expiresIn seconds: TimeInterval) {
        queue.async(flags: .barrier) {
            self.storage[key] = (value, Date().addingTimeInterval(seconds))
        }
    }
}
