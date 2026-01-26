import Vapor
import Fluent
import FluentSQLiteDriver
import JWT
import VaporToOpenAPI

public func configure(_ app: Application) async throws {

    // Server hostname
    app.http.server.configuration.hostname = "10.12.74.53"

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
    app.migrations.add(CreateBudget())
    app.migrations.add(CreateNotification())
    app.migrations.add(CreateChatMessage())
    app.migrations.add(CreateGamification())

    // Middleware
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(RateLimitMiddleware())

    // OpenAPI Configuration
    // Register OpenAPI JSON route
    app.get("openapi.json") { req -> OpenAPIObject in
        // Define API Info
        let info = InfoObject(
            title: "PocketPilot API",
            description: "API for PocketPilot Smart Finance App",
            version: "2.0.0"
        )
        // Generate OpenAPI document from registered routes
        return app.routes.openAPI(info: info)
    }

    // Register Swagger UI route
    app.get("swagger") { req -> Response in
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>PocketPilot API Documentation</title>
          <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@4.15.5/swagger-ui.css" />
        </head>
        <body>
        <div id="swagger-ui"></div>
        <script src="https://unpkg.com/swagger-ui-dist@4.15.5/swagger-ui-bundle.js" crossorigin></script>
        <script>
          window.onload = () => {
            window.ui = SwaggerUIBundle({
              url: '/openapi.json',
              dom_id: '#swagger-ui',
              deepLinking: true,
              presets: [
                SwaggerUIBundle.presets.apis,
                SwaggerUIBundle.SwaggerUIStandalonePreset
              ],
              layout: "BaseLayout"
            });
          };
        </script>
        </body>
        </html>
        """
        
        var headers = HTTPHeaders()
        headers.contentType = .html
        return Response(status: .ok, headers: headers, body: .init(string: html))
    }

    // Routes
    try routes(app)
    
    // Routes
    try routes(app)
}
