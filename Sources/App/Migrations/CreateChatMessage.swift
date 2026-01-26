import Fluent

struct CreateChatMessage: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("chat_messages")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("message", .string, .required)
            .field("response", .string, .required)
            .field("intent", .string, .required)
            .field("context_data", .json)
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("chat_messages").delete()
    }
}
