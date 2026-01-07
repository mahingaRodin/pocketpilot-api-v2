import Vapor

struct ErrorResponse: Content {
    let error: Bool
    let reason: String
    let code: String?
    let timestamp: Date
    
    init(reason: String, code: String? = nil) {
        self.error = true
        self.reason = reason
        self.code = code
        self.timestamp = Date()
    }
}

extension ErrorMiddleware {
    static func `default`(environment: Environment) -> ErrorMiddleware {
        return .init { req, error in
            // Log the error
            req.logger.report(error: error)
            
            // Create response based on error type
            let response: Response
            let status: HTTPResponseStatus
            let reason: String
            
            switch error {
            case let abort as AbortError:
                status = abort.status
                reason = abort.reason
                
            case let validation as ValidationsError:
                status = .badRequest
                reason = "Validation failed: \(validation.description)"
                
            case is DecodingError:
                status = .badRequest
                reason = "Invalid request data"
                
            default:
                status = .internalServerError
                reason = environment.isRelease ? "Internal server error" : String(describing: error)
            }
            
            response = Response(status: status)
            
            do {
                let errorResponse = ErrorResponse(reason: reason)
                response.body = try .init(data: JSONEncoder().encode(errorResponse))
                response.headers.contentType = .json
            } catch {
                response.body = .init(string: "Internal server error")
                response.headers.contentType = .plainText
            }
            
            return response
        }
    }
}