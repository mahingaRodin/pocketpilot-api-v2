import Vapor

struct ChatResponseDTO: Content {
    let message: String
    let response: String
    let intent: String
    let contextData: ChatContextData?
    let timestamp: Date
}

struct ChatMessageDTO: Content {
    let id: UUID
    let message: String
    let response: String
    let intent: String
    let timestamp: Date
    
    init(from chatMessage: ChatMessage) throws {
        guard let id = chatMessage.id,
              let timestamp = chatMessage.createdAt else {
            throw Abort(.internalServerError)
        }
        
        self.id = id
        self.message = chatMessage.message
        self.response = chatMessage.response
        self.intent = chatMessage.intent
        self.timestamp = timestamp
    }
}

struct APIResponse<T: Content>: Content {
    let success: Bool
    let data: T?
    let message: String?
    
    init(success: Bool, data: T? = nil, message: String? = nil) {
        self.success = success
        self.data = data
        self.message = message
    }
}

struct EmptyResponse: Content {}
