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
    if let jwtSecret = Environment.get("JWT_SECRET") {
        await app.jwt.keys.addHMAC(key: jwtSecret, digestAlgorithm: .sha256)
    } else {
        // Development fallback - use a default secret
        await app.jwt.keys.addHMAC(key: "development-secret-key-not-for-production", digestAlgorithm: .sha256)
        app.logger.warning("Using default JWT secret - not suitable for production!")
    }
    
    // Add migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateRefreshToken())
    app.migrations.add(CreateExpense())
    
    // Add middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(RateLimitMiddleware())
    app.middleware.use(AuthMiddleware())
    
    // Register routes
    try routes(app)
}