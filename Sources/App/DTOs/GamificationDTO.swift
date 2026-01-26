import Vapor

struct AchievementResponse: Content {
    let id: UUID
    let code: String
    let name: String
    let description: String
    let category: String
    let icon: String
    let requiredValue: Int
    let progress: Int
    let isUnlocked: Bool
    let unlockedAt: Date?
    let points: Int
    let tier: String
    
    init(achievement: Achievement, userAchievement: UserAchievement?) {
        self.id = achievement.id!
        self.code = achievement.code
        self.name = achievement.name
        self.description = achievement.description
        self.category = achievement.category.rawValue
        self.icon = achievement.icon
        self.requiredValue = achievement.requiredValue
        self.progress = userAchievement?.progress ?? 0
        self.isUnlocked = userAchievement?.isUnlocked ?? false
        self.unlockedAt = userAchievement?.unlockedAt
        self.points = achievement.points
        self.tier = achievement.tier.rawValue
    }
}

struct GamificationProfileResponse: Content {
    let totalPoints: Int
    let achievementsCount: Int
    let challengesCompleted: Int
    let currentRank: Int
    let currentStreak: Int
    let longestStreak: Int
}

struct LeaderboardResponse: Content {
    let entries: [LeaderboardEntryListItem]
}

struct LeaderboardEntryListItem: Content {
    let userID: UUID
    let firstName: String
    let lastName: String
    let points: Int
    let rank: Int
}
