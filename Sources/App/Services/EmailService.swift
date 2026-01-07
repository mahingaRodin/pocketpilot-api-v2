import Vapor

protocol EmailServiceProtocol: Sendable {
    func sendVerificationEmail(to email: String, token: String, baseURL: String) async throws
    func sendPasswordResetEmail(to email: String, token: String, baseURL: String) async throws
    func sendPasswordChangedNotification(to email: String) async throws
}

struct MockEmailService: EmailServiceProtocol {
    let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func sendVerificationEmail(to email: String, token: String, baseURL: String) async throws {
        let verificationURL = "\(baseURL)/verify-email?token=\(token)"
        
        logger.info("📧 Verification Email")
        logger.info("To: \(email)")
        logger.info("Subject: Verify your PocketPilot account")
        logger.info("Verification URL: \(verificationURL)")
        logger.info("---")
    }
    
    func sendPasswordResetEmail(to email: String, token: String, baseURL: String) async throws {
        let resetURL = "\(baseURL)/reset-password?token=\(token)"
        
        logger.info("📧 Password Reset Email")
        logger.info("To: \(email)")
        logger.info("Subject: Reset your PocketPilot password")
        logger.info("Reset URL: \(resetURL)")
        logger.info("---")
    }
    
    func sendPasswordChangedNotification(to email: String) async throws {
        logger.info("📧 Password Changed Notification")
        logger.info("To: \(email)")
        logger.info("Subject: Your PocketPilot password has been changed")
        logger.info("Message: Your password was successfully changed. If you didn't make this change, please contact support.")
        logger.info("---")
    }
}

// MARK: - Real Email Service Implementation (Template)
struct SMTPEmailService: EmailServiceProtocol {
    // TODO: Implement with actual SMTP service like SendGrid, Mailgun, etc.
    
    func sendVerificationEmail(to email: String, token: String, baseURL: String) async throws {
        // Implementation would go here
        throw Abort(.notImplemented, reason: "SMTP email service not implemented")
    }
    
    func sendPasswordResetEmail(to email: String, token: String, baseURL: String) async throws {
        // Implementation would go here
        throw Abort(.notImplemented, reason: "SMTP email service not implemented")
    }
    
    func sendPasswordChangedNotification(to email: String) async throws {
        // Implementation would go here
        throw Abort(.notImplemented, reason: "SMTP email service not implemented")
    }
}

// MARK: - Application Extension
extension Application {
    private struct EmailServiceKey: StorageKey {
        typealias Value = EmailServiceProtocol
    }
    
    var emailService: EmailServiceProtocol {
        get {
            storage[EmailServiceKey.self] ?? MockEmailService(logger: logger)
        }
        set {
            storage[EmailServiceKey.self] = newValue
        }
    }
}

extension Request {
    var emailService: EmailServiceProtocol {
        application.emailService
    }
}