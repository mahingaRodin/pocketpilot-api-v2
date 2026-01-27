import Fluent

struct CreateSquad: AsyncMigration {
    func prepare(on database: Database) async throws {
        // Create squads table
        try await database.schema("squads")
            .id()
            .field("name", .string, .required)
            .field("invite_code", .string, .required)
            .field("description", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "invite_code")
            .create()
            
        // Create squad_members table
        try await database.schema("squad_members")
            .id()
            .field("squad_id", .uuid, .required, .references("squads", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("role", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "squad_id", "user_id")
            .create()
            
        // Create squad_invitations table
        try await database.schema("squad_invitations")
            .id()
            .field("squad_id", .uuid, .required, .references("squads", "id", onDelete: .cascade))
            .field("email", .string, .required)
            .field("token", .string, .required)
            .field("status", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "token")
            .create()
            
        // Update expenses table to include squad_id
        try await database.schema("expenses")
            .field("squad_id", .uuid, .references("squads", "id", onDelete: .setNull))
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("expenses")
            .deleteField("squad_id")
            .update()
            
        try await database.schema("squad_invitations").delete()
        try await database.schema("squad_members").delete()
        try await database.schema("squads").delete()
    }
}
