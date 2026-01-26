import Vapor
import Fluent

struct GamificationService {
    
    // MARK: - Initialize Default Achievements
    static func seedDefaultAchievements(on db: Database) async throws {
        let achievements = [
            // Tracking Achievements
            Achievement(
                code: "first_expense",
                name: "Getting Started",
                description: "Track your first expense",
                category: .tracking,
                icon: "star.fill",
                requiredValue: 1,
                points: 10,
                tier: .bronze
            ),
            Achievement(
                code: "expense_10",
                name: "On a Roll",
                description: "Track 10 expenses",
                category: .tracking,
                icon: "flame.fill",
                requiredValue: 10,
                points: 25,
                tier: .bronze
            ),
            Achievement(
                code: "expense_50",
                name: "Expense Master",
                description: "Track 50 expenses",
                category: .tracking,
                icon: "star.circle.fill",
                requiredValue: 50,
                points: 100,
                tier: .silver
            ),
            Achievement(
                code: "expense_100",
                name: "Century Club",
                description: "Track 100 expenses",
                category: .tracking,
                icon: "crown.fill",
                requiredValue: 100,
                points: 250,
                tier: .gold
            ),
            
            // Budget Achievements
            Achievement(
                code: "budget_first",
                name: "Budget Beginner",
                description: "Create your first budget",
                category: .budget,
                icon: "chart.bar.fill",
                requiredValue: 1,
                points: 15,
                tier: .bronze
            ),
            Achievement(
                code: "budget_month",
                name: "Budget Hero",
                description: "Stay under budget for 1 month",
                category: .budget,
                icon: "checkmark.shield.fill",
                requiredValue: 1,
                points: 50,
                tier: .silver
            ),
            Achievement(
                code: "budget_3months",
                name: "Budget Legend",
                description: "Stay under budget for 3 months",
                category: .budget,
                icon: "shield.fill",
                requiredValue: 3,
                points: 200,
                tier: .gold
            ),
            
            // Saving Achievements
            Achievement(
                code: "save_100",
                name: "Penny Pincher",
                description: "Save $100 compared to last month",
                category: .saving,
                icon: "dollarsign.circle.fill",
                requiredValue: 100,
                points: 30,
                tier: .bronze
            ),
            Achievement(
                code: "save_500",
                name: "Smart Saver",
                description: "Save $500 compared to last month",
                category: .saving,
                icon: "banknote.fill",
                requiredValue: 500,
                points: 100,
                tier: .silver
            ),
            Achievement(
                code: "save_1000",
                name: "Savings Master",
                description: "Save $1000 compared to last month",
                category: .saving,
                icon: "gift.fill",
                requiredValue: 1000,
                points: 300,
                tier: .gold
            ),
            
            // Streak Achievements
            Achievement(
                code: "streak_7",
                name: "Week Warrior",
                description: "Track expenses for 7 days straight",
                category: .streak,
                icon: "calendar.badge.clock",
                requiredValue: 7,
                points: 50,
                tier: .bronze
            ),
            Achievement(
                code: "streak_30",
                name: "Monthly Master",
                description: "Track expenses for 30 days straight",
                category: .streak,
                icon: "calendar.badge.exclamationmark",
                requiredValue: 30,
                points: 150,
                tier: .silver
            ),
            Achievement(
                code: "streak_100",
                name: "Consistency King",
                description: "Track expenses for 100 days straight",
                category: .streak,
                icon: "trophy.fill",
                requiredValue: 100,
                points: 500,
                tier: .platinum
            ),
            
            // Scanning Achievements
            Achievement(
                code: "scan_first",
                name: "Scanner Novice",
                description: "Scan your first receipt",
                category: .scanning,
                icon: "camera.fill",
                requiredValue: 1,
                points: 10,
                tier: .bronze
            ),
            Achievement(
                code: "scan_10",
                name: "Receipt Pro",
                description: "Scan 10 receipts",
                category: .scanning,
                icon: "camera.metering.multispot",
                requiredValue: 10,
                points: 40,
                tier: .bronze
            ),
            Achievement(
                code: "scan_50",
                name: "Scan Master",
                description: "Scan 50 receipts",
                category: .scanning,
                icon: "doc.text.magnifyingglass",
                requiredValue: 50,
                points: 150,
                tier: .gold
            )
        ]
        
        for achievement in achievements {
            if try await Achievement.query(on: db).filter(\.$code == achievement.code).first() == nil {
                try await achievement.save(on: db)
            }
        }
    }
    
    // MARK: - Check and Update Achievements
    static func checkAchievements(for userID: UUID, on req: Request) async throws {
        let allAchievements = try await Achievement.query(on: req.db).all()
        
        let expenseCount = try await Expense.query(on: req.db)
            .filter(\.$user.$id == userID)
            .count()
        
        let scanCount = try await Expense.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$receiptURL != nil)
            .count()
        
        let budgetMonths = try await calculateBudgetAdherenceMonths(userID: userID, on: req)
        let savingsAmount = try await calculateSavingsVsLastMonth(userID: userID, on: req)
        let currentStreak = try await getCurrentStreak(userID: userID, on: req)
        
        for achievement in allAchievements {
            let currentValue: Int
            switch achievement.category {
            case .tracking, .spending: currentValue = expenseCount
            case .scanning: currentValue = scanCount
            case .budget: currentValue = budgetMonths
            case .saving: currentValue = Int(savingsAmount)
            case .streak: currentValue = currentStreak
            }
            
            if currentValue >= achievement.requiredValue {
                try await unlockAchievement(achievementID: achievement.id!, userID: userID, progress: currentValue, on: req)
            } else {
                try await updateAchievementProgress(achievementID: achievement.id!, userID: userID, progress: currentValue, on: req)
            }
        }
        
        try await updateLeaderboard(userID: userID, on: req)
    }
    
    private static func unlockAchievement(achievementID: UUID, userID: UUID, progress: Int, on req: Request) async throws {
        if let existing = try await UserAchievement.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$achievement.$id == achievementID)
            .first() {
            if !existing.isUnlocked {
                existing.isUnlocked = true
                existing.unlockedAt = Date()
                existing.progress = progress
                try await existing.save(on: req.db)
                try await sendAchievementNotification(userID: userID, achievementID: achievementID, on: req)
            }
        } else {
            let userAchievement = UserAchievement(userID: userID, achievementID: achievementID, progress: progress, isUnlocked: true)
            userAchievement.unlockedAt = Date()
            try await userAchievement.save(on: req.db)
            try await sendAchievementNotification(userID: userID, achievementID: achievementID, on: req)
        }
    }
    
    private static func updateAchievementProgress(achievementID: UUID, userID: UUID, progress: Int, on req: Request) async throws {
        if let existing = try await UserAchievement.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$achievement.$id == achievementID)
            .first() {
            existing.progress = progress
            try await existing.save(on: req.db)
        } else {
            let userAchievement = UserAchievement(userID: userID, achievementID: achievementID, progress: progress)
            try await userAchievement.save(on: req.db)
        }
    }
    
    // MARK: - Helper Functions
    
    private static func calculateBudgetAdherenceMonths(userID: UUID, on req: Request) async throws -> Int {
        // Simplified mockup logic
        return 1
    }
    
    private static func calculateSavingsVsLastMonth(userID: UUID, on req: Request) async throws -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: startOfThisMonth)!
        let startOfLastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: endOfLastMonth))!
        
        let thisMonthTotal = try await Expense.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$date >= startOfThisMonth)
            .sum(\.$amount) ?? 0.0
            
        let lastMonthTotal = try await Expense.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$date >= startOfLastMonth)
            .filter(\.$date <= endOfLastMonth)
            .sum(\.$amount) ?? 0.0
            
        return max(lastMonthTotal - thisMonthTotal, 0)
    }
    
    private static func getCurrentStreak(userID: UUID, on req: Request) async throws -> Int {
        if let streak = try await UserStreak.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$streakType == .dailyTracking)
            .first() {
            return streak.currentStreak
        }
        return 0
    }
    
    private static func sendAchievementNotification(userID: UUID, achievementID: UUID, on req: Request) async throws {
        guard let achievement = try await Achievement.find(achievementID, on: req.db) else { return }
        _ = try await NotificationService.createNotification(
            for: userID,
            type: .savingsGoal,
            title: "🏆 Achievement Unlocked!",
            message: "You've earned '\(achievement.name)'! +\(achievement.points) points",
            priority: .normal,
            category: "achievement",
            on: req
        )
    }
    
    private static func updateLeaderboard(userID: UUID, on req: Request) async throws {
        let userAchievements = try await UserAchievement.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$isUnlocked == true)
            .with(\.$achievement)
            .all()
            
        let totalPoints = userAchievements.reduce(0) { $0 + $1.achievement.points }
        let achievementsCount = userAchievements.count
        let challengesCompleted = try await UserChallenge.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$status == .completed)
            .count()
            
        if let entry = try await LeaderboardEntry.query(on: req.db).filter(\.$user.$id == userID).first() {
            entry.totalPoints = totalPoints
            entry.achievementsCount = achievementsCount
            entry.challengesCompleted = challengesCompleted
            try await entry.save(on: req.db)
        } else {
            let newEntry = LeaderboardEntry(userID: userID, totalPoints: totalPoints, achievementsCount: achievementsCount, challengesCompleted: challengesCompleted)
            try await newEntry.save(on: req.db)
        }
        
        try await recalculateRanks(on: req)
    }
    
    private static func recalculateRanks(on req: Request) async throws {
        let entries = try await LeaderboardEntry.query(on: req.db).sort(\.$totalPoints, .descending).all()
        for (index, entry) in entries.enumerated() {
            entry.currentRank = index + 1
            try await entry.save(on: req.db)
        }
    }
    
    static func updateStreak(userID: UUID, type: StreakType, on req: Request) async throws {
        let today = Calendar.current.startOfDay(for: Date())
        if let streak = try await UserStreak.query(on: req.db).filter(\.$user.$id == userID).filter(\.$streakType == type).first() {
            let lastActivity = Calendar.current.startOfDay(for: streak.lastActivityDate)
            let daysDiff = Calendar.current.dateComponents([.day], from: lastActivity, to: today).day ?? 0
            
            if daysDiff == 1 {
                streak.currentStreak += 1
                streak.longestStreak = max(streak.longestStreak, streak.currentStreak)
            } else if daysDiff > 1 {
                streak.currentStreak = 1
            }
            streak.lastActivityDate = Date()
            try await streak.save(on: req.db)
        } else {
            let newStreak = UserStreak(userID: userID, streakType: type)
            newStreak.currentStreak = 1
            newStreak.longestStreak = 1
            try await newStreak.save(on: req.db)
        }
    }
}
