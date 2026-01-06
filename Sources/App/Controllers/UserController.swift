import Vapor
import Fluent

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("user")
        let protected = users.grouped(JWTAuthenticator())
        
        protected.get("profile", use: getProfile)
        protected.put("profile", use: updateProfile)
    }
    
    func getProfile(req: Request) async throws -> UserResponse {
        let user = try req.auth.require(User.self)
        return UserResponse(user: user)
    }
    
    func updateProfile(req: Request) async throws -> UserResponse {
        let user = try req.auth.require(User.self)
        
        try UserUpdateRequest.validate(content: req)
        let updateRequest = try req.content.decode(UserUpdateRequest.self)
        
        // Update fields if provided
        if let firstName = updateRequest.firstName {
            user.firstName = firstName
        }
        
        if let lastName = updateRequest.lastName {
            user.lastName = lastName
        }
        
        try await user.save(on: req.db)
        
        return UserResponse(user: user)
    }
}