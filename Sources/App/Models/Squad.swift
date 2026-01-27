import Vapor
import Fluent

final class Squad: Model, Content, @unchecked Sendable {
    static let schema = "squads"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "invite_code")
    var inviteCode: String
    
    @OptionalField(key: "description")
    var description: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Children(for: \.$squad)
    var members: [SquadMember]
    
    @Children(for: \.$squad)
    var expenses: [Expense]
    
    init() { }
    
    init(id: UUID? = nil, name: String, inviteCode: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.description = description
    }
}

final class SquadMember: Model, Content, @unchecked Sendable {
    static let schema = "squad_members"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "squad_id")
    var squad: Squad
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "role")
    var role: SquadRole
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() { }
    
    init(id: UUID? = nil, squadID: UUID, userID: UUID, role: SquadRole = .member) {
        self.id = id
        self.$squad.id = squadID
        self.$user.id = userID
        self.role = role
    }
}

enum SquadRole: String, Codable {
    case admin = "admin"
    case member = "member"
}

final class SquadInvitation: Model, Content, @unchecked Sendable {
    static let schema = "squad_invitations"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "squad_id")
    var squad: Squad
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "token")
    var token: String
    
    @Field(key: "status")
    var status: InvitationStatus
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil, squadID: UUID, email: String, token: String) {
        self.id = id
        self.$squad.id = squadID
        self.email = email
        self.token = token
        self.status = .pending
    }
}

enum InvitationStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case expired = "expired"
}
