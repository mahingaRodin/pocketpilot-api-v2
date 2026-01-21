import Vapor

struct NotificationResponse: Content {
    let id: UUID
    let type: String
    let title: String
    let message: String
    let data: NotificationData?
    let priority: String
    let isRead: Bool
    let readAt: Date?
    let actionURL: String?
    let category: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, message, data, priority, category
        case isRead = "is_read"
        case readAt = "read_at"
        case actionURL = "action_url"
        case createdAt = "created_at"
    }
    
    init(from notification: Notification) throws {
        guard let id = notification.id,
              let createdAt = notification.createdAt else {
            throw Abort(.internalServerError)
        }
        
        self.id = id
        self.type = notification.type.rawValue
        self.title = notification.title
        self.message = notification.message
        self.data = notification.data
        self.priority = notification.priority.rawValue
        self.isRead = notification.isRead
        self.readAt = notification.readAt
        self.actionURL = notification.actionURL
        self.category = notification.category
        self.createdAt = createdAt
    }
}

struct NotificationPreferencesResponse: Content {
    let budgetAlertsEnabled: Bool
    let dailySummaryEnabled: Bool
    let weeklySummaryEnabled: Bool
    let unusualSpendingEnabled: Bool
    let billRemindersEnabled: Bool
    let quietHoursStart: Int?
    let quietHoursEnd: Int?
    let pushEnabled: Bool
    let emailEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case budgetAlertsEnabled = "budget_alerts_enabled"
        case dailySummaryEnabled = "daily_summary_enabled"
        case weeklySummaryEnabled = "weekly_summary_enabled"
        case unusualSpendingEnabled = "unusual_spending_enabled"
        case billRemindersEnabled = "bill_reminders_enabled"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case pushEnabled = "push_enabled"
        case emailEnabled = "email_enabled"
    }
    
    init(preferences: UserNotificationPreferences) {
        self.budgetAlertsEnabled = preferences.budgetAlertsEnabled
        self.dailySummaryEnabled = preferences.dailySummaryEnabled
        self.weeklySummaryEnabled = preferences.weeklySummaryEnabled
        self.unusualSpendingEnabled = preferences.unusualSpendingEnabled
        self.billRemindersEnabled = preferences.billRemindersEnabled
        self.quietHoursStart = preferences.quietHoursStart
        self.quietHoursEnd = preferences.quietHoursEnd
        self.pushEnabled = preferences.pushEnabled
        self.emailEnabled = preferences.emailEnabled
    }
}

struct UpdateNotificationPreferencesRequest: Content {
    let budgetAlertsEnabled: Bool?
    let dailySummaryEnabled: Bool?
    let weeklySummaryEnabled: Bool?
    let unusualSpendingEnabled: Bool?
    let billRemindersEnabled: Bool?
    let quietHoursStart: Int?
    let quietHoursEnd: Int?
    let pushEnabled: Bool?
    let emailEnabled: Bool?
    
    enum CodingKeys: String, CodingKey {
        case budgetAlertsEnabled = "budget_alerts_enabled"
        case dailySummaryEnabled = "daily_summary_enabled"
        case weeklySummaryEnabled = "weekly_summary_enabled"
        case unusualSpendingEnabled = "unusual_spending_enabled"
        case billRemindersEnabled = "bill_reminders_enabled"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case pushEnabled = "push_enabled"
        case emailEnabled = "email_enabled"
    }
}

struct RegisterPushTokenRequest: Content {
    let pushToken: String
    
    enum CodingKeys: String, CodingKey {
        case pushToken = "push_token"
    }
}

struct UnreadCountResponse: Content {
    let count: Int
}

struct NotificationListResponse: Content {
    let notifications: [NotificationResponse]
    let total: Int
    let page: Int
    let perPage: Int
}
