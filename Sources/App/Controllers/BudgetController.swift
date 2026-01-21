import Vapor
import Fluent

struct BudgetController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let budgets = routes.grouped("budgets")
            .grouped(JWTAuthenticator())
        
        budgets.get(use: index)
        budgets.post(use: create)
        budgets.get(":budgetID", use: show)
        budgets.put(":budgetID", use: update)
        budgets.delete(":budgetID", use: delete)
        
        budgets.get("status", use: getAllStatus)
        budgets.get(":budgetID", "status", use: getBudgetStatus)
        budgets.get("summary", use: getSummary)
        budgets.get("alerts", use: getAlerts)
        budgets.put("alerts", ":alertID", "read", use: markAlertRead)
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
        
        guard let category = ExpenseCategory(rawValue: createRequest.category) else {
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
