import Fluent
import Vapor

final class Notification: Model, Content, @unchecked Sendable {
    static let schema = "notifications"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "type")
    var type: NotificationType
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "message")
    var message: String
    
    @OptionalField(key: "data")
    var data: NotificationData?
    
    @Field(key: "priority")
    var priority: NotificationPriority
    
    @Field(key: "is_read")
    var isRead: Bool
    
    @OptionalField(key: "read_at")
    var readAt: Date?
    
    @OptionalField(key: "action_url")
    var actionURL: String?
    
    @Field(key: "category")
    var category: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "scheduled_for", on: .none)
    var scheduledFor: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        userID: User.IDValue,
        type: NotificationType,
        title: String,
        message: String,
        data: NotificationData? = nil,
        priority: NotificationPriority = .normal,
        actionURL: String? = nil,
        category: String,
        scheduledFor: Date? = nil
    ) {
        self.id = id
        self.$user.id = userID
        self.type = type
        self.title = title
        self.message = message
        self.data = data
        self.priority = priority
        self.isRead = false
        self.actionURL = actionURL
        self.category = category
        self.scheduledFor = scheduledFor
    }
}

enum NotificationType: String, Codable {
    case budgetAlert = "budget_alert"
    case expenseAdded = "expense_added"
    case dailySummary = "daily_summary"
    case weeklySummary = "weekly_summary"
    case monthlySummary = "monthly_summary"
    case unusualSpending = "unusual_spending"
    case billReminder = "bill_reminder"
    case savingsGoal = "savings_goal"
    case receiptScanned = "receipt_scanned"
    case teamUpdate = "team_update"
}

enum NotificationPriority: String, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
}

struct NotificationData: Codable {
    var expenseID: String?
    var budgetID: String?
    var amount: Double?
    var category: String?
    var percentage: Double?
    var metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case expenseID = "expense_id"
        case budgetID = "budget_id"
        case amount
        case category
        case percentage
        case metadata
    }
}

// User Notification Preferences
final class UserNotificationPreferences: Model, Content, @unchecked Sendable {
    static let schema = "user_notification_preferences"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "budget_alerts_enabled")
    var budgetAlertsEnabled: Bool
    
    @Field(key: "daily_summary_enabled")
    var dailySummaryEnabled: Bool
    
    @Field(key: "weekly_summary_enabled")
    var weeklySummaryEnabled: Bool
    
    @Field(key: "unusual_spending_enabled")
    var unusualSpendingEnabled: Bool
    
    @Field(key: "bill_reminders_enabled")
    var billRemindersEnabled: Bool
    
    @Field(key: "quiet_hours_start")
    var quietHoursStart: Int? // Hour in 24h format (e.g., 22 for 10 PM)
    
    @Field(key: "quiet_hours_end")
    var quietHoursEnd: Int? // Hour in 24h format (e.g., 8 for 8 AM)
    
    @Field(key: "push_enabled")
    var pushEnabled: Bool
    
    @Field(key: "email_enabled")
    var emailEnabled: Bool
    
    @OptionalField(key: "push_token")
    var pushToken: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(userID: User.IDValue) {
        self.$user.id = userID
        self.budgetAlertsEnabled = true
        self.dailySummaryEnabled = true
        self.weeklySummaryEnabled = true
        self.unusualSpendingEnabled = true
        self.billRemindersEnabled = true
        self.pushEnabled = true
        self.emailEnabled = false
    }
}
