import Vapor

func routes(_ app: Application) throws {
    struct HealthResponse: Content {
        let status: String
        let timestamp: TimeInterval
    }
    
    app.get("health") { req async in
        return HealthResponse(status: "ok", timestamp: Date().timeIntervalSince1970)
    }
    
    // API v1 routes
    let api = app.grouped("api", "v1")
    
    // Budget routes
    try api.register(collection: BudgetController())
    
    // Auth routes
    try api.register(collection: AuthController())
    
    // Dashboard routes
    try api.register(collection: DashboardController())
    
    // User routes
    try api.register(collection: UserController())
    
    // Expense routes
    try api.register(collection: ExpenseController())

    // Receipt routes
    try api.register(collection: ReceiptController())
    
    // Notification routes
    try api.register(collection: NotificationController())
}
