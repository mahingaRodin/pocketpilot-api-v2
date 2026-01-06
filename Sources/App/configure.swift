import Vapor
import Fluent
import FluentPostgresDriver
import JWT

// Configures your application
public func configure(_ app: Application) async throws {
    // Configure database
    app.databases.use(
        .postgres(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? 5432,
            username: Environment.get("DATABASE_USERNAME") ?? "postgres",
            password: Environment.get("DATABASE_PASSWORD") ?? "",
            database: Environment.get("DATABASE_NAME") ?? "pocketpilot"
        ),
        as: .psql
    )
    
    // Configure JWT
    if let jwtSecret = Environment.get("JWT_SECRET") {
        await app.jwt.keys.addHMAC(key: jwtSecret, digestAlgorithm: .sha256)
    } else {
        // Development fallback - use a default secret
        await app.jwt.keys.addHMAC(key: "secret-key", digestAlgorithm: .sha256)
        app.logger.warning("Using default JWT secret - not suitable for production!")
    }
    
    // Add migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateExpense())
    
    // Add middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(AuthMiddleware())
    
    // Register routes
    try routes(app)
}