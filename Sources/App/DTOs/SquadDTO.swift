import Vapor

struct SquadResponse: Content {
    let id: UUID?
    let name: String
    let inviteCode: String
    let description: String?
    let members: [SquadMemberResponse]?
}

struct SquadMemberResponse: Content {
    let id: UUID?
    let userID: UUID
    let firstName: String
    let lastName: String
    let role: SquadRole
}

struct CreateSquadRequest: Content {
    let name: String
    let description: String?
}

struct JoinSquadRequest: Content {
    let inviteCode: String
}

struct SettlementResponse: Content {
    let fromUserID: UUID
    let fromUserName: String
    let toUserID: UUID
    let toUserName: String
    let amount: Double
}
