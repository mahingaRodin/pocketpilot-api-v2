import Vapor
import Fluent
import FluentSQLiteDriver
import JWT

public func configure(_ app: Application) throws {

    // Server hostname
    app.http.server.configuration.hostname = "10.12.73.61"

    // Database
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    app.logger.info("Using SQLite database")
    
    // Increase max body size to 20MB to handle receipt images
    app.routes.defaultMaxBodySize = "20mb"

    // JWT
    let jwtSecret = Environment.get("JWT_SECRET")
        ?? "development-secret-key-not-for-production"

    if Environment.get("JWT_SECRET") == nil {
        app.logger.warning("Using default JWT secret - not suitable for production!")
    }

    app.jwt.signers.use(.hs256(key: jwtSecret))

    // JSON config
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    ContentConfiguration.global.use(encoder: encoder, for: .json)
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    // Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateRefreshToken())
    app.migrations.add(CreateExpense())
    app.migrations.add(AddReceiptURLToExpenses())
    app.migrations.add(AddProfilePictureToUsers())

    // Middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(RateLimitMiddleware())

    // Routes
    try routes(app)
}
