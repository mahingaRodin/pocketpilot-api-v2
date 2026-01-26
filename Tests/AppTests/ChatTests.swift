import XCTVapor
import Fluent
@testable import App

final class ChatTests: XCTestCase {
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
    
    func testAskQuestion() async throws {
        // Create and authenticate user
        let user = User(
            email: "chat@example.com",
            passwordHash: try Bcrypt.hash("Password123!"),
            firstName: "Chat",
            lastName: "User"
        )
        try await user.save(on: app.db)
        let token = try await app.jwtService.generateUserToken(for: user)
        
        // Add some expenses for the AI to analyze
        let expense = Expense(
            userID: user.id!,
            amount: 50.0,
            description: "Grocery shopping",
            category: .shopping,
            date: Date()
        )
        try await expense.save(on: app.db)
        
        let askRequest = ChatController.AskRequest(message: "Where did I spend most of my money?")
        
        try await app.test(.POST, "api/v1/chat/ask", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
            try req.content.encode(askRequest)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            let response = try? res.content.decode(APIResponse<ChatResponseDTO>.self)
            XCTAssertNotNil(response?.data)
            XCTAssertTrue(response?.success ?? false)
            XCTAssertEqual(response?.data?.intent, "category_breakdown")
        }
    }
    
    func testChatHistory() async throws {
        // Create and authenticate user
        let user = User(
            email: "history@example.com",
            passwordHash: try Bcrypt.hash("Password123!"),
            firstName: "History",
            lastName: "User"
        )
        try await user.save(on: app.db)
        let token = try await app.jwtService.generateUserToken(for: user)
        
        // Add a chat message
        let chatMessage = ChatMessage(
            userID: user.id!,
            message: "Hello",
            response: "Hi there!",
            intent: "general"
        )
        try await chatMessage.save(on: app.db)
        
        try await app.test(.GET, "api/v1/chat/history", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            let response = try? res.content.decode(APIResponse<[ChatMessageDTO]>.self)
            XCTAssertEqual(response?.data?.count, 1)
            XCTAssertEqual(response?.data?.first?.message, "Hello")
        }
    }
    
    func testClearHistory() async throws {
        // Create and authenticate user
        let user = User(
            email: "clear@example.com",
            passwordHash: try Bcrypt.hash("Password123!"),
            firstName: "Clear",
            lastName: "User"
        )
        try await user.save(on: app.db)
        let token = try await app.jwtService.generateUserToken(for: user)
        
        // Add a chat message
        let chatMessage = ChatMessage(
            userID: user.id!,
            message: "Bye",
            response: "Goodbye!",
            intent: "general"
        )
        try await chatMessage.save(on: app.db)
        
        try await app.test(.DELETE, "api/v1/chat/history", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
        }
        
        // Verify history is empty
        try await self.app.test(.GET, "api/v1/chat/history", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }) { historyRes async in
            let historyResponse = try? historyRes.content.decode(APIResponse<[ChatMessageDTO]>.self)
            XCTAssertEqual(historyResponse?.data?.count, 0)
        }
    }
}
