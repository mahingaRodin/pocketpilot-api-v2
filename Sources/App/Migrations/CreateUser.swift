import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        let builder = database.schema("users")
            .id()
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .field("first_name", .string, .required)
            .field("last_name", .string, .required)
            .field("email_verified", .bool, .required)
            .field("email_verification_token", .string)
            .field("password_reset_token", .string)
            .field("password_reset_expires", .datetime)
            .field("failed_login_attempts", .int, .required)
            .field("locked_until", .datetime)
            .field("last_login", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "email")
        
        // Set default values based on database type
        if database is SQLDatabase {
            // For SQLite, we'll handle defaults in the model
            try await builder.create()
        } else {
            // For PostgreSQL, use database defaults
            try await builder
                .field("email_verified", .bool, .required, .custom("DEFAULT FALSE"))
                .field("failed_login_attempts", .int, .required, .custom("DEFAULT 0"))
                .create()
        }
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}