import Vapor
import Fluent

struct ExpenseController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let expenses = routes.grouped("expenses")
        let protected = expenses.grouped(JWTAuthenticator())
        
        protected.get(use: index)
        protected.post(use: create)
        protected.get(":expenseID", use: show)
        protected.put(":expenseID", use: update)
        protected.delete(":expenseID", use: delete)
        protected.get("categories", use: getCategories)
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
        
        try CreateExpenseRequest.validate(content: req)
        let createRequest = try req.content.decode(CreateExpenseRequest.self)
        
        let expense = Expense(
            userID: user.id!,
            amount: createRequest.amount,
            description: createRequest.description,
            category: createRequest.category,
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
        
        // Update fields if provided
        if let amount = updateRequest.amount {
            expense.amount = amount
        }
        
        if let description = updateRequest.description {
            expense.description = description
        }
        
        if let category = updateRequest.category {
            expense.category = category
        }
        
        if let date = updateRequest.date {
            expense.date = date
        }
        
        if let notes = updateRequest.notes {
            expense.notes = notes
        }
        
        try await expense.save(on: req.db)
        
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