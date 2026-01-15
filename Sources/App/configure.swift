import Vapor
import Fluent
import FluentSQLiteDriver
import JWT

// Configures your application
public func configure(_ app: Application) async throws {
    // Always use SQLite for Windows development to avoid SSL/networking issues
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    app.logger.info("Using SQLite database for Windows development")
    
    // Configure JWT
    let jwtSecret = Environment.get("JWT_SECRET") ?? "development-secret-key-not-for-production"
    if Environment.get("JWT_SECRET") == nil {
        app.logger.warning("Using default JWT secret - not suitable for production!")
    }
    app.jwt.signers.use(.hs256(key: jwtSecret))
    
    // Configure JSON encoder/decoder for ISO 8601 dates
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    
    ContentConfiguration.global.use(encoder: encoder, for: .json)
    ContentConfiguration.global.use(decoder: decoder, for: .json)
    
    // Add migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateRefreshToken())
    app.migrations.add(CreateExpense())
    
    // Add middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(RateLimitMiddleware())
    
    // Register routes
    try routes(app)
}