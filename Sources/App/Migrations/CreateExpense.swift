import Fluent
import FluentSQLiteDriver

struct CreateExpense: AsyncMigration {
    func prepare(on database: Database) async throws {
        // Create enum for PostgreSQL, skip for SQLite
        var categoryEnum: DatabaseSchema.DataType = .string
        
        if !(database is SQLiteDatabase) {
            let enumBuilder = try await database.enum("expense_category")
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
            categoryEnum = enumBuilder
        }
        
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
        
        // Only delete enum if it's PostgreSQL
        if !(database is SQLiteDatabase) {
            try await database.enum("expense_category").delete()
        }
    }
}