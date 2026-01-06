import Vapor
import JWT

struct JWTService {
    let application: Application
    
    init(_ application: Application) {
        self.application = application
    }
    
    func sign<Payload: JWTPayload>(_ payload: Payload) async throws -> String {
        return try await application.jwt.sign(payload)
    }
    
    func verify<Payload: JWTPayload>(_ token: String, as payload: Payload.Type) async throws -> Payload {
        return try await application.jwt.verify(token, as: payload)
    }
    
    func generateUserToken(for user: User, expirationTime: TimeInterval = 86400 * 7) throws -> String {
        let payload = UserPayload(
            userID: user.id!,
            email: user.email,
            exp: .init(value: Date().addingTimeInterval(expirationTime))
        )
        
        return try application.jwt.sign(payload)
    }
}

extension Application {
    var jwtService: JWTService {
        .init(self)
    }
}

extension Request {
    var jwtService: JWTService {
        application.jwtService
    }
}