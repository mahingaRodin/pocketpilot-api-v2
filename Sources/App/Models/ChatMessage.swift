import Fluent
import Vapor

final class ChatMessage: Model, Content, @unchecked Sendable {
    static let schema = "chat_messages"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "message")
    var message: String
    
    @Field(key: "response")
    var response: String
    
    @Field(key: "intent")
    var intent: String
    
    @OptionalField(key: "context_data")
    var contextData: ChatContextData?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        userID: User.IDValue,
        message: String,
        response: String,
        intent: String,
        contextData: ChatContextData? = nil
    ) {
        self.id = id
        self.$user.id = userID
        self.message = message
        self.response = response
        self.intent = intent
        self.contextData = contextData
    }
}

struct ChatContextData: Codable {
    var amount: Double?
    var category: String?
    var timeframe: String?
    var comparison: String?
    var suggestions: [String]?
}
