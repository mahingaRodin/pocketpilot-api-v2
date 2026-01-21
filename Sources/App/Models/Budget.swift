import Fluent
import Vapor

final class Budget: Model, Content, @unchecked Sendable {
    static let schema = "budgets"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "category")
    var category: ExpenseCategory
    
    @Field(key: "amount")
    var amount: Double
    
    @Field(key: "period")
    var period: BudgetPeriod
    
    @Field(key: "start_date")
    var startDate: Date
    
    @OptionalField(key: "end_date")
    var endDate: Date?
    
    @Field(key: "alert_threshold")
    var alertThreshold: Double // Percentage (e.g., 80 for 80%)
    
    @Field(key: "is_active")
    var isActive: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        userID: User.IDValue,
        category: ExpenseCategory,
        amount: Double,
        period: BudgetPeriod,
        startDate: Date,
        alertThreshold: Double = 80.0
    ) {
        self.id = id
        self.$user.id = userID
        self.category = category
        self.amount = amount
        self.period = period
        self.startDate = startDate
        self.alertThreshold = alertThreshold
        self.isActive = true
    }
}

enum BudgetPeriod: String, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
}

// MARK: - Budget Alert Model
final class BudgetAlert: Model, Content, @unchecked Sendable {
    static let schema = "budget_alerts"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "budget_id")
    var budget: Budget
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "alert_type")
    var alertType: AlertType
    
    @Field(key: "threshold_percentage")
    var thresholdPercentage: Double
    
    @Field(key: "triggered_at")
    var triggeredAt: Date
    
    @Field(key: "is_read")
    var isRead: Bool
    
    @OptionalField(key: "message")
    var message: String?
    
    init() { }
}

enum AlertType: String, Codable {
    case approaching = "approaching" // 80%
    case warning = "warning"         // 90%
    case exceeded = "exceeded"       // 100%+
    case prediction = "prediction"   // Predicted to exceed
}
