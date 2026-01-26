import Fluent
import Vapor

// MARK: - Achievement Model
final class Achievement: Model, Content, @unchecked Sendable {
    static let schema = "achievements"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "code")
    var code: String // Unique identifier
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "description")
    var description: String
    
    @Field(key: "category")
    var category: AchievementCategory
    
    @Field(key: "icon")
    var icon: String // SF Symbol name
    
    @Field(key: "required_value")
    var requiredValue: Int
    
    @Field(key: "points")
    var points: Int
    
    @Field(key: "tier")
    var tier: AchievementTier
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        code: String,
        name: String,
        description: String,
        category: AchievementCategory,
        icon: String,
        requiredValue: Int,
        points: Int,
        tier: AchievementTier
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.description = description
        self.category = category
        self.icon = icon
        self.requiredValue = requiredValue
        self.points = points
        self.tier = tier
    }
}

enum AchievementCategory: String, Codable {
    case spending = "spending"
    case saving = "saving"
    case tracking = "tracking"
    case budget = "budget"
    case streak = "streak"
    case scanning = "scanning"
}

enum AchievementTier: String, Codable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case platinum = "platinum"
}

// MARK: - User Achievement
final class UserAchievement: Model, Content, @unchecked Sendable {
    static let schema = "user_achievements"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Parent(key: "achievement_id")
    var achievement: Achievement
    
    @Field(key: "progress")
    var progress: Int
    
    @Field(key: "is_unlocked")
    var isUnlocked: Bool
    
    @Timestamp(key: "unlocked_at", on: .none)
    var unlockedAt: Date?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil, userID: User.IDValue, achievementID: Achievement.IDValue, progress: Int = 0, isUnlocked: Bool = false) {
        self.id = id
        self.$user.id = userID
        self.$achievement.id = achievementID
        self.progress = progress
        self.isUnlocked = isUnlocked
    }
}

// MARK: - Streak Tracking
final class UserStreak: Model, Content, @unchecked Sendable {
    static let schema = "user_streaks"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "streak_type")
    var streakType: StreakType
    
    @Field(key: "current_streak")
    var currentStreak: Int
    
    @Field(key: "longest_streak")
    var longestStreak: Int
    
    @Field(key: "last_activity_date")
    var lastActivityDate: Date
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil, userID: User.IDValue, streakType: StreakType) {
        self.id = id
        self.$user.id = userID
        self.streakType = streakType
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastActivityDate = Date()
    }
}

enum StreakType: String, Codable {
    case dailyTracking = "daily_tracking"
    case budgetAdherence = "budget_adherence"
    case scanning = "scanning"
}

// MARK: - Challenge
final class Challenge: Model, Content, @unchecked Sendable {
    static let schema = "challenges"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "code")
    var code: String
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "description")
    var description: String
    
    @Field(key: "challenge_type")
    var challengeType: ChallengeType
    
    @Field(key: "target_value")
    var targetValue: Double
    
    @Field(key: "duration_days")
    var durationDays: Int
    
    @Field(key: "reward_points")
    var rewardPoints: Int
    
    @Field(key: "icon")
    var icon: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        code: String,
        name: String,
        description: String,
        challengeType: ChallengeType,
        targetValue: Double,
        durationDays: Int,
        rewardPoints: Int,
        icon: String
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.description = description
        self.challengeType = challengeType
        self.targetValue = targetValue
        self.durationDays = durationDays
        self.rewardPoints = rewardPoints
        self.icon = icon
    }
}

enum ChallengeType: String, Codable {
    case noSpend = "no_spend"
    case reduceCategory = "reduce_category"
    case saveAmount = "save_amount"
    case trackDaily = "track_daily"
    case scanReceipts = "scan_receipts"
}

// MARK: - User Challenge
final class UserChallenge: Model, Content, @unchecked Sendable {
    static let schema = "user_challenges"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Parent(key: "challenge_id")
    var challenge: Challenge
    
    @Field(key: "progress")
    var progress: Double
    
    @Field(key: "status")
    var status: ChallengeStatus
    
    @Field(key: "start_date")
    var startDate: Date
    
    @OptionalField(key: "end_date")
    var endDate: Date?
    
    @OptionalField(key: "completed_at")
    var completedAt: Date?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        userID: User.IDValue,
        challengeID: Challenge.IDValue,
        progress: Double = 0,
        status: ChallengeStatus = .active,
        startDate: Date = Date(),
        endDate: Date? = nil
    ) {
        self.id = id
        self.$user.id = userID
        self.$challenge.id = challengeID
        self.progress = progress
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
    }
}

enum ChallengeStatus: String, Codable {
    case active = "active"
    case completed = "completed"
    case failed = "failed"
    case abandoned = "abandoned"
}

// MARK: - Leaderboard
final class LeaderboardEntry: Model, Content, @unchecked Sendable {
    static let schema = "leaderboard"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "total_points")
    var totalPoints: Int
    
    @Field(key: "achievements_count")
    var achievementsCount: Int
    
    @Field(key: "challenges_completed")
    var challengesCompleted: Int
    
    @Field(key: "current_rank")
    var currentRank: Int
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        userID: User.IDValue,
        totalPoints: Int = 0,
        achievementsCount: Int = 0,
        challengesCompleted: Int = 0,
        currentRank: Int = 0
    ) {
        self.id = id
        self.$user.id = userID
        self.totalPoints = totalPoints
        self.achievementsCount = achievementsCount
        self.challengesCompleted = challengesCompleted
        self.currentRank = currentRank
    }
}
