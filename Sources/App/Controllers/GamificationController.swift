import Vapor
import Fluent

struct GamificationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let gamification = routes.grouped("gamification")
            .grouped(JWTAuthenticator())
        
        gamification.get("achievements", use: getAchievements)
            .openAPI(
                summary: "Get achievements",
                description: "Retrieves all available achievements and user progress.",
                response: .type([AchievementResponse].self),
                auth: .bearer()
            )
            
        gamification.get("profile", use: getProfile)
            .openAPI(
                summary: "Get gamification profile",
                description: "Retrieves user's points, rank, and streaks.",
                response: .type(GamificationProfileResponse.self),
                auth: .bearer()
            )
            
        gamification.get("leaderboard", use: getLeaderboard)
            .openAPI(
                summary: "Get leaderboard",
                description: "Retrieves top users by points.",
                response: .type(LeaderboardResponse.self),
                auth: .bearer()
            )
            
        gamification.post("achievements", "check", use: checkAchievements)
            .openAPI(
                summary: "Check achievements",
                description: "Manually triggers an evaluation of achievements.",
                response: .type(HTTPStatus.self),
                auth: .bearer()
            )
    }
    
    // MARK: - Get Achievements
    func getAchievements(req: Request) async throws -> [AchievementResponse] {
        let user = try req.auth.require(User.self)
        let userID = user.id!
        
        let achievements = try await Achievement.query(on: req.db).all()
        let userAchievements = try await UserAchievement.query(on: req.db)
            .filter(\.$user.$id == userID)
            .all()
            
        return achievements.map { achievement in
            let userAch = userAchievements.first(where: { $0.$achievement.id == achievement.id })
            return AchievementResponse(achievement: achievement, userAchievement: userAch)
        }
    }
    
    // MARK: - Get Profile
    func getProfile(req: Request) async throws -> GamificationProfileResponse {
        let user = try req.auth.require(User.self)
        let userID = user.id!
        
        let leaderboardEntry = try await LeaderboardEntry.query(on: req.db)
            .filter(\.$user.$id == userID)
            .first()
            
        let streak = try await UserStreak.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$streakType == .dailyTracking)
            .first()
            
        return GamificationProfileResponse(
            totalPoints: leaderboardEntry?.totalPoints ?? 0,
            achievementsCount: leaderboardEntry?.achievementsCount ?? 0,
            challengesCompleted: leaderboardEntry?.challengesCompleted ?? 0,
            currentRank: leaderboardEntry?.currentRank ?? 0,
            currentStreak: streak?.currentStreak ?? 0,
            longestStreak: streak?.longestStreak ?? 0
        )
    }
    
    // MARK: - Get Leaderboard
    func getLeaderboard(req: Request) async throws -> LeaderboardResponse {
        let entries = try await LeaderboardEntry.query(on: req.db)
            .with(\.$user)
            .sort(\.$currentRank, .ascending)
            .limit(10)
            .all()
            
        let listItems = entries.map { entry in
            LeaderboardEntryListItem(
                userID: entry.$user.id,
                firstName: entry.user.firstName,
                lastName: entry.user.lastName,
                points: entry.totalPoints,
                rank: entry.currentRank
            )
        }
        
        return LeaderboardResponse(entries: listItems)
    }
    
    // MARK: - Trigger Check
    func checkAchievements(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        try await GamificationService.checkAchievements(for: user.id!, on: req)
        return .ok
    }
}
