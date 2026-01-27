import XCTest
import XCTVapor
import Fluent
@testable import App

final class EcoImpactTests: XCTestCase {
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
    
    func testEcoImpactCalculation() async throws {
        // 1. Create a user
        let user = User(
            email: "eco@test.com",
            passwordHash: "hash",
            firstName: "Eco",
            lastName: "Tester"
        )
        try await user.save(on: app.db)
        let token = try await app.jwtService.generateUserToken(for: user)
        
        // 2. Add some high impact and low impact expenses
        let now = Date()
        let travelExpense = Expense(
            userID: user.id!,
            amount: 1000.0, // High impact
            description: "Flight to London",
            category: .travel,
            date: now
        )
        try await travelExpense.save(on: app.db)
        
        let educationExpense = Expense(
            userID: user.id!,
            amount: 100.0, // Low impact
            description: "Online Course",
            category: .education,
            date: now
        )
        try await educationExpense.save(on: app.db)
        
        // 3. Request dashboard and check eco-impact
        try await app.test(.GET, "api/v1/dashboard", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
            let dashboard = try res.content.decode(DashboardResponse.self)
            XCTAssertNotNil(dashboard.ecoImpact)
            
            if let eco = dashboard.ecoImpact {
                // travel: 1000 * 2.5 = 2500
                // education: 100 * 0.1 = 10
                // total = 2510 kg
                XCTAssertEqual(eco.carbonFootprintKg, 2510.0, accuracy: 0.1)
                XCTAssertEqual(eco.treesToOffset, 2510.0 / 21.0, accuracy: 0.1)
                XCTAssertEqual(eco.score, 0) // Over the 1000kg limit
            }
        }
    }
}
