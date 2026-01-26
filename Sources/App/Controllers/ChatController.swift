import Vapor
import Fluent

struct ChatController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let chat = routes.grouped("chat")
            .grouped(JWTAuthenticator())
        
        chat.post("ask", use: ask)
            .openAPI(
                summary: "Ask a question",
                description: "Processes a user query and returns an AI-generated response.",
                body: .type(AskRequest.self),
                response: .type(APIResponse<ChatResponseDTO>.self),
                auth: .bearer()
            )
            
        chat.get("history", use: getHistory)
            .openAPI(
                summary: "Get chat history",
                description: "Retrieves the user's chat history.",
                response: .type(APIResponse<[ChatMessageDTO]>.self),
                auth: .bearer()
            )
            
        chat.delete("history", use: clearHistory)
            .openAPI(
                summary: "Clear chat history",
                description: "Deletes all chat messages for the user.",
                response: .type(APIResponse<EmptyResponse>.self),
                auth: .bearer()
            )
    }
    
    struct AskRequest: Content {
        let message: String
    }
    
    // MARK: - Ask Question
    func ask(req: Request) async throws -> APIResponse<ChatResponseDTO> {
        let user = try req.auth.require(User.self)
        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }
        
        let askRequest = try req.content.decode(AskRequest.self)
        
        guard !askRequest.message.isEmpty else {
            throw Abort(.badRequest, reason: "Message cannot be empty")
        }
        
        let (response, intent, contextData) = try await AIChatService.processQuery(
            message: askRequest.message,
            userID: userID,
            on: req
        )
        
        let responseDTO = ChatResponseDTO(
            message: askRequest.message,
            response: response,
            intent: intent.rawValue,
            contextData: contextData,
            timestamp: Date()
        )
        
        return APIResponse(success: true, data: responseDTO)
    }
    
    // MARK: - Get Chat History
    func getHistory(req: Request) async throws -> APIResponse<[ChatMessageDTO]> {
        let user = try req.auth.require(User.self)
        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }
        
        let limit = req.query[Int.self, at: "limit"] ?? 20
        
        let messages = try await ChatMessage.query(on: req.db)
            .filter(\.$user.$id == userID)
            .sort(\.$createdAt, .descending)
            .limit(limit)
            .all()
        
        let dtos = try messages.map { message in
            try ChatMessageDTO(from: message)
        }
        
        return APIResponse(success: true, data: dtos)
    }
    
    // MARK: - Clear History
    func clearHistory(req: Request) async throws -> APIResponse<EmptyResponse> {
        let user = try req.auth.require(User.self)
        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }
        
        try await ChatMessage.query(on: req.db)
            .filter(\.$user.$id == userID)
            .delete()
        
        return APIResponse(success: true, data: EmptyResponse(), message: "Chat history cleared")
    }
}
