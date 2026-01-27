import XCTest
import XCTVapor
import Fluent
@testable import App

final class SafeToSpendTests: XCTestCase {
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
    
    func testSafeToSpendCalculation() async throws {
        // 1. Create a user with income
        let user = User(
            email: "test@safetospend.com",
            passwordHash: try Bcrypt.hash("password"),
            firstName: "Safe",
            lastName: "Tester"
        )
        user.monthlyIncome = 3000.0
        try await user.save(on: app.db)
        
        // 2. Add some expenses
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        
        let expense1 = Expense(
            userID: user.id!,
            amount: 500.0,
            description: "Groceries",
            category: .food,
            date: startOfMonth
        )
        try await expense1.save(on: app.db)
        
        // 3. Request dashboard and check safe-to-spend
        let token = try await app.jwtService.generateUserToken(for: user)
        
        try await app.test(.GET, "api/v1/dashboard", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: token)
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
            let dashboard = try res.content.decode(DashboardResponse.self)
            XCTAssertNotNil(dashboard.safeToSpend)
            
            if let sts = dashboard.safeToSpend {
                XCTAssertEqual(sts.monthlyRemaining, 2500.0)
                XCTAssertGreaterThan(sts.dailyAllowance, 0)
                XCTAssertEqual(sts.status, .onTrack)
            }
        }
    }
}
