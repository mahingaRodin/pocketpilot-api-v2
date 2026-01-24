import Vapor
import Fluent
import VaporToOpenAPI

struct ExpenseController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let expenses = routes.grouped("expenses")
        let protected = expenses.grouped(JWTAuthenticator())
        
        protected.get(use: index)
            .openAPI(
                summary: "List expenses",
                description: "Retrieves a paginated list of expenses.",
                query: .type(ExpenseQueryParams.self),
                response: .type(ExpenseListResponse.self),
                auth: .bearer()
            )
            
        protected.post(use: create)
            .openAPI(
                summary: "Create expense",
                description: "Creates a new expense record.",
                body: .type(CreateExpenseRequest.self),
                response: .type(ExpenseResponse.self),
                auth: .bearer()
            )
            
        protected.get(":expenseID", use: show)
            .openAPI(
                summary: "Get expense details",
                description: "Retrieves details of a specific expense.",
                response: .type(ExpenseResponse.self),
                auth: .bearer()
            )
            
        protected.put(":expenseID", use: update)
            .openAPI(
                summary: "Update expense",
                description: "Updates an existing expense record.",
                body: .type(UpdateExpenseRequest.self),
                response: .type(ExpenseResponse.self),
                auth: .bearer()
            )
            
        protected.delete(":expenseID", use: delete)
            .openAPI(
                summary: "Delete expense",
                description: "Deletes a specific expense record.",
                auth: .bearer()
            )
            
        protected.get("categories", use: getCategories)
            .openAPI(
                summary: "List categories",
                description: "Retrieves all available expense categories.",
                response: .type([CategoryResponse].self),
                auth: .bearer()
            )
    }
    
    func index(req: Request) async throws -> ExpenseListResponse {
        let user = try req.auth.require(User.self)
        let queryParams = try req.query.decode(ExpenseQueryParams.self)
        
        let page = queryParams.page ?? 1
        let perPage = min(queryParams.perPage ?? 20, 100) // Max 100 items per page
        
        var query = Expense.query(on: req.db)
            .filter(\.$user.$id == user.id!)
        
        // Apply filters
        if let category = queryParams.category {
            query = query.filter(\.$category == category)
        }
        
        if let startDate = queryParams.startDate {
            query = query.filter(\.$date >= startDate)
        }
        
        if let endDate = queryParams.endDate {
            query = query.filter(\.$date <= endDate)
        }
        
        // Apply sorting
        let sortBy = queryParams.sortBy ?? "date"
        let sortOrder = queryParams.sortOrder ?? "desc"
        
        switch sortBy {
        case "amount":
            if sortOrder == "asc" {
                query = query.sort(\.$amount, .ascending)
            } else {
                query = query.sort(\.$amount, .descending)
            }
        case "description":
            if sortOrder == "asc" {
                query = query.sort(\.$description, .ascending)
            } else {
                query = query.sort(\.$description, .descending)
            }
        default: // date
            if sortOrder == "asc" {
                query = query.sort(\.$date, .ascending)
            } else {
                query = query.sort(\.$date, .descending)
            }
        }
        
        // Get total count
        let total = try await query.count()
        
        // Get paginated results
        let expenses = try await query
            .offset((page - 1) * perPage)
            .limit(perPage)
            .all()
        
        // Calculate total amount for current filter
        let totalAmount = try await Expense.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .sum(\.$amount) ?? 0.0
        
        return ExpenseListResponse(
            expenses: expenses.map(ExpenseResponse.init),
            total: total,
            page: page,
            perPage: perPage,
            totalAmount: totalAmount
        )
    }
    
    func create(req: Request) async throws -> ExpenseResponse {
        let user = try req.auth.require(User.self)
        
        let createRequest = try req.content.decode(CreateExpenseRequest.self)
        
        // Manual validation checks
        guard createRequest.amount >= 0.01 else {
            throw Abort(.badRequest, reason: "Amount must be at least 0.01")
        }
        
        guard !createRequest.description.isEmpty && createRequest.description.count <= 255 else {
            throw Abort(.badRequest, reason: "Description must be between 1 and 255 characters")
        }
        
        if let notes = createRequest.notes, notes.count > 500 {
            throw Abort(.badRequest, reason: "Notes must be at most 500 characters")
        }
        
        guard let category = ExpenseCategory.from(createRequest.category) else {
            throw Abort(.badRequest, reason: "Invalid expense category: \(createRequest.category)")
        }
        
        let expense = Expense(
            userID: user.id!,
            amount: createRequest.amount,
            description: createRequest.description,
            category: category,
            date: createRequest.date,
            notes: createRequest.notes
        )
        
        try await expense.save(on: req.db)
        
        return ExpenseResponse(expense: expense)
    }
    
    func show(req: Request) async throws -> ExpenseResponse {
        let user = try req.auth.require(User.self)
        
        guard let expenseID = req.parameters.get("expenseID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid expense ID")
        }
        
        guard let expense = try await Expense.query(on: req.db)
            .filter(\.$id == expenseID)
            .filter(\.$user.$id == user.id!)
            .first() else {
            throw Abort(.notFound, reason: "Expense not found")
        }
        
        return ExpenseResponse(expense: expense)
    }
    
    func update(req: Request) async throws -> ExpenseResponse {
        let user = try req.auth.require(User.self)
        
        guard let expenseID = req.parameters.get("expenseID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid expense ID")
        }
        
        guard let expense = try await Expense.query(on: req.db)
            .filter(\.$id == expenseID)
            .filter(\.$user.$id == user.id!)
            .first() else {
            throw Abort(.notFound, reason: "Expense not found")
        }
        
        try UpdateExpenseRequest.validate(content: req)
        let updateRequest = try req.content.decode(UpdateExpenseRequest.self)
        
        // Track if we need to regenerate receipt
        var shouldRegenerateReceipt = false
        
        // Update fields if provided
        if let amount = updateRequest.amount {
            expense.amount = amount
            shouldRegenerateReceipt = true
        }
        
        if let description = updateRequest.description {
            expense.description = description
            shouldRegenerateReceipt = true
        }
        
        if let categoryString = updateRequest.category {
            // Parse category from string (supports both rawValue and displayName)
            guard let category = ExpenseCategory.from(categoryString) else {
                throw Abort(.badRequest, reason: "Invalid category: '\(categoryString)'. Use rawValue (e.g., 'food') or displayName (e.g., 'Food & Dining')")
            }
            expense.category = category
            shouldRegenerateReceipt = true
        }
        
        if let date = updateRequest.date {
            expense.date = date
            shouldRegenerateReceipt = true
        }
        
        if let notes = updateRequest.notes {
            expense.notes = notes
            shouldRegenerateReceipt = true
        }
        
        try await expense.save(on: req.db)
        
        // Regenerate receipt if expense data changed
        if shouldRegenerateReceipt {
            // Delete old receipt file if it exists
            if let oldReceiptURL = expense.receiptURL {
                let directory = req.application.directory.publicDirectory
                let relativePath = String(oldReceiptURL.dropFirst()) // Remove leading /
                let fullPath = directory + relativePath
                
                // Try to delete old receipt file (ignore errors if file doesn't exist)
                try? FileManager.default.removeItem(atPath: fullPath)
            }
            
            // Generate new receipt
            let generated = try ReceiptGenerationService.generate(for: expense)
            
            // Save HTML to file
            let fileName = "\(UUID().uuidString).html"
            let receiptsDirectory = req.application.directory.publicDirectory + "receipts/"
            
            try FileManager.default.createDirectory(
                atPath: receiptsDirectory,
                withIntermediateDirectories: true
            )
            
            let filePath = receiptsDirectory + fileName
            try generated.html.write(
                to: URL(fileURLWithPath: filePath),
                atomically: true,
                encoding: .utf8
            )
            
            // Update expense with new receipt URL
            expense.receiptURL = "/receipts/\(fileName)"
            try await expense.save(on: req.db)
        }
        
        return ExpenseResponse(expense: expense)
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        guard let expenseID = req.parameters.get("expenseID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid expense ID")
        }
        
        guard let expense = try await Expense.query(on: req.db)
            .filter(\.$id == expenseID)
            .filter(\.$user.$id == user.id!)
            .first() else {
            throw Abort(.notFound, reason: "Expense not found")
        }
        
        try await expense.delete(on: req.db)
        
        return .noContent
    }
    
    func getCategories(req: Request) async throws -> [CategoryResponse] {
        return ExpenseCategory.allCases.map(CategoryResponse.init)
    }
}