import Vapor

struct DashboardResponse: Content {
    let totalExpenses: Double
    let monthlyExpenses: Double
    let weeklyExpenses: Double
    let recentExpenses: [ExpenseResponse]
    let categoryBreakdown: [CategorySummary]
    let budgetStatus: Double // Percentage of budget used (if implemented)
    let safeToSpend: SafeToSpendData?
    let ecoImpact: UserEcoImpact?
}

struct CategorySummary: Content {
    let category: ExpenseCategory
    let categoryDisplay: String
    let categoryIcon: String
    let total: Double
}
