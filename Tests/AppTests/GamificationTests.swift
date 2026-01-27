import XCTVapor
import Fluent
@testable import App

final class GamificationTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
        try await app.autoMigrate()
    }
    
    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
    }
    
    func testTrackFirstExpenseAchievement() async throws {
        // Create and authenticate user
        let user = User(
            email: "gamer@example.com",
            passwordHash: try Bcrypt.hash("Password123!"),
            firstName: "Gamer",
            lastName: "User"
        )
        try await user.save(on: app.db)
        let token = try await app.jwtService.generateUserToken(for: user)
        
        // Create an expense
        let expenseRequest = CreateExpenseRequest(
            amount: 10.0,
            description: "Test Expense",
            category: ExpenseCategory.food.rawValue,
            date: Date(),
            notes: nil,
            squadID: nil
        )
        
        try await app.test(.POST, "api/v1/expenses", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
            try req.content.encode(expenseRequest)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
        }
        
        // Verify achievement "first_expense" is unlocked
        try await app.test(.GET, "api/v1/gamification/achievements", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            let achievements = try? res.content.decode([AchievementResponse].self)
            let firstExpense = achievements?.first(where: { $0.code == "first_expense" })
            XCTAssertNotNil(firstExpense)
            XCTAssertTrue(firstExpense?.isUnlocked ?? false)
            XCTAssertEqual(firstExpense?.progress, 1)
        }
        
        // Check profile
        try await app.test(.GET, "api/v1/gamification/profile", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            let profile = try? res.content.decode(GamificationProfileResponse.self)
            XCTAssertGreaterThanOrEqual(profile?.totalPoints ?? 0, 10) 
            XCTAssertEqual(profile?.currentStreak, 1)
        }
    }
    
    func testStreakResetsAfterGap() async throws {
        // Create and authenticate user
        let user = User(
            email: "streaker@example.com",
            passwordHash: try Bcrypt.hash("Password123!"),
            firstName: "Streak",
            lastName: "User"
        )
        try await user.save(on: app.db)
        let token = try await app.jwtService.generateUserToken(for: user)
        
        // Set an old streak activity date
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let streak = UserStreak(userID: user.id!, streakType: .dailyTracking)
        streak.currentStreak = 5
        streak.lastActivityDate = threeDaysAgo
        try await streak.save(on: app.db)
        
        // Create an expense today
        let expenseRequest = CreateExpenseRequest(
            amount: 5.0,
            description: "Today's Expense",
            category: ExpenseCategory.other.rawValue,
            date: Date(),
            notes: nil,
            squadID: nil
        )
        
        try await app.test(.POST, "api/v1/expenses", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
            try req.content.encode(expenseRequest)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
        }
        
        // Verify streak is reset to 1
        try await app.test(.GET, "api/v1/gamification/profile", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            let profile = try? res.content.decode(GamificationProfileResponse.self)
            XCTAssertEqual(profile?.currentStreak, 1)
        }
    }
}
