import Fluent

struct CreateRefreshToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        let builder = database.schema("refresh_tokens")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("token", .string, .required)
            .field("session_id", .uuid, .required)
            .field("expires_at", .datetime, .required)
            .field("revoked", .bool, .required)
            .field("device_info", .string)
            .field("ip_address", .string)
            .field("created_at", .datetime)
            .field("last_used", .datetime)
            .unique(on: "token")
        
        // Set default values based on database type
        if database is SQLDatabase {
            // For SQLite, we'll handle defaults in the model
            try await builder.create()
        } else {
            // For PostgreSQL, use database defaults
            try await builder
                .field("revoked", .bool, .required, .custom("DEFAULT FALSE"))
                .create()
        }
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("refresh_tokens").delete()
    }
}