import Vapor
import Fluent

struct DashboardController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let dashboard = routes.grouped("dashboard")
        let protected = dashboard.grouped(JWTAuthenticator())
        
        protected.get(use: getDashboard)
    }
    
    func getDashboard(req: Request) async throws -> DashboardResponse {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        
        // Get all expenses for the user
        let expenses = try await Expense.query(on: req.db)
            .filter(\.$user.$id == userID)
            .sort(\.$date, .descending)
            .all()
        
        let totalExpenses = expenses.reduce(0.0) { $0 + $1.amount }
        
        // Calculate monthly expenses
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthlyExpenses = expenses
            .filter { $0.date >= startOfMonth }
            .reduce(0.0) { $0 + $1.amount }
        
        // Calculate weekly expenses
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weeklyExpenses = expenses
            .filter { $0.date >= startOfWeek }
            .reduce(0.0) { $0 + $1.amount }
        
        // Recent expenses (last 5)
        let recentExpenses = Array(expenses.prefix(5)).map(ExpenseResponse.init)
        
        // Category breakdown
        var categoryTotals: [ExpenseCategory: Double] = [:]
        for expense in expenses {
            categoryTotals[expense.category, default: 0.0] += expense.amount
        }
        
        let categoryBreakdown = categoryTotals.map { (category, total) in
            CategorySummary(
                category: category,
                categoryDisplay: category.displayName,
                categoryIcon: category.icon,
                total: total
            )
        }.sorted { $0.total > $1.total }
        
        return DashboardResponse(
            totalExpenses: totalExpenses,
            monthlyExpenses: monthlyExpenses,
            weeklyExpenses: weeklyExpenses,
            recentExpenses: recentExpenses,
            categoryBreakdown: categoryBreakdown,
            budgetStatus: 0.0 // Placeholder until budget is implemented
        )
    }
}
