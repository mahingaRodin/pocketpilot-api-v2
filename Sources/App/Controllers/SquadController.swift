import Vapor
import Fluent
import VaporToOpenAPI

struct SquadController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let squads = routes.grouped("squads").grouped(JWTAuthenticator())
        
        squads.post(use: createSquad)
        squads.post("join", use: joinSquad)
        squads.get(use: getMySquads)
        squads.get(":squadID", "members", use: getSquadMembers)
        squads.get(":squadID", "settlements", use: getSettlements)
        squads.delete(":squadID", use: deleteSquad)
    }
    
    // MARK: - Handlers
    
    func createSquad(req: Request) async throws -> SquadResponse {
        let user = try req.auth.require(User.self)
        let createRequest = try req.content.decode(CreateSquadRequest.self)
        
        let squad = Squad(
            name: createRequest.name,
            inviteCode: String(UUID().uuidString.prefix(8)).uppercased(),
            description: createRequest.description
        )
        try await squad.save(on: req.db)
        
        let member = SquadMember(
            squadID: try squad.requireID(),
            userID: try user.requireID(),
            role: .admin
        )
        try await member.save(on: req.db)
        
        return SquadResponse(
            id: squad.id,
            name: squad.name,
            inviteCode: squad.inviteCode,
            description: squad.description,
            members: nil
        )
    }
    
    func joinSquad(req: Request) async throws -> SquadResponse {
        let user = try req.auth.require(User.self)
        let joinRequest = try req.content.decode(JoinSquadRequest.self)
        
        guard let squad = try await Squad.query(on: req.db)
            .filter(\.$inviteCode == joinRequest.inviteCode.uppercased())
            .first() else {
            throw Abort(.notFound, reason: "Squad not found with this invite code.")
        }
        
        let existingMember = try await SquadMember.query(on: req.db)
            .filter(\.$squad.$id == squad.id!)
            .filter(\.$user.$id == user.id!)
            .first()
        
        if existingMember == nil {
            let member = SquadMember(
                squadID: try squad.requireID(),
                userID: try user.requireID(),
                role: .member
            )
            try await member.save(on: req.db)
        }
        
        return SquadResponse(
            id: squad.id,
            name: squad.name,
            inviteCode: squad.inviteCode,
            description: squad.description,
            members: nil
        )
    }
    
    func getMySquads(req: Request) async throws -> [SquadResponse] {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        
        let memberships = try await SquadMember.query(on: req.db)
            .filter(\.$user.$id == userID)
            .with(\.$squad)
            .all()
            
        return memberships.compactMap { membership in
            SquadResponse(
                id: membership.squad.id,
                name: membership.squad.name,
                inviteCode: membership.squad.inviteCode,
                description: membership.squad.description,
                members: nil
            )
        }
    }
    
    func getSquadMembers(req: Request) async throws -> [SquadMemberResponse] {
        guard let squadID = req.parameters.get("squadID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let members = try await SquadMember.query(on: req.db)
            .filter(\.$squad.$id == squadID)
            .with(\.$user)
            .all()
            
        return members.map { member in
            SquadMemberResponse(
                id: member.id,
                userID: member.$user.id,
                firstName: member.user.firstName,
                lastName: member.user.lastName,
                role: member.role
            )
        }
    }
    
    func getSettlements(req: Request) async throws -> [SettlementResponse] {
        guard let squadID = req.parameters.get("squadID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        // 1. Get all expenses for this squad
        let expenses = try await Expense.query(on: req.db)
            .filter(\.$squad.$id == squadID)
            .with(\.$user)
            .all()
            
        // 2. Get all members
        let members = try await SquadMember.query(on: req.db)
            .filter(\.$squad.$id == squadID)
            .with(\.$user)
            .all()
            
        let memberCount = members.count
        guard memberCount > 1 else { return [] }
        
        // 3. Calculate net balance for each user
        var balances: [UUID: Double] = [:]
        for member in members {
            balances[member.$user.id] = 0.0
        }
        
        for expense in expenses {
            let amount = expense.amount
            let payerID = expense.$user.id
            let share = amount / Double(memberCount)
            
            // Payer gets back 'amount - share'
            balances[payerID, default: 0] += (amount - share)
            
            // Others owe 'share'
            for member in members where member.$user.id != payerID {
                balances[member.$user.id, default: 0] -= share
            }
        }
        
        // 4. Simplify settlements (Greedy approach)
        var debtors = balances.filter { $1 < -0.01 }.map { ($0, -$1) }.sorted { $0.1 > $1.1 } // (ID, amount_owed)
        var creditors = balances.filter { $1 > 0.01 }.map { ($0, $1) }.sorted { $0.1 > $1.1 } // (ID, amount_to_receive)
        
        var settlements: [SettlementResponse] = []
        
        var dIndex = 0
        var cIndex = 0
        
        while dIndex < debtors.count && cIndex < creditors.count {
            let debtor = debtors[dIndex]
            let creditor = creditors[cIndex]
            
            let settlementAmount = min(debtor.1, creditor.1)
            
            let debtorUser = members.first { $0.$user.id == debtor.0 }?.user
            let creditorUser = members.first { $0.$user.id == creditor.0 }?.user
            
            settlements.append(SettlementResponse(
                fromUserID: debtor.0,
                fromUserName: debtorUser?.firstName ?? "Unknown",
                toUserID: creditor.0,
                toUserName: creditorUser?.firstName ?? "Unknown",
                amount: settlementAmount
            ))
            
            debtors[dIndex].1 -= settlementAmount
            creditors[cIndex].1 -= settlementAmount
            
            if debtors[dIndex].1 < 0.01 { dIndex += 1 }
            if creditors[cIndex].1 < 0.01 { cIndex += 1 }
        }
        
        return settlements
    }
    
    func deleteSquad(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        
        guard let squadID = req.parameters.get("squadID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        // 1. Find squad
        guard let squad = try await Squad.find(squadID, on: req.db) else {
            throw Abort(.notFound, reason: "Squad not found")
        }
        
        // 2. Verify user is admin
        guard let membership = try await SquadMember.query(on: req.db)
            .filter(\.$squad.$id == squadID)
            .filter(\.$user.$id == userID)
            .first() else {
            throw Abort(.forbidden, reason: "You are not a member of this squad")
        }
        
        guard membership.role == .admin else {
            throw Abort(.forbidden, reason: "Only admins can delete a squad")
        }
        
        // 3. Delete squad (Cascading delete will handle members and invitations if configured in migration)
        try await squad.delete(on: req.db)
        
        return .noContent
    }
}
