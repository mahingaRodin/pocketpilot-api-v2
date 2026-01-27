import XCTest
import XCTVapor
import Fluent
@testable import App

final class SquadTests: XCTestCase {
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
    
    func testSquadCreationAndJoining() async throws {
        // 1. Create User A
        let userA = User(email: "usera@squad.com", passwordHash: "hashA", firstName: "User", lastName: "A")
        try await userA.save(on: app.db)
        let tokenA = try await app.jwtService.generateUserToken(for: userA)
        
        // 2. Create Squad
        let createReq = CreateSquadRequest(name: "Test Squad", description: "A squad for testing")
        var inviteCode = ""
        var squadID: UUID?
        
        try await app.test(.POST, "api/v1/squads", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: tokenA)
            try req.content.encode(createReq)
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
            let squad = try res.content.decode(SquadResponse.self)
            XCTAssertEqual(squad.name, "Test Squad")
            inviteCode = squad.inviteCode
            squadID = squad.id
        }
        
        // 3. Create User B and Join Squad
        let userB = User(email: "userb@squad.com", passwordHash: "hashB", firstName: "User", lastName: "B")
        try await userB.save(on: app.db)
        let tokenB = try await app.jwtService.generateUserToken(for: userB)
        
        let joinReq = JoinSquadRequest(inviteCode: inviteCode)
        try await app.test(.POST, "api/v1/squads/join", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: tokenB)
            try req.content.encode(joinReq)
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
        
        // 4. Verify members
        try await app.test(.GET, "api/v1/squads/\(squadID!)/members", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: tokenA)
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
            let members = try res.content.decode([SquadMemberResponse].self)
            XCTAssertEqual(members.count, 2)
        }
    }
    
    func testSquadSettlements() async throws {
        // 1. Set up squad with 2 users
        let userA = User(email: "usera@settle.com", passwordHash: "hashA", firstName: "User", lastName: "A")
        try await userA.save(on: app.db)
        let tokenA = try await app.jwtService.generateUserToken(for: userA)
        
        let userB = User(email: "userb@settle.com", passwordHash: "hashB", firstName: "User", lastName: "B")
        try await userB.save(on: app.db)
        
        let squad = Squad(name: "Settle Squad", inviteCode: "SETTLE1")
        try await squad.save(on: app.db)
        let sID = squad.id!
        
        try await SquadMember(squadID: sID, userID: userA.id!, role: .admin).save(on: app.db)
        try await SquadMember(squadID: sID, userID: userB.id!, role: .member).save(on: app.db)
        
        // 2. User A pays $100 for Groceries (Both share $50)
        let expense = Expense(
            userID: userA.id!,
            amount: 100.0,
            description: "Groceries",
            category: .food,
            date: Date()
        )
        expense.$squad.id = sID
        try await expense.save(on: app.db)
        
        // 3. Get settlements
        try await app.test(.GET, "api/v1/squads/\(sID)/settlements", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: tokenA)
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
            let settlements = try res.content.decode([SettlementResponse].self)
            XCTAssertEqual(settlements.count, 1)
            let s = settlements[0]
            XCTAssertEqual(s.fromUserID, userB.id!)
            XCTAssertEqual(s.toUserID, userA.id!)
            XCTAssertEqual(s.amount, 50.0)
        }
    }
}
