import Fluent

struct CreateNotification: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("notifications")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("type", .string, .required)
            .field("title", .string, .required)
            .field("message", .string, .required)
            .field("data", .json)
            .field("priority", .string, .required)
            .field("is_read", .bool, .required)
            .field("read_at", .datetime)
            .field("action_url", .string)
            .field("category", .string, .required)
            .field("created_at", .datetime)
            .field("scheduled_for", .datetime)
            .create()
        
        try await database.schema("user_notification_preferences")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("budget_alerts_enabled", .bool, .required)
            .field("daily_summary_enabled", .bool, .required)
            .field("weekly_summary_enabled", .bool, .required)
            .field("unusual_spending_enabled", .bool, .required)
            .field("bill_reminders_enabled", .bool, .required)
            .field("quiet_hours_start", .int)
            .field("quiet_hours_end", .int)
            .field("push_enabled", .bool, .required)
            .field("email_enabled", .bool, .required)
            .field("push_token", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("user_notification_preferences").delete()
        try await database.schema("notifications").delete()
    }
}
