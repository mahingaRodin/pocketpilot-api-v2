import Vapor

// Create Budget Request
struct CreateBudgetRequest: Content {
    let category: String
    let amount: Double
    let period: String
    let startDate: Date?
    let alertThreshold: Double?
    
    func validate() throws {
        guard amount > 0 else {
            throw Abort(.badRequest, reason: "Budget amount must be greater than 0")
        }
        
        guard let _ = BudgetPeriod(rawValue: period) else {
            throw Abort(.badRequest, reason: "Invalid period. Use: daily, weekly, monthly, yearly")
        }
        
        if let threshold = alertThreshold {
            guard threshold > 0 && threshold <= 100 else {
                throw Abort(.badRequest, reason: "Alert threshold must be between 1-100")
            }
        }
    }
}

// Update Budget Request
struct UpdateBudgetRequest: Content {
    let amount: Double?
    let alertThreshold: Double?
    let isActive: Bool?
}

// Budget Status Response
struct BudgetStatusResponse: Content {
    let budget: BudgetResponse
    let spent: Double
    let remaining: Double
    let percentage: Double
    let status: BudgetStatus
    let daysRemaining: Int
    let averageDaily: Double
    let projectedTotal: Double
    let onTrack: Bool
}

struct BudgetResponse: Content {
    let id: UUID
    let category: String
    let categoryDisplay: String
    let categoryIcon: String
    let amount: Double
    let period: String
    let startDate: Date
    let endDate: Date?
    let alertThreshold: Double
    let isActive: Bool
    
    init(budget: Budget) {
        self.id = budget.id!
        self.category = budget.category.rawValue
        self.categoryDisplay = budget.category.displayName
        self.categoryIcon = budget.category.icon
        self.amount = budget.amount
        self.period = budget.period.rawValue
        self.startDate = budget.startDate
        self.endDate = budget.endDate
        self.alertThreshold = budget.alertThreshold
        self.isActive = budget.isActive
    }
}

enum BudgetStatus: String, Codable {
    case onTrack = "on_track"
    case approaching = "approaching"
    case warning = "warning"
    case exceeded = "exceeded"
}

// Budget Summary Response
struct BudgetSummaryResponse: Content {
    let totalBudget: Double
    let totalSpent: Double
    let totalRemaining: Double
    let overallPercentage: Double
    let budgets: [BudgetStatusResponse]
    let alerts: [BudgetAlertResponse]
}

struct BudgetAlertResponse: Content {
    let id: UUID
    let budgetId: UUID
    let alertType: String
    let thresholdPercentage: Double
    let triggeredAt: Date
    let isRead: Bool
    let message: String?
    
    init(alert: BudgetAlert) {
        self.id = alert.id!
        self.budgetId = alert.$budget.id
        self.alertType = alert.alertType.rawValue
        self.thresholdPercentage = alert.thresholdPercentage
        self.triggeredAt = alert.triggeredAt
        self.isRead = alert.isRead
        self.message = alert.message
    }
}
