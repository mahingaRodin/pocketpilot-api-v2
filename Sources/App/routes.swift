import Vapor

func routes(_ app: Application) throws {
    // Health check endpoint
    app.get("health") { req async in
        return ["status": "ok", "timestamp": Date().timeIntervalSince1970]
    }
    
    // API v1 routes
    let api = app.grouped("api", "v1")
    
    // Auth routes (public)
    let authController = AuthController()
    api.post("auth", "register", use: authController.register)
    api.post("auth", "login", use: authController.login)
    
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