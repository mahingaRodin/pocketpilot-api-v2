import Vapor
import JWT

struct JWTService {
    let application: Application
    
    init(_ application: Application) {
        self.application = application
    }
    
    func sign<Payload: JWTPayload>(_ payload: Payload) async throws -> String {
        return try await application.jwt.signers.sign(payload, kid: nil)
    }
    
    func verify<Payload: JWTPayload>(_ token: String, as payload: Payload.Type) async throws -> Payload {
        return try await application.jwt.signers.verify(token, as: payload)
    }
    
    func generateUserToken(for user: User, expirationTime: TimeInterval = 86400 * 7) async throws -> String {
        let payload = UserPayload(
            userID: user.id!,
            email: user.email,
            tokenType: .access,
            sessionID: UUID(),
            exp: .init(value: Date().addingTimeInterval(expirationTime))
        )
        
        return try await application.jwt.signers.sign(payload, kid: nil)
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