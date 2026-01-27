import Vapor
import Fluent

struct BudgetService {
    
    // MARK: - Calculate Budget Status
    static func calculateBudgetStatus(
        budget: Budget,
        expenses: [Expense],
        on req: Request
    ) async throws -> BudgetStatusResponse {
        
        let spent = expenses.reduce(0) { $0 + $1.amount }
        let remaining = budget.amount - spent
        let percentage = budget.amount > 0 ? (spent / budget.amount) * 100 : 0
        
        // Determine status
        let status: BudgetStatus
        if percentage >= 100 {
            status = .exceeded
        } else if percentage >= 90 {
            status = .warning
        } else if percentage >= budget.alertThreshold {
            status = .approaching
        } else {
            status = .onTrack
        }
        
        // Calculate days remaining in period
        let endDate = calculatePeriodEndDate(
            startDate: budget.startDate,
            period: budget.period
        )
        let now = Date()
        let calendar = Calendar.current
        let daysRemaining = calendar.dateComponents(
            [.day],
            from: now,
            to: endDate
        ).day ?? 0
        
        // Calculate average daily spending
        let daysSinceStart = calendar.dateComponents(
            [.day],
            from: budget.startDate,
            to: now
        ).day ?? 0
        let daysInPast = max(daysSinceStart, 1)
        let averageDaily = spent / Double(daysInPast)
        
        // Project total spending
        let totalDaysInPeriod = calendar.dateComponents(
            [.day],
            from: budget.startDate,
            to: endDate
        ).day ?? 30
        let projectedTotal = averageDaily * Double(max(totalDaysInPeriod, 1))
        
        // Check if on track
        let budgetFraction = Double(daysInPast) / Double(max(totalDaysInPeriod, 1))
        let expectedSpentFraction = budgetFraction * budget.amount
        let onTrack = spent <= expectedSpentFraction
        
        return BudgetStatusResponse(
            budget: BudgetResponse(budget: budget),
            spent: spent,
            remaining: remaining,
            percentage: percentage,
            status: status,
            daysRemaining: max(daysRemaining, 0),
            averageDaily: averageDaily,
            projectedTotal: projectedTotal,
            onTrack: onTrack
        )
    }
    
    // MARK: - Check and Create Alerts
    static func checkAndCreateAlerts(
        budget: Budget,
        status: BudgetStatusResponse,
        on req: Request
    ) async throws {
        
        let db = req.db
        
        // Only create alerts for specific statuses
        guard status.status != .onTrack else { return }
        
        let alertType = status.status.toAlertType()
        
        // Check if alert already exists for this threshold
        let existingAlert = try await BudgetAlert.query(on: db)
            .filter(\.$budget.$id == budget.id!)
            .filter(\.$alertType == alertType)
            .filter(\.$isRead == false)
            .first()
        
        if existingAlert == nil {
            // Create new alert
            let alert = BudgetAlert()
            alert.$budget.id = budget.id!
            alert.$user.id = budget.$user.id
            alert.alertType = alertType
            alert.thresholdPercentage = status.percentage
            alert.triggeredAt = Date()
            alert.isRead = false
            alert.message = generateAlertMessage(status: status, budget: budget)
            
            try await alert.save(on: db)
        }
    }
    
    private static func generateAlertMessage(status: BudgetStatusResponse, budget: Budget) -> String {
        switch status.status {
        case .approaching:
            return "You've spent \(String(format: "%.0f", status.percentage))% of your \(budget.category.displayName) budget. You have $\(String(format: "%.2f", status.remaining)) remaining."
        case .warning:
            return "⚠️ Warning: You've spent \(String(format: "%.0f", status.percentage))% of your \(budget.category.displayName) budget! Only $\(String(format: "%.2f", status.remaining)) left."
        case .exceeded:
            return "🚨 Budget exceeded! You've spent $\(String(format: "%.2f", status.spent)) on \(budget.category.displayName), which is $\(String(format: "%.2f", abs(status.remaining))) over budget."
        case .onTrack:
            return "✅ You're on track with your \(budget.category.displayName) budget!"
        }
    }
    
    private static func calculatePeriodEndDate(startDate: Date, period: BudgetPeriod) -> Date {
        let calendar = Calendar.current
        
        switch period {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        }
    }
    
    // MARK: - Refresh Budget Alerts
    static func refreshBudgetAlerts(for userID: UUID, category: ExpenseCategory, on req: Request) async throws {
        // Find active budget for this category
        guard let budget = try await Budget.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$category == category)
            .filter(\.$isActive == true)
            .first() else { return }
        
        // Get all expenses for this budget's category in the period
        let expenses = try await Expense.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$category == category)
            .filter(\.$date >= budget.startDate)
            .all()
        
        // Calculate status
        let status = try await calculateBudgetStatus(
            budget: budget,
            expenses: expenses,
            on: req
        )
        
        // Check and create alerts
        try await checkAndCreateAlerts(budget: budget, status: status, on: req)
    }
}

extension BudgetStatus {
    func toAlertType() -> AlertType {
        switch self {
        case .onTrack: return .approaching // Fallback, shouldn't be called if guarded
        case .approaching: return .approaching
        case .warning: return .warning
        case .exceeded: return .exceeded
        }
    }
}
