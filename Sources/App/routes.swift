import Vapor

func routes(_ app: Application) throws {
    struct HealthResponse: Content {
        let status: String
        let timestamp: TimeInterval
    }
    
    func routes(_ app: Application) throws {
        app.get("health") { req async in
            return HealthResponse(status: "ok", timestamp: Date().timeIntervalSince1970)
        }
        
        // API v1 routes
        let api = app.grouped("api", "v1")
        
        // Auth routes
        try api.register(collection: AuthController())
        
        // Protected routes
        let protected = api.grouped(JWTAuthenticator())
        
        // User routes
        let userController = UserController()
        protected.get("user", "profile", use: userController.getProfile)
        protected.put("user", "profile", use: userController.updateProfile)
        
        // Expense routes
        let expenseController = ExpenseController()
        protected.get("expenses", use: expenseController.index)
        protected.post("expenses", use: expenseController.create)
        protected.get("expenses", ":expenseID", use: expenseController.show)
        protected.put("expenses", ":expenseID", use: expenseController.update)
        protected.delete("expenses", ":expenseID", use: expenseController.delete)
        protected.get("expenses", "categories", use: expenseController.getCategories)
    }
}
