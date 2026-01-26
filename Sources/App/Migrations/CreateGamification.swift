import Fluent

struct CreateGamification: AsyncMigration {
    func prepare(on database: Database) async throws {
        // Achievements table
        try await database.schema("achievements")
            .id()
            .field("code", .string, .required)
            .field("name", .string, .required)
            .field("description", .string, .required)
            .field("category", .string, .required)
            .field("icon", .string, .required)
            .field("required_value", .int, .required)
            .field("points", .int, .required)
            .field("tier", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "code")
            .create()
        
        // User Achievements table
        try await database.schema("user_achievements")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("achievement_id", .uuid, .required, .references("achievements", "id", onDelete: .cascade))
            .field("progress", .int, .required)
            .field("is_unlocked", .bool, .required)
            .field("unlocked_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id", "achievement_id")
            .create()
        
        // Streaks table
        try await database.schema("user_streaks")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("streak_type", .string, .required)
            .field("current_streak", .int, .required)
            .field("longest_streak", .int, .required)
            .field("last_activity_date", .datetime, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id", "streak_type")
            .create()
        
        // Challenges table
        try await database.schema("challenges")
            .id()
            .field("code", .string, .required)
            .field("name", .string, .required)
            .field("description", .string, .required)
            .field("challenge_type", .string, .required)
            .field("target_value", .double, .required)
            .field("duration_days", .int, .required)
            .field("reward_points", .int, .required)
            .field("icon", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "code")
            .create()
        
        // User Challenges table
        try await database.schema("user_challenges")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("challenge_id", .uuid, .required, .references("challenges", "id", onDelete: .cascade))
            .field("progress", .double, .required)
            .field("status", .string, .required)
            .field("start_date", .datetime, .required)
            .field("end_date", .datetime)
            .field("completed_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
        
        // Leaderboard table
        try await database.schema("leaderboard")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("total_points", .int, .required)
            .field("achievements_count", .int, .required)
            .field("challenges_completed", .int, .required)
            .field("current_rank", .int, .required)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()
            
        // Seed initial achievements
        try await GamificationService.seedDefaultAchievements(on: database)
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("leaderboard").delete()
        try await database.schema("user_challenges").delete()
        try await database.schema("challenges").delete()
        try await database.schema("user_streaks").delete()
        try await database.schema("user_achievements").delete()
        try await database.schema("achievements").delete()
    }
}
