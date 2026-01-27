import Vapor
import Fluent
import VaporToOpenAPI

struct BudgetController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let budgets = routes.grouped("budgets")
            .grouped(JWTAuthenticator())
        
        budgets.get(use: index)
            .openAPI(
                summary: "List all budgets",
                description: "Retrieves a list of all active budgets for the user.",
                response: .type([BudgetResponse].self),
                auth: .bearer()
            )
            
        budgets.post(use: create)
            .openAPI(
                summary: "Create budget",
                description: "Creates a new budget for a category.",
                body: .type(CreateBudgetRequest.self),
                response: .type(BudgetResponse.self),
                auth: .bearer()
            )
            
        budgets.get(":budgetID", use: show)
            .openAPI(
                summary: "Get budget details",
                description: "Retrieves details of a specific budget.",
                response: .type(BudgetResponse.self),
                auth: .bearer()
            )
            
        budgets.put(":budgetID", use: update)
            .openAPI(
                summary: "Update budget",
                description: "Updates a budget's amount or status.",
                body: .type(UpdateBudgetRequest.self),
                response: .type(BudgetResponse.self),
                auth: .bearer()
            )
            
        budgets.delete(":budgetID", use: delete)
            .openAPI(
                summary: "Delete budget",
                description: "Deletes a specific budget.",
                auth: .bearer()
            )
        
        budgets.get("status", use: getAllStatus)
            .openAPI(
                summary: "Get all budget limits",
                description: "Retrieves the current spending status against all budgets.",
                response: .type([BudgetStatusResponse].self),
                auth: .bearer()
            )
            
        budgets.get(":budgetID", "status", use: getBudgetStatus)
            .openAPI(
                summary: "Get budget status",
                description: "Retrieves the current spending status for a specific budget.",
                response: .type(BudgetStatusResponse.self),
                auth: .bearer()
            )
            
        budgets.get("summary", use: getSummary)
            .openAPI(
                summary: "Get budget summary",
                description: "Retrieves a high-level summary of all budgets and alerts.",
                response: .type(BudgetSummaryResponse.self),
                auth: .bearer()
            )
            
        budgets.get("alerts", use: getAlerts)
            .openAPI(
                summary: "List budget alerts",
                description: "Retrieves a list of all triggered budget alerts.",
                response: .type([BudgetAlertResponse].self),
                auth: .bearer()
            )
            
        budgets.put("alerts", ":alertID", "read", use: markAlertRead)
            .openAPI(
                summary: "Mark alert as read",
                description: "Marks a specific budget alert as read.",
                auth: .bearer()
            )
    }
    
    // MARK: - List All Budgets
    func index(req: Request) async throws -> [BudgetResponse] {
        let user = try req.auth.require(User.self)
        
        let budgets = try await Budget.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$isActive == true)
            .all()
        
        return budgets.map { BudgetResponse(budget: $0) }
    }
    
    // MARK: - Create Budget
    func create(req: Request) async throws -> BudgetResponse {
        let user = try req.auth.require(User.self)
        
        let createRequest = try req.content.decode(CreateBudgetRequest.self)
        try createRequest.validate()
        
        guard let category = ExpenseCategory.from(createRequest.category) else {
            throw Abort(.badRequest, reason: "Invalid category: \(createRequest.category)")
        }
        
        guard let period = BudgetPeriod(rawValue: createRequest.period) else {
            throw Abort(.badRequest, reason: "Invalid period")
        }
        
        let budget = Budget(
            userID: user.id!,
            category: category,
            amount: createRequest.amount,
            period: period,
            startDate: createRequest.startDate ?? Date(),
            alertThreshold: createRequest.alertThreshold ?? 80.0
        )
        
        try await budget.save(on: req.db)
        
        return BudgetResponse(budget: budget)
    }
    
    // MARK: - Get Budget Status
    func getBudgetStatus(req: Request) async throws -> BudgetStatusResponse {
        let user = try req.auth.require(User.self)
        
        guard let budgetID = req.parameters.get("budgetID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid budget ID")
        }
        
        guard let budget = try await Budget.find(budgetID, on: req.db) else {
            throw Abort(.notFound, reason: "Budget not found")
        }
        
        guard budget.$user.id == user.id! else {
            throw Abort(.forbidden)
        }
        
        // Get expenses for this category in the budget period
        let expenses = try await Expense.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$category == budget.category)
            .filter(\.$date >= budget.startDate)
            .all()
        
        let status = try await BudgetService.calculateBudgetStatus(
            budget: budget,
            expenses: expenses,
            on: req
        )
        
        // Check and create alerts
        try await BudgetService.checkAndCreateAlerts(budget: budget, status: status, on: req)
        
        return status
    }
    
    // MARK: - Get All Budget Status
    func getAllStatus(req: Request) async throws -> [BudgetStatusResponse] {
        let user = try req.auth.require(User.self)
        
        let budgets = try await Budget.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$isActive == true)
            .all()
        
        var statuses: [BudgetStatusResponse] = []
        
        for budget in budgets {
            let expenses = try await Expense.query(on: req.db)
                .filter(\.$user.$id == user.id!)
                .filter(\.$category == budget.category)
                .filter(\.$date >= budget.startDate)
                .all()
            
            let status = try await BudgetService.calculateBudgetStatus(
                budget: budget,
                expenses: expenses,
                on: req
            )
            
            try await BudgetService.checkAndCreateAlerts(budget: budget, status: status, on: req)
            statuses.append(status)
        }
        
        return statuses
    }
    
    // MARK: - Get Budget Summary
    func getSummary(req: Request) async throws -> BudgetSummaryResponse {
        let user = try req.auth.require(User.self)
        
        let budgets = try await Budget.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$isActive == true)
            .all()
        
        var statuses: [BudgetStatusResponse] = []
        var totalBudgetAmount: Double = 0
        var totalSpentAmount: Double = 0
        
        for budget in budgets {
            let expenses = try await Expense.query(on: req.db)
                .filter(\.$user.$id == user.id!)
                .filter(\.$category == budget.category)
                .filter(\.$date >= budget.startDate)
                .all()
            
            let status = try await BudgetService.calculateBudgetStatus(
                budget: budget,
                expenses: expenses,
                on: req
            )
            
            // Check and create alerts if needed
            try? await BudgetService.checkAndCreateAlerts(budget: budget, status: status, on: req)
            
            statuses.append(status)
            totalBudgetAmount += budget.amount
            totalSpentAmount += status.spent
        }
        
        // Get unread alerts
        let alerts = try await BudgetAlert.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$isRead == false)
            .sort(\.$triggeredAt, .descending)
            .limit(10)
            .all()
        
        let alertResponses = alerts.map { BudgetAlertResponse(alert: $0) }
        
        return BudgetSummaryResponse(
            totalBudget: totalBudgetAmount,
            totalSpent: totalSpentAmount,
            totalRemaining: totalBudgetAmount - totalSpentAmount,
            overallPercentage: totalBudgetAmount > 0 ? (totalSpentAmount / totalBudgetAmount) * 100 : 0,
            budgets: statuses,
            alerts: alertResponses
        )
    }
    
    // MARK: - Get Alerts
    func getAlerts(req: Request) async throws -> [BudgetAlertResponse] {
        let user = try req.auth.require(User.self)
        
        let alerts = try await BudgetAlert.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .sort(\.$triggeredAt, .descending)
            .all()
        
        return alerts.map { BudgetAlertResponse(alert: $0) }
    }
    
    // MARK: - Mark Alert as Read
    func markAlertRead(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        guard let alertID = req.parameters.get("alertID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let alert = try await BudgetAlert.find(alertID, on: req.db) else {
            throw Abort(.notFound)
        }
        
        guard alert.$user.id == user.id! else {
            throw Abort(.forbidden)
        }
        
        alert.isRead = true
        try await alert.save(on: req.db)
        
        return .ok
    }
    
    // MARK: - Show Budget
    func show(req: Request) async throws -> BudgetResponse {
        let user = try req.auth.require(User.self)
        
        guard let budgetID = req.parameters.get("budgetID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let budget = try await Budget.find(budgetID, on: req.db) else {
            throw Abort(.notFound)
        }
        
        guard budget.$user.id == user.id! else {
            throw Abort(.forbidden)
        }
        
        return BudgetResponse(budget: budget)
    }
    
    // MARK: - Update Budget
    func update(req: Request) async throws -> BudgetResponse {
        let user = try req.auth.require(User.self)
        
        guard let budgetID = req.parameters.get("budgetID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let budget = try await Budget.find(budgetID, on: req.db) else {
            throw Abort(.notFound)
        }
        
        guard budget.$user.id == user.id! else {
            throw Abort(.forbidden)
        }
        
        let updateRequest = try req.content.decode(UpdateBudgetRequest.self)
        
        if let amount = updateRequest.amount {
            budget.amount = amount
        }
        
        if let threshold = updateRequest.alertThreshold {
            budget.alertThreshold = threshold
        }
        
        if let isActive = updateRequest.isActive {
            budget.isActive = isActive
        }
        
        try await budget.save(on: req.db)
        
        return BudgetResponse(budget: budget)
    }
    
    // MARK: - Delete Budget
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        guard let budgetID = req.parameters.get("budgetID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let budget = try await Budget.find(budgetID, on: req.db) else {
            throw Abort(.notFound)
        }
        
        guard budget.$user.id == user.id! else {
            throw Abort(.forbidden)
        }
        
        try await budget.delete(on: req.db)
        
        return .noContent
    }
}
