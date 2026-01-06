import Fluent

struct CreateExpense: AsyncMigration {
    func prepare(on database: Database) async throws {
        let categoryEnum = try await database.enum("expense_category")
            .case("food")
            .case("transportation")
            .case("entertainment")
            .case("shopping")
            .case("bills")
            .case("healthcare")
            .case("education")
            .case("travel")
            .case("groceries")
            .case("utilities")
            .case("rent")
            .case("insurance")
            .case("other")
            .create()
        
        try await database.schema("expenses")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("amount", .double, .required)
            .field("description", .string, .required)
            .field("category", categoryEnum, .required)
            .field("date", .date, .required)
            .field("notes", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("expenses").delete()
        try await database.enum("expense_category").delete()
    }
}