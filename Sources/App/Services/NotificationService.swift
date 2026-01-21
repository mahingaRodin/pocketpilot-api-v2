import Vapor
import Fluent

struct NotificationService {
    
    // MARK: - Create Notification
    static func createNotification(
        for userID: UUID,
        type: NotificationType,
        title: String,
        message: String,
        data: NotificationData? = nil,
        priority: NotificationPriority = .normal,
        category: String,
        actionURL: String? = nil,
        scheduledFor: Date? = nil,
        on req: Request
    ) async throws -> Notification {
        
        // Check user preferences
        let preferences = try await getUserPreferences(userID: userID, on: req)
        
        guard shouldSendNotification(type: type, preferences: preferences) else {
            throw Abort(.badRequest, reason: "Notification type disabled in user preferences")
        }
        
        // Check quiet hours
        if isInQuietHours(preferences: preferences) && priority != .urgent {
            // Schedule for after quiet hours
            let scheduledTime = calculateNextAvailableTime(preferences: preferences)
            let notification = Notification(
                userID: userID,
                type: type,
                title: title,
                message: message,
                data: data,
                priority: priority,
                actionURL: actionURL,
                category: category,
                scheduledFor: scheduledFor ?? scheduledTime
            )
            try await notification.save(on: req.db)
            return notification
        }
        
        let notification = Notification(
            userID: userID,
            type: type,
            title: title,
            message: message,
            data: data,
            priority: priority,
            actionURL: actionURL,
            category: category,
            scheduledFor: scheduledFor
        )
        
        try await notification.save(on: req.db)
        
        // Send push notification if enabled
        if preferences.pushEnabled, let pushToken = preferences.pushToken {
            try await sendPushNotification(
                token: pushToken,
                notification: notification,
                on: req
            )
        }
        
        return notification
    }
    
    // MARK: - Smart Notification Triggers
    
    static func triggerBudgetAlert(
        userID: UUID,
        budgetStatus: BudgetStatusResponse,
        on req: Request
    ) async throws {
        
        let (title, message, priority) = generateBudgetAlertContent(status: budgetStatus)
        
        let data = NotificationData(
            budgetID: budgetStatus.budget.id.uuidString,
            amount: budgetStatus.spent,
            category: budgetStatus.budget.category,
            percentage: budgetStatus.percentage
        )
        
        _ = try await createNotification(
            for: userID,
            type: .budgetAlert,
            title: title,
            message: message,
            data: data,
            priority: priority,
            category: budgetStatus.budget.category,
            actionURL: "/budgets/\(budgetStatus.budget.id)",
            on: req
        )
    }
    
    static func triggerDailySummary(
        userID: UUID,
        totalSpent: Double,
        expenseCount: Int,
        topCategory: String,
        on req: Request
    ) async throws {
        
        let title = "Daily Summary"
        let message = "Today you spent $\(String(format: "%.2f", totalSpent)) across \(expenseCount) expenses. Top category: \(topCategory)"
        
        let data = NotificationData(
            amount: totalSpent,
            category: topCategory,
            metadata: ["expense_count": String(expenseCount)]
        )
        
        _ = try await createNotification(
            for: userID,
            type: .dailySummary,
            title: title,
            message: message,
            data: data,
            priority: .normal,
            category: "summary",
            on: req
        )
    }
    
    static func triggerUnusualSpending(
        userID: UUID,
        category: String,
        currentAmount: Double,
        averageAmount: Double,
        percentage: Double,
        on req: Request
    ) async throws {
        
        let title = "Unusual Spending Detected"
        let message = "Your \(category) spending is \(Int(percentage))% higher than usual. $\(String(format: "%.2f", currentAmount)) vs avg $\(String(format: "%.2f", averageAmount))"
        
        let data = NotificationData(
            amount: currentAmount,
            category: category,
            percentage: percentage,
            metadata: ["average_amount": String(averageAmount)]
        )
        
        _ = try await createNotification(
            for: userID,
            type: .unusualSpending,
            title: title,
            message: message,
            data: data,
            priority: .high,
            category: category,
            on: req
        )
    }
    
    // MARK: - Helper Functions
    
    static func getUserPreferences(userID: UUID, on req: Request) async throws -> UserNotificationPreferences {
        if let preferences = try await UserNotificationPreferences.query(on: req.db)
            .filter(\.$user.$id == userID)
            .first() {
            return preferences
        }
        
        // Create default preferences
        let newPreferences = UserNotificationPreferences(userID: userID)
        try await newPreferences.save(on: req.db)
        return newPreferences
    }
    
    private static func shouldSendNotification(
        type: NotificationType,
        preferences: UserNotificationPreferences
    ) -> Bool {
        switch type {
        case .budgetAlert:
            return preferences.budgetAlertsEnabled
        case .dailySummary:
            return preferences.dailySummaryEnabled
        case .weeklySummary:
            return preferences.weeklySummaryEnabled
        case .unusualSpending:
            return preferences.unusualSpendingEnabled
        case .billReminder:
            return preferences.billRemindersEnabled
        default:
            return true
        }
    }
    
    private static func isInQuietHours(preferences: UserNotificationPreferences) -> Bool {
        guard let start = preferences.quietHoursStart,
              let end = preferences.quietHoursEnd else {
            return false
        }
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        
        if start < end {
            return currentHour >= start && currentHour < end
        } else {
            return currentHour >= start || currentHour < end
        }
    }
    
    private static func calculateNextAvailableTime(preferences: UserNotificationPreferences) -> Date {
        guard let end = preferences.quietHoursEnd else {
            return Date()
        }
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = end
        components.minute = 0
        
        if let scheduledDate = calendar.date(from: components), scheduledDate > Date() {
            return scheduledDate
        } else {
            // Next day
            return calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components)!) ?? Date()
        }
    }
    
    private static func generateBudgetAlertContent(
        status: BudgetStatusResponse
    ) -> (title: String, message: String, priority: NotificationPriority) {
        
        switch status.status {
        case .approaching:
            return (
                "Budget Alert",
                "You've spent \(Int(status.percentage))% of your \(status.budget.categoryDisplay) budget ($\(String(format: "%.2f", status.remaining)) remaining)",
                .normal
            )
        case .warning:
            return (
                "Budget Warning!",
                "⚠️ You've spent \(Int(status.percentage))% of your \(status.budget.categoryDisplay) budget! Only $\(String(format: "%.2f", status.remaining)) left.",
                .high
            )
        case .exceeded:
            return (
                "Budget Exceeded!",
                "🚨 You've exceeded your \(status.budget.categoryDisplay) budget by $\(String(format: "%.2f", abs(status.remaining))).",
                .urgent
            )
        case .onTrack:
            return (
                "Budget Update",
                "Your \(status.budget.categoryDisplay) budget status has changed.",
                .normal
            )
        }
    }
    
    private static func sendPushNotification(
        token: String,
        notification: Notification,
        on req: Request
    ) async throws {
        // Integrate with APNs (Apple Push Notification service)
        // This is a placeholder - implement with APNs library
        req.logger.info("Would send push notification to token: \(token)")
        req.logger.info("Title: \(notification.title)")
        req.logger.info("Message: \(notification.message)")
    }
}
