import XCTVapor
@testable import App

final class AppTests: XCTestCase {
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
    
    func testHealthEndpoint() async throws {
        try await app.test(.GET, "health") { res async in
            XCTAssertEqual(res.status, .ok)
            
            struct HealthResponse: Content {
                let status: String
                let timestamp: Double
            }
            
            let response = try? res.content.decode(HealthResponse.self)
            XCTAssertEqual(response?.status, "ok")
            XCTAssertNotNil(response?.timestamp)
        }
    }
    
    func testUserRegistration() async throws {
        let userRequest = UserRegistrationRequest(
            email: "test@example.com",
            password: "Password123!",
            confirmPassword: "Password123!",
            firstName: "John",
            lastName: "Doe"
        )
        
        try await app.test(.POST, "api/v1/auth/register", beforeRequest: { req in
            try req.content.encode(userRequest)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            
            let response = try? res.content.decode(AuthResponse.self)
            XCTAssertEqual(response?.user.email, "test@example.com")
            XCTAssertEqual(response?.user.firstName, "John")
            XCTAssertEqual(response?.user.lastName, "Doe")
            XCTAssertNotNil(response?.accessToken)
        }
    }
    
    func testUserLogin() async throws {
        // First register a user
        let user = User(
            email: "test@example.com",
            passwordHash: try Bcrypt.hash("Password123!"),
            firstName: "John",
            lastName: "Doe"
        )
        try await user.save(on: app.db)
        
        let loginRequest = UserLoginRequest(
            email: "test@example.com",
            password: "Password123!",
            deviceInfo: nil
        )
        
        try await app.test(.POST, "api/v1/auth/login", beforeRequest: { req in
            try req.content.encode(loginRequest)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            
            let response = try? res.content.decode(AuthResponse.self)
            XCTAssertEqual(response?.user.email, "test@example.com")
            XCTAssertNotNil(response?.accessToken)
        }
    }
    
    func testUpdateProfileWithMonthlyIncome() async throws {
        // 1. Create and authenticate user
        let user = User(
            email: "update@example.com",
            passwordHash: try Bcrypt.hash("Password123!"),
            firstName: "John",
            lastName: "Doe"
        )
        try await user.save(on: app.db)
        let token = try await app.jwtService.generateUserToken(for: user)
        
        // 2. Update profile with monthly income
        let updateRequest = UserUpdateRequest(
            firstName: "John",
            lastName: "Updated",
            monthlyIncome: 5000.0
        )
        
        try await app.test(.PUT, "api/v1/user/profile", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
            try req.content.encode(updateRequest)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            let response = try? res.content.decode(UserResponse.self)
            XCTAssertEqual(response?.lastName, "Updated")
            XCTAssertEqual(response?.monthlyIncome, 5000.0)
        }
    }
    
    func testCreateExpense() async throws {
        // Create and authenticate user
        let user = User(
            email: "test@example.com",
            passwordHash: try Bcrypt.hash("Password123!"),
            firstName: "John",
            lastName: "Doe"
        )
        try await user.save(on: app.db)
        
        let token = try await app.jwtService.generateUserToken(for: user)
        
        let expenseRequest = CreateExpenseRequest(
            amount: 25.50,
            description: "Lunch",
            category: ExpenseCategory.food.rawValue,
            date: Date(),
            notes: "Business lunch",
            squadID: nil
        )
        
        try await app.test(.POST, "api/v1/expenses", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
            try req.content.encode(expenseRequest)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            
            let response = try? res.content.decode(ExpenseResponse.self)
            XCTAssertEqual(response?.amount, 25.50)
            XCTAssertEqual(response?.description, "Lunch")
            XCTAssertEqual(response?.category, .food)
            XCTAssertEqual(response?.notes, "Business lunch")
        }
    }
    
    func testGetExpenses() async throws {
        // Create and authenticate user
        let user = User(
            email: "test@example.com",
            passwordHash: try Bcrypt.hash("Password123!"),
            firstName: "John",
            lastName: "Doe"
        )
        try await user.save(on: app.db)
        
        // Create some expenses
        let expense1 = Expense(
            userID: user.id!,
            amount: 25.50,
            description: "Lunch",
            category: .food,
            date: Date()
        )
        let expense2 = Expense(
            userID: user.id!,
            amount: 15.00,
            description: "Coffee",
            category: .food,
            date: Date()
        )
        
        try await expense1.save(on: app.db)
        try await expense2.save(on: app.db)
        
        let token = try await app.jwtService.generateUserToken(for: user)
        
        try await app.test(.GET, "api/v1/expenses", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            
            let response = try? res.content.decode(ExpenseListResponse.self)
            XCTAssertEqual(response?.expenses.count, 2)
            XCTAssertEqual(response?.total, 2)
            XCTAssertEqual(response?.totalAmount, 40.50)
        }
    }
    
    func testDownloadReceipt() async throws {
        // Create and authenticate user
        let user = User(
            email: "test@example.com",
            passwordHash: try Bcrypt.hash("Password123!"),
            firstName: "John",
            lastName: "Doe"
        )
        try await user.save(on: app.db)
        
        let token = try await app.jwtService.generateUserToken(for: user)
        
        // Create expense
        let expense = Expense(
            userID: user.id!,
            amount: 25.50,
            description: "Lunch",
            category: .food,
            date: Date()
        )
        try await expense.save(on: app.db)
        
        // 1. Generate receipt first
        try await app.test(.POST, "api/v1/receipts/generate/\(expense.id!)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
        }
        
        // 2. Test download
        try await app.test(.GET, "api/v1/receipts/\(expense.id!)/download", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(res.headers.contains(name: .contentDisposition))
            let disposition = res.headers.first(name: .contentDisposition) ?? ""
            XCTAssertTrue(disposition.contains("attachment"))
            XCTAssertTrue(disposition.contains("receipt-Lunch"))
        }
    }
}
