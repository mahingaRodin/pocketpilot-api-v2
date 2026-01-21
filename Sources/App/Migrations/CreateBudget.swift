import Fluent

struct CreateBudget: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("budgets")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("category", .string, .required)
            .field("amount", .double, .required)
            .field("period", .string, .required)
            .field("start_date", .datetime, .required)
            .field("end_date", .datetime)
            .field("alert_threshold", .double, .required)
            .field("is_active", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
        
        try await database.schema("budget_alerts")
            .id()
            .field("budget_id", .uuid, .required, .references("budgets", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("alert_type", .string, .required)
            .field("threshold_percentage", .double, .required)
            .field("triggered_at", .datetime, .required)
            .field("is_read", .bool, .required)
            .field("message", .string)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("budget_alerts").delete()
        try await database.schema("budgets").delete()
    }
}
