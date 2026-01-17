import Fluent

struct AddProfilePictureToUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("profile_picture_url", .string)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("profile_picture_url")
            .update()
    }
}
