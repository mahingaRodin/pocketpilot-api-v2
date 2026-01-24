import Vapor
import Fluent
import VaporToOpenAPI

struct ReceiptController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let receipts = routes.grouped("receipts")
            .grouped(JWTAuthenticator())
        
        receipts.post("scan", use: scanReceipt)
            .openAPI(
                summary: "Scan receipt",
                description: "Analyzes a receipt image and extracts data.",
                body: .type(UploadRequest.self), 
                response: .type(ScanReceiptResponse.self),
                auth: .bearer()
            )
            
        receipts.post("upload", use: uploadReceipt)
            .openAPI(
                summary: "Upload receipt",
                description: "Uploads a receipt image and creates an expense.",
                body: .type(UploadAndCreateRequest.self),
                response: .type(ExpenseResponse.self),
                auth: .bearer()
            )
            
        receipts.post("generate", ":expenseID", use: generateReceipt)
            .openAPI(
                summary: "Generate receipt",
                description: "Generates a digital receipt for an expense.",
                response: .type(ReceiptGenerationService.GeneratedReceipt.self),
                auth: .bearer()
            )
            
        receipts.get(":expenseID", "image", use: getReceiptImage)
            .openAPI(
                summary: "Get receipt image",
                description: "Retrieves the uploaded receipt image.",
                auth: .bearer()
            )
            
        receipts.get(":expenseID", "view", use: viewGeneratedReceipt)
            .openAPI(
                summary: "View receipt",
                description: "Views the generated digital receipt.",
                auth: .bearer()
            )
    }
    
    struct UploadRequest: Content {
        let file: File
    }
    
    struct UploadAndCreateRequest: Content {
        let file: File?
        let amount: Double
        let description: String
        let category: String
        let date: String
        let notes: String?
    }
    
    // MARK: - Scan Receipt (AI OCR)
    // MARK: - Scan Receipt (AI OCR)
    func scanReceipt(req: Request) async throws -> ScanReceiptResponse {
        struct UploadRequest: Content {
            let file: File
        }
        
        let upload = try req.content.decode(UploadRequest.self)
        
        // Convert ByteBuffer to Data
        let imageData = Data(buffer: upload.file.data)
        
        // Process with OCR
        let ocrResult = try await ReceiptOCRService.processReceipt(
            imageData: imageData,
            on: req
        )
        
        let response = ScanReceiptResponse(
            merchantName: ocrResult.merchantName,
            amount: ocrResult.amount,
            date: ocrResult.date,
            suggestedCategory: ocrResult.category,
            items: ocrResult.items,
            confidence: ocrResult.confidence,
            needsReview: ocrResult.confidence < 0.8
        )
        
        return response
    }
    
    // MARK: - Upload Receipt and Create Expense
    func uploadReceipt(req: Request) async throws -> ExpenseResponse {
        let user = try req.auth.require(User.self)
        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }
        
        struct UploadAndCreateRequest: Content {
            let file: File?
            let amount: Double
            let description: String
            let category: String
            let date: String
            let notes: String?
        }
        
        let upload = try req.content.decode(UploadAndCreateRequest.self)
        
        // Parse date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Try with fractional seconds first
        var validDate: Date? = formatter.date(from: upload.date)
        
        if validDate == nil {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            validDate = formatter.date(from: upload.date)
        }
        
        guard let date = validDate else {
            throw Abort(.badRequest, reason: "Invalid date format")
        }
        
        // Save image if provided
        var receiptURL: String? = nil
        if let file = upload.file {
            // Convert ByteBuffer to Data
            let imageData = Data(buffer: file.data)
            receiptURL = try await saveReceiptImage(imageData, on: req)
        }
        
        // Parse category string to enum, default to .other if invalid
        let category = ExpenseCategory.from(upload.category) ?? .other
        
        // Create expense
        let expense = Expense(
            userID: userID,
            amount: upload.amount,
            description: upload.description,
            category: category,
            date: date,
            notes: upload.notes
        )
        
        expense.receiptURL = receiptURL
        
        try await expense.save(on: req.db)
        
        let expenseResponse = ExpenseResponse(expense: expense)
        return expenseResponse
    }
    
    // MARK: - Get Receipt Image
    func getReceiptImage(req: Request) async throws -> Response {
        let user = try req.auth.require(User.self)
        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }
        
        guard let expenseID = req.parameters.get("expenseID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid expense ID")
        }
        
        guard let expense = try await Expense.find(expenseID, on: req.db) else {
            throw Abort(.notFound, reason: "Expense not found")
        }
        
        // Verify ownership
        guard expense.$user.id == userID else {
            throw Abort(.forbidden, reason: "Access denied")
        }
        
        guard let receiptURL = expense.receiptURL else {
            throw Abort(.notFound, reason: "No receipt found for this expense")
        }
        
        // For local storage, stream file
        // Ensure path is safe
        let directory = req.application.directory.publicDirectory
        // receiptURL usually starts with /receipts/, strip leading /
        let relativePath = String(receiptURL.dropFirst())
        let fullPath = directory + relativePath
        
        return try await req.fileio.asyncStreamFile(at: fullPath)
    }
    
    // MARK: - Generate Generative AI Receipt
    func generateReceipt(req: Request) async throws -> ReceiptGenerationService.GeneratedReceipt {
        let user = try req.auth.require(User.self)
        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }
        
        guard let expenseID = req.parameters.get("expenseID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid expense ID")
        }
        
        guard let expense = try await Expense.find(expenseID, on: req.db) else {
            throw Abort(.notFound, reason: "Expense not found")
        }
        
        // Verify ownership
        guard expense.$user.id == userID else {
            throw Abort(.forbidden, reason: "Access denied")
        }
        
        // Generate Receipt
        let generated = try ReceiptGenerationService.generate(for: expense)
        
        // Save HTML to file
        let fileName = "\(UUID().uuidString).html"
        let directory = req.application.directory.publicDirectory + "receipts/"
        
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let filePath = directory + fileName
        
        try generated.html.write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
        
        // Update Expense
        expense.receiptURL = "/receipts/\(fileName)"
        try await expense.save(on: req.db)
        
        return generated
    }
    
    // MARK: - View Generated Receipt (Web View)
    func viewGeneratedReceipt(req: Request) async throws -> Response {
        let user = try req.auth.require(User.self)
        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }
        
        guard let expenseID = req.parameters.get("expenseID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid expense ID")
        }
        
        guard let expense = try await Expense.find(expenseID, on: req.db) else {
            throw Abort(.notFound, reason: "Expense not found")
        }
        
        guard expense.$user.id == userID else {
            throw Abort(.forbidden, reason: "Access denied")
        }
        
        guard let receiptURL = expense.receiptURL else {
            throw Abort(.notFound, reason: "No receipt found")
        }
        
        if receiptURL.hasSuffix(".html") {
            let directory = req.application.directory.publicDirectory
            let relativePath = String(receiptURL.dropFirst())
            let fullPath = directory + relativePath
            return try await req.fileio.asyncStreamFile(at: fullPath)
        } else {
            // Redirect to image handler if it's an image
            return req.redirect(to: "/api/v1/receipts/\(expenseID)/image")
        }
    }

    // MARK: - Helper: Save Receipt Image
    private func saveReceiptImage(_ imageData: Data, on req: Request) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let directory = req.application.directory.publicDirectory + "receipts/"
        
        // Create directory if doesn't exist
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )
        
        let filePath = directory + fileName
        try imageData.write(to: URL(fileURLWithPath: filePath))
        
        return "/receipts/\(fileName)"
    }
}

// MARK: - Scan Receipt Response
struct ScanReceiptResponse: Content {
    let merchantName: String?
    let amount: Double?
    let date: Date?
    let suggestedCategory: String?
    let items: [ReceiptOCRService.ReceiptItem]?
    let confidence: Double
    let needsReview: Bool
    
    enum CodingKeys: String, CodingKey {
        case merchantName = "merchant_name"
        case amount
        case date
        case suggestedCategory = "suggested_category"
        case items
        case confidence
        case needsReview = "needs_review"
    }
}
