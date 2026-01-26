import Vapor
import Fluent

struct AIChatService {
    
    enum Intent: String, Content {
        case spendingAnalysis = "spending_analysis"
        case budgetStatus = "budget_status"
        case savingsTips = "savings_tips"
        case categoryBreakdown = "category_breakdown"
        case comparison = "comparison"
        case topExpenses = "top_expenses"
        case unusualSpending = "unusual_spending"
        case prediction = "prediction"
        case general = "general"
    }
    
    // MARK: - Process User Query
    static func processQuery(
        message: String,
        userID: UUID,
        on req: Request
    ) async throws -> (response: String, intent: Intent, contextData: ChatContextData?) {
        
        // 1. Detect intent from message
        let intent = detectIntent(from: message)
        
        // 2. Fetch relevant user data
        let expenses = try await Expense.query(on: req.db)
            .filter(\.$user.$id == userID)
            .sort(\.$date, .descending)
            .all()
        
        let budgets = try await Budget.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$isActive == true)
            .all()
        
        // 3. Generate response based on intent
        let (response, contextData) = try await generateResponse(
            intent: intent,
            message: message,
            expenses: expenses,
            budgets: budgets,
            on: req
        )
        
        // 4. Save conversation
        let chatMessage = ChatMessage(
            userID: userID,
            message: message,
            response: response,
            intent: intent.rawValue,
            contextData: contextData
        )
        try await chatMessage.save(on: req.db)
        
        return (response, intent, contextData)
    }
    
    // MARK: - Intent Detection
    static func detectIntent(from message: String) -> Intent {
        let lowercased = message.lowercased()
        
        // Spending Analysis
        if lowercased.contains("why") && (lowercased.contains("spending") || lowercased.contains("spent")) {
            return .spendingAnalysis
        }
        
        // Budget Status
        if lowercased.contains("budget") && (lowercased.contains("status") || lowercased.contains("how")) {
            return .budgetStatus
        }
        
        // Savings Tips
        if lowercased.contains("save") || lowercased.contains("reduce") || lowercased.contains("cut") {
            return .savingsTips
        }
        
        // Category Breakdown
        if lowercased.contains("category") || lowercased.contains("categories") || 
           lowercased.contains("breakdown") || lowercased.contains("where") {
            return .categoryBreakdown
        }
        
        // Comparison
        if lowercased.contains("compare") || lowercased.contains("last month") || 
           lowercased.contains("previous") || lowercased.contains("vs") {
            return .comparison
        }
        
        // Top Expenses
        if lowercased.contains("top") || lowercased.contains("biggest") || 
           lowercased.contains("largest") || lowercased.contains("most expensive") {
            return .topExpenses
        }
        
        // Unusual Spending
        if lowercased.contains("unusual") || lowercased.contains("anomaly") || 
           lowercased.contains("weird") || lowercased.contains("suspicious") {
            return .unusualSpending
        }
        
        // Prediction
        if lowercased.contains("predict") || lowercased.contains("forecast") || 
           lowercased.contains("will i") || lowercased.contains("next month") {
            return .prediction
        }
        
        return .general
    }
    
    // MARK: - Generate Response
    static func generateResponse(
        intent: Intent,
        message: String,
        expenses: [Expense],
        budgets: [Budget],
        on req: Request
    ) async throws -> (String, ChatContextData?) {
        
        switch intent {
        case .spendingAnalysis:
            return try await generateSpendingAnalysis(expenses: expenses, budgets: budgets)
            
        case .budgetStatus:
            return try await generateBudgetStatus(budgets: budgets, expenses: expenses, on: req)
            
        case .savingsTips:
            return try await generateSavingsTips(expenses: expenses)
            
        case .categoryBreakdown:
            return generateCategoryBreakdown(expenses: expenses)
            
        case .comparison:
            return generateComparison(expenses: expenses)
            
        case .topExpenses:
            return generateTopExpenses(expenses: expenses)
            
        case .unusualSpending:
            return generateUnusualSpending(expenses: expenses)
            
        case .prediction:
            return generatePrediction(expenses: expenses, budgets: budgets)
            
        case .general:
            return generateGeneralResponse(message: message, expenses: expenses)
        }
    }
    
    // MARK: - Spending Analysis
    static func generateSpendingAnalysis(
        expenses: [Expense],
        budgets: [Budget]
    ) async throws -> (String, ChatContextData?) {
        
        let thisMonth = Calendar.current.dateComponents([.year, .month], from: Date())
        let monthExpenses = expenses.filter { expense in
            let components = Calendar.current.dateComponents([.year, .month], from: expense.date)
            return components.year == thisMonth.year && components.month == thisMonth.month
        }
        
        let totalSpent = monthExpenses.reduce(0) { $0 + $1.amount }
        
        // Group by category
        var categorySpending: [String: Double] = [:]
        for expense in monthExpenses {
            categorySpending[expense.category.rawValue, default: 0] += expense.amount
        }
        
        // Find top category
        let topCategory = categorySpending.max(by: { $0.value < $1.value })
        
        guard let top = topCategory else {
            return ("You haven't spent anything this month yet! 🎉", nil)
        }
        
        let percentage = (top.value / totalSpent) * 100
        let topCategoryBudget = budgets.first(where: { $0.category.rawValue == top.key })
        
        var response = """
        📊 **This Month's Analysis:**
        
        You've spent **$\(String(format: "%.2f", totalSpent))** so far this month.
        
        Your biggest spending category is **\(top.key)** at $\(String(format: "%.2f", top.value)) (\(Int(percentage))% of total).
        """
        
        if let budget = topCategoryBudget {
            let budgetPercentage = (top.value / budget.amount) * 100
            if budgetPercentage > 80 {
                response += "\n\n⚠️ You're at \(Int(budgetPercentage))% of your \(top.key) budget!"
            }
        }
        
        // Add suggestions
        if top.key == "food" && top.value > 300 {
            response += "\n\n💡 **Tip:** Try meal prepping on Sundays to reduce dining out. Could save you $100-150/month!"
        } else if top.key == "transportation" && top.value > 200 {
            response += "\n\n💡 **Tip:** Consider carpooling or public transport 2-3 days a week to cut costs."
        }
        
        let contextData = ChatContextData(
            amount: totalSpent,
            category: top.key,
            timeframe: "this_month",
            suggestions: []
        )
        
        return (response, contextData)
    }
    
    // MARK: - Budget Status
    static func generateBudgetStatus(
        budgets: [Budget],
        expenses: [Expense],
        on req: Request
    ) async throws -> (String, ChatContextData?) {
        
        guard !budgets.isEmpty else {
            return ("You haven't set up any budgets yet. Want me to help you create one? 🎯", nil)
        }
        
        var response = "📊 **Budget Status:**\n\n"
        var allOnTrack = true
        
        for budget in budgets {
            let categoryExpenses = expenses.filter { 
                $0.category == budget.category && 
                $0.date >= budget.startDate 
            }
            let spent = categoryExpenses.reduce(0) { $0 + $1.amount }
            let percentage = (spent / budget.amount) * 100
            
            let emoji: String
            if percentage < 80 {
                emoji = "✅"
            } else if percentage < 100 {
                emoji = "⚠️"
                allOnTrack = false
            } else {
                emoji = "🚨"
                allOnTrack = false
            }
            
            response += """
            \(emoji) **\(budget.category.displayName):** $\(String(format: "%.2f", spent)) / $\(String(format: "%.2f", budget.amount)) (\(Int(percentage))%)
            
            """
        }
        
        if allOnTrack {
            response += "\n🎉 Great job! You're on track with all your budgets!"
        } else {
            response += "\n💡 Some budgets need attention. Want tips on how to cut back?"
        }
        
        return (response, nil)
    }
    
    // MARK: - Savings Tips
    static func generateSavingsTips(expenses: [Expense]) async throws -> (String, ChatContextData?) {
        
        let thisMonth = Calendar.current.dateComponents([.year, .month], from: Date())
        let monthExpenses = expenses.filter { expense in
            let components = Calendar.current.dateComponents([.year, .month], from: expense.date)
            return components.year == thisMonth.year && components.month == thisMonth.month
        }
        
        var categorySpending: [String: Double] = [:]
        for expense in monthExpenses {
            categorySpending[expense.category.rawValue, default: 0] += expense.amount
        }
        
        var tips: [String] = []
        var potentialSavings: Double = 0
        
        // Food suggestions
        if let foodSpending = categorySpending["food"], foodSpending > 300 {
            tips.append("🍳 **Cook at home 3x per week** instead of dining out → Save ~$120/month")
            potentialSavings += 120
        }
        
        // Transport suggestions
        if let transportSpending = categorySpending["transportation"], transportSpending > 150 {
            tips.append("🚌 **Use public transport 2x per week** → Save ~$60/month")
            potentialSavings += 60
        }
        
        // Entertainment suggestions
        if let entertainmentSpending = categorySpending["entertainment"], entertainmentSpending > 100 {
            tips.append("🎬 **Try free activities or streaming** instead of movies/events → Save ~$50/month")
            potentialSavings += 50
        }
        
        // Coffee suggestion (check for frequent small purchases)
        let smallPurchases = monthExpenses.filter { $0.amount < 10 && $0.category == .food }
        if smallPurchases.count > 10 {
            tips.append("☕ **Brew coffee at home** instead of coffee shops → Save ~$80/month")
            potentialSavings += 80
        }
        
        // Generic tip
        if tips.isEmpty {
            tips.append("💰 Track every expense and review weekly")
            tips.append("🎯 Set specific savings goals")
            tips.append("🔄 Automate savings transfers")
        }
        
        var response = "💡 **Smart Savings Tips:**\n\n"
        response += tips.joined(separator: "\n\n")
        
        if potentialSavings > 0 {
            response += "\n\n**Total Potential Savings: $\(String(format: "%.2f", potentialSavings))/month** 🎉"
        }
        
        let contextData = ChatContextData(suggestions: tips)
        return (response, contextData)
    }
    
    // MARK: - Category Breakdown
    static func generateCategoryBreakdown(expenses: [Expense]) -> (String, ChatContextData?) {
        
        let thisMonth = Calendar.current.dateComponents([.year, .month], from: Date())
        let monthExpenses = expenses.filter { expense in
            let components = Calendar.current.dateComponents([.year, .month], from: expense.date)
            return components.year == thisMonth.year && components.month == thisMonth.month
        }
        
        var categorySpending: [ExpenseCategory: Double] = [:]
        var categoryCounts: [ExpenseCategory: Int] = [:]
        
        for expense in monthExpenses {
            categorySpending[expense.category, default: 0] += expense.amount
            categoryCounts[expense.category, default: 0] += 1
        }
        
        let totalSpent = categorySpending.values.reduce(0, +)
        let sortedCategories = categorySpending.sorted(by: { $0.value > $1.value })
        
        var response = "📊 **Spending by Category:**\n\n"
        
        for (category, amount) in sortedCategories {
            let percentage = (amount / totalSpent) * 100
            let count = categoryCounts[category] ?? 0
            
            response += """
            \(category.icon) **\(category.displayName)**: $\(String(format: "%.2f", amount)) (\(Int(percentage))%)
            \(count) transactions
            
            """
        }
        
        response += "\n**Total: $\(String(format: "%.2f", totalSpent))**"
        
        return (response, nil)
    }
    
    // MARK: - Comparison
    static func generateComparison(expenses: [Expense]) -> (String, ChatContextData?) {
        
        let calendar = Calendar.current
        let now = Date()
        
        // This month
        let thisMonth = calendar.dateComponents([.year, .month], from: now)
        let thisMonthExpenses = expenses.filter { expense in
            let components = calendar.dateComponents([.year, .month], from: expense.date)
            return components.year == thisMonth.year && components.month == thisMonth.month
        }
        let thisMonthTotal = thisMonthExpenses.reduce(0) { $0 + $1.amount }
        
        // Last month
        guard let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now) else {
            return ("Unable to compare months.", nil)
        }
        let lastMonth = calendar.dateComponents([.year, .month], from: lastMonthDate)
        let lastMonthExpenses = expenses.filter { expense in
            let components = calendar.dateComponents([.year, .month], from: expense.date)
            return components.year == lastMonth.year && components.month == lastMonth.month
        }
        let lastMonthTotal = lastMonthExpenses.reduce(0) { $0 + $1.amount }
        
        let difference = thisMonthTotal - lastMonthTotal
        let percentageChange = lastMonthTotal > 0 ? (difference / lastMonthTotal) * 100 : 0
        
        let emoji = difference > 0 ? "📈" : "📉"
        let trend = difference > 0 ? "higher" : "lower"
        
        var response = """
        \(emoji) **Month-over-Month Comparison:**
        
        This month: $\(String(format: "%.2f", thisMonthTotal))
        Last month: $\(String(format: "%.2f", lastMonthTotal))
        
        You're spending $\(String(format: "%.2f", abs(difference))) \(trend) (\(Int(abs(percentageChange)))%)
        """
        
        if difference > 0 {
            response += "\n\n💡 Consider reviewing your recent expenses to identify areas to cut back."
        } else {
            response += "\n\n🎉 Great job! You're spending less than last month!"
        }
        
        let contextData = ChatContextData(
            amount: difference,
            comparison: "month_over_month"
        )
        
        return (response, contextData)
    }
    
    // MARK: - Top Expenses
    static func generateTopExpenses(expenses: [Expense]) -> (String, ChatContextData?) {
        
        let thisMonth = Calendar.current.dateComponents([.year, .month], from: Date())
        let monthExpenses = expenses.filter { expense in
            let components = Calendar.current.dateComponents([.year, .month], from: expense.date)
            return components.year == thisMonth.year && components.month == thisMonth.month
        }
        
        let topExpenses = monthExpenses.sorted(by: { $0.amount > $1.amount }).prefix(5)
        
        var response = "💰 **Top 5 Expenses This Month:**\n\n"
        
        for (index, expense) in topExpenses.enumerated() {
            response += """
            \(index + 1). \(expense.category.icon) **$\(String(format: "%.2f", expense.amount))** - \(expense.description)
            \(expense.category.displayName) • \(formatDate(expense.date))
            
            """
        }
        
        if topExpenses.isEmpty {
            response = "No expenses recorded this month yet! Start tracking to see your top spending. 📝"
        }
        
        return (response, nil)
    }
    
    // MARK: - Unusual Spending
    static func generateUnusualSpending(expenses: [Expense]) -> (String, ChatContextData?) {
        
        // Calculate average for each category
        var categoryAverages: [ExpenseCategory: Double] = [:]
        var categoryExpenses: [ExpenseCategory: [Expense]] = [:]
        
        for expense in expenses {
            categoryExpenses[expense.category, default: []].append(expense)
        }
        
        for (category, expenseList) in categoryExpenses {
            let total = expenseList.reduce(0) { $0 + $1.amount }
            categoryAverages[category] = total / Double(expenseList.count)
        }
        
        // Find unusual expenses (> 2x average)
        var unusualExpenses: [(Expense, Double)] = []
        
        for expense in expenses.prefix(30) { // Last 30 expenses
            if let average = categoryAverages[expense.category], expense.amount > average * 2 {
                unusualExpenses.append((expense, average))
            }
        }
        
        if unusualExpenses.isEmpty {
            return ("✅ No unusual spending detected! Everything looks normal.", nil)
        }
        
        var response = "🔍 **Unusual Spending Detected:**\n\n"
        
        for (expense, average) in unusualExpenses.prefix(3) {
            let multiplier = expense.amount / average
            response += """
            ⚠️ **$\(String(format: "%.2f", expense.amount))** - \(expense.description)
            \(expense.category.displayName) • \(Int(multiplier))x your average ($\(String(format: "%.2f", average)))
            
            """
        }
        
        response += "\n💡 Review these transactions to ensure they're correct."
        
        return (response, nil)
    }
    
    // MARK: - Prediction
    static func generatePrediction(expenses: [Expense], budgets: [Budget]) -> (String, ChatContextData?) {
        
        let calendar = Calendar.current
        let now = Date()
        let thisMonth = calendar.dateComponents([.year, .month], from: now)
        
        let monthExpenses = expenses.filter { expense in
            let components = calendar.dateComponents([.year, .month], from: expense.date)
            return components.year == thisMonth.year && components.month == thisMonth.month
        }
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentDay = calendar.component(.day, from: now)
        let daysRemaining = daysInMonth - currentDay
        
        let totalSpent = monthExpenses.reduce(0) { $0 + $1.amount }
        let dailyAverage = totalSpent / Double(max(1, currentDay))
        let projectedTotal = dailyAverage * Double(daysInMonth)
        
        let totalBudget = budgets.filter { $0.isActive }.reduce(0) { $0 + $1.amount }
        
        let emoji = projectedTotal > totalBudget ? "⚠️" : "✅"
        let status = projectedTotal > totalBudget ? "exceed" : "stay within"
        
        var response = """
        🔮 **Spending Forecast:**
        
        Based on your current pace:
        • Daily average: $\(String(format: "%.2f", dailyAverage))
        • Days remaining: \(daysRemaining)
        • Projected month total: $\(String(format: "%.2f", projectedTotal))
        
        \(emoji) You're on track to **\(status)** your budget this month.
        """
        
        if projectedTotal > totalBudget && daysRemaining > 0 {
            let excess = projectedTotal - totalBudget
            let dailyLimit = (totalBudget - totalSpent) / Double(daysRemaining)
            response += "\n\n💡 To stay on budget, try to spend less than $\(String(format: "%.2f", max(0, dailyLimit)))/day for the rest of the month."
        }
        
        let contextData = ChatContextData(
            amount: projectedTotal,
            timeframe: "month_end"
        )
        
        return (response, contextData)
    }
    
    // MARK: - General Response
    static func generateGeneralResponse(message: String, expenses: [Expense]) -> (String, ChatContextData?) {
        
        let responses = [
            "I'm here to help you understand your spending! Try asking:\n• 'Why am I spending so much?'\n• 'How's my budget?'\n• 'Can you give me savings tips?'\n• 'Show my top expenses'",
            "I can analyze your finances! Some things you can ask:\n• Compare my spending to last month\n• What's unusual about my spending?\n• Predict my spending\n• Break down by category",
            "Let me help you manage your money! Ask me about:\n• Your spending patterns\n• Budget status\n• Ways to save money\n• Category breakdowns"
        ]
        
        return (responses.randomElement() ?? responses[0], nil)
    }
    
    // MARK: - Helper Functions
    
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
