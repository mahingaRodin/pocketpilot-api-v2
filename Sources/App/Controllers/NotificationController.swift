import Vapor
import Fluent
import VaporToOpenAPI

struct NotificationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let notifications = routes.grouped("notifications")
            .grouped(JWTAuthenticator())
        
        notifications.get(use: index)
            .openAPI(
                summary: "List notifications",
                description: "Retrieves a paginated list of notifications.",
                response: .type(NotificationListResponse.self),
                auth: .bearer()
            )
            
        notifications.get("unread", use: getUnread)
            .openAPI(
                summary: "Get unread notifications",
                description: "Retrieves a list of recent unread notifications.",
                response: .type([NotificationResponse].self),
                auth: .bearer()
            )
            
        notifications.get("unread", "count", use: getUnreadCount)
            .openAPI(
                summary: "Get unread count",
                description: "Retrieves the total count of unread notifications.",
                response: .type(UnreadCountResponse.self),
                auth: .bearer()
            )
            
        notifications.put(":notificationID", "read", use: markAsRead)
            .openAPI(
                summary: "Mark as read",
                description: "Marks a specific notification as read.",
                response: .type(NotificationResponse.self),
                auth: .bearer()
            )
            
        notifications.put("read-all", use: markAllAsRead)
            .openAPI(
                summary: "Mark all as read",
                description: "Marks all notifications as read.",
                auth: .bearer()
            )
            
        notifications.delete(":notificationID", use: delete)
            .openAPI(
                summary: "Delete notification",
                description: "Deletes a specific notification.",
                auth: .bearer()
            )
            
        notifications.delete("clear-all", use: clearAll)
            .openAPI(
                summary: "Clear all notifications",
                description: "Deletes all notifications for the user.",
                auth: .bearer()
            )
        
        // Preferences
        notifications.get("preferences", use: getPreferences)
            .openAPI(
                summary: "Get preferences",
                description: "Retrieves user notification preferences.",
                response: .type(NotificationPreferencesResponse.self),
                auth: .bearer()
            )
            
        notifications.put("preferences", use: updatePreferences)
            .openAPI(
                summary: "Update preferences",
                description: "Updates user notification preferences.",
                body: .type(UpdateNotificationPreferencesRequest.self),
                response: .type(NotificationPreferencesResponse.self),
                auth: .bearer()
            )
            
        notifications.post("register-push", use: registerPushToken)
            .openAPI(
                summary: "Register push token",
                description: "Registers a device push token for notifications.",
                body: .type(RegisterPushTokenRequest.self),
                auth: .bearer()
            )
        
        // Testing endpoints
        notifications.post("test", "budget-alert", use: testBudgetAlert)
            .openAPI(
                summary: "Test budget alert",
                description: "Triggers a test budget alert notification.",
                response: .type(NotificationResponse.self),
                auth: .bearer()
            )
            
        notifications.post("test", "daily-summary", use: testDailySummary)
             .openAPI(
                summary: "Test daily summary",
                description: "Triggers a test daily summary notification.",
                response: .type(NotificationResponse.self),
                auth: .bearer()
            )
    }
    
    // MARK: - Get All Notifications
    func index(req: Request) async throws -> NotificationListResponse {
        let user = try req.auth.require(User.self)
        
        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = min(req.query[Int.self, at: "per"] ?? 20, 100)
        
        let query = Notification.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .sort(\.$createdAt, .descending)
        
        let total = try await query.count()
        let items = try await query
            .offset((page - 1) * perPage)
            .limit(perPage)
            .all()
        
        let responses = try items.map { try NotificationResponse(from: $0) }
        
        return NotificationListResponse(
            notifications: responses,
            total: total,
            page: page,
            perPage: perPage
        )
    }
    
    // MARK: - Get Unread Notifications
    func getUnread(req: Request) async throws -> [NotificationResponse] {
        let user = try req.auth.require(User.self)
        
        let notifications = try await Notification.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$isRead == false)
            .sort(\.$createdAt, .descending)
            .limit(50)
            .all()
        
        return try notifications.map { try NotificationResponse(from: $0) }
    }
    
    // MARK: - Get Unread Count
    func getUnreadCount(req: Request) async throws -> UnreadCountResponse {
        let user = try req.auth.require(User.self)
        
        let count = try await Notification.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$isRead == false)
            .count()
        
        return UnreadCountResponse(count: count)
    }
    
    // MARK: - Mark as Read
    func markAsRead(req: Request) async throws -> NotificationResponse {
        let user = try req.auth.require(User.self)
        
        guard let notificationID = req.parameters.get("notificationID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let notification = try await Notification.find(notificationID, on: req.db) else {
            throw Abort(.notFound)
        }
        
        guard notification.$user.id == user.id! else {
            throw Abort(.forbidden)
        }
        
        notification.isRead = true
        notification.readAt = Date()
        try await notification.save(on: req.db)
        
        return try NotificationResponse(from: notification)
    }
    
    // MARK: - Mark All as Read
    func markAllAsRead(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        let notifications = try await Notification.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$isRead == false)
            .all()
        
        for notification in notifications {
            notification.isRead = true
            notification.readAt = Date()
            try await notification.save(on: req.db)
        }
        
        return .ok
    }
    
    // MARK: - Delete Notification
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        guard let notificationID = req.parameters.get("notificationID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let notification = try await Notification.find(notificationID, on: req.db) else {
            throw Abort(.notFound)
        }
        
        guard notification.$user.id == user.id! else {
            throw Abort(.forbidden)
        }
        
        try await notification.delete(on: req.db)
        return .noContent
    }
    
    // MARK: - Clear All
    func clearAll(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        try await Notification.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .delete()
        
        return .noContent
    }
    
    // MARK: - Get Preferences
    func getPreferences(req: Request) async throws -> NotificationPreferencesResponse {
        let user = try req.auth.require(User.self)
        
        let preferences = try await NotificationService.getUserPreferences(userID: user.id!, on: req)
        return NotificationPreferencesResponse(preferences: preferences)
    }
    
    // MARK: - Update Preferences
    func updatePreferences(req: Request) async throws -> NotificationPreferencesResponse {
        let user = try req.auth.require(User.self)
        
        let updateRequest = try req.content.decode(UpdateNotificationPreferencesRequest.self)
        let preferences = try await NotificationService.getUserPreferences(userID: user.id!, on: req)
        
        if let value = updateRequest.budgetAlertsEnabled {
            preferences.budgetAlertsEnabled = value
        }
        if let value = updateRequest.dailySummaryEnabled {
            preferences.dailySummaryEnabled = value
        }
        if let value = updateRequest.weeklySummaryEnabled {
            preferences.weeklySummaryEnabled = value
        }
        if let value = updateRequest.unusualSpendingEnabled {
            preferences.unusualSpendingEnabled = value
        }
        if let value = updateRequest.billRemindersEnabled {
            preferences.billRemindersEnabled = value
        }
        if let value = updateRequest.quietHoursStart {
            preferences.quietHoursStart = value
        }
        if let value = updateRequest.quietHoursEnd {
            preferences.quietHoursEnd = value
        }
        if let value = updateRequest.pushEnabled {
            preferences.pushEnabled = value
        }
        if let value = updateRequest.emailEnabled {
            preferences.emailEnabled = value
        }
        
        try await preferences.save(on: req.db)
        
        return NotificationPreferencesResponse(preferences: preferences)
    }
    
    // MARK: - Register Push Token
    func registerPushToken(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        let tokenRequest = try req.content.decode(RegisterPushTokenRequest.self)
        let preferences = try await NotificationService.getUserPreferences(userID: user.id!, on: req)
        
        preferences.pushToken = tokenRequest.pushToken
        try await preferences.save(on: req.db)
        
        return .ok
    }
    
    // MARK: - Test Endpoints
    func testBudgetAlert(req: Request) async throws -> NotificationResponse {
        let user = try req.auth.require(User.self)
        
        let notification = try await NotificationService.createNotification(
            for: user.id!,
            type: .budgetAlert,
            title: "Budget Alert",
            message: "You've spent 85% of your Food budget ($75 remaining)",
            data: NotificationData(
                budgetID: UUID().uuidString,
                amount: 425.0,
                category: "Food",
                percentage: 85.0
            ),
            priority: .high,
            category: "Food",
            actionURL: "/budgets",
            on: req
        )
        
        return try NotificationResponse(from: notification)
    }
    
    func testDailySummary(req: Request) async throws -> NotificationResponse {
        let user = try req.auth.require(User.self)
        
        let notification = try await NotificationService.createNotification(
            for: user.id!,
            type: .dailySummary,
            title: "Daily Summary",
            message: "Today you spent $125.50 across 4 expenses. Top category: Shopping",
            data: NotificationData(
                amount: 125.50,
                category: "Shopping",
                metadata: ["expense_count": "4"]
            ),
            priority: .normal,
            category: "summary",
            on: req
        )
        
        return try NotificationResponse(from: notification)
    }
}
